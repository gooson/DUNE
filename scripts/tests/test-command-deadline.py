"""Contract tests for the owned UI command deadline."""

from pathlib import Path
import os
import subprocess
import sys
import tempfile
import time
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "lib" / "command-deadline.py"
LOCK = SCRIPT.with_name("simulator-test-lock.py")


class CommandDeadlineTests(unittest.TestCase):
    @staticmethod
    def stubborn_child(marker: Path) -> str:
        return (
            "import pathlib,signal,sys,time; "
            "signal.signal(signal.SIGTERM, signal.SIG_IGN); "
            "time.sleep(1.5); pathlib.Path(sys.argv[1]).touch(); time.sleep(20)"
        )

    def test_preserves_exit_code(self) -> None:
        result = subprocess.run([sys.executable, str(SCRIPT), "--seconds", "2", "--",
                                 sys.executable, "-c", "import sys; sys.exit(17)"],
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 17)

    def test_nested_deadline_preserves_both_repository_lock_descriptors(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory) / "repo"
            repo.mkdir()
            subprocess.run(["git", "init", "-q", str(repo)], check=True,
                           capture_output=True)
            environment = os.environ.copy()
            environment["DUNE_SIM_TEST_LOCK_SCOPE"] = "repository"
            environment.pop("DUNE_SIM_TEST_LOCK_FD", None)
            environment.pop("DUNE_SIM_TEST_WORKTREE_LOCK_FD", None)
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--seconds", "5", "--",
                 sys.executable, str(LOCK), str(repo), "--",
                 sys.executable, str(SCRIPT), "--seconds", "3", "--",
                 sys.executable, str(LOCK), str(repo), "--verify"],
                env=environment, capture_output=True, text=True, timeout=8,
            )
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_duplicate_and_invalid_inherited_lock_descriptors(self) -> None:
        with tempfile.TemporaryFile() as file:
            fd = file.fileno()
            environment = {**os.environ,
                           "DUNE_SIM_TEST_LOCK_FD": str(fd),
                           "DUNE_SIM_TEST_WORKTREE_LOCK_FD": str(fd)}
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--seconds", "2", "--",
                 sys.executable, "-c", "import os,sys; os.fstat(int(sys.argv[1]))", str(fd)],
                env=environment, pass_fds=(fd,), capture_output=True, text=True, timeout=5,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
        invalid = subprocess.run(
            [sys.executable, str(SCRIPT), "--seconds", "2", "--",
             sys.executable, "-c", "print('ran')"],
            env={**os.environ, "DUNE_SIM_TEST_LOCK_FD": "stale",
                 "DUNE_SIM_TEST_WORKTREE_LOCK_FD": "stale"},
            capture_output=True, text=True, timeout=5,
        )
        self.assertEqual(invalid.returncode, 0, invalid.stderr)
        self.assertEqual(invalid.stdout.strip(), "ran")

    def test_stops_a_stalled_command(self) -> None:
        result = subprocess.run([sys.executable, str(SCRIPT), "--seconds", "1", "--",
                                 sys.executable, "-c", "import time; time.sleep(20)"],
                                capture_output=True, text=True, timeout=7)
        self.assertEqual(result.returncode, 124)
        self.assertIn("exceeded 1s", result.stderr)

    def test_stops_when_log_has_no_activity(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            activity_file = Path(directory) / "test.log"
            result = subprocess.run([sys.executable, str(SCRIPT), "--seconds", "10",
                                     "--idle-seconds", "1", "--activity-file", str(activity_file),
                                     "--", sys.executable, "-c", "import time; time.sleep(20)"],
                                    capture_output=True, text=True, timeout=7)
            self.assertEqual(result.returncode, 124)
            self.assertIn("no activity for 1s", result.stderr)

    def test_stops_descendant_after_timeout(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "descendant-survived"
            parent = (
                "import subprocess,sys,time; "
                "subprocess.Popen([sys.executable, '-c', "
                "'import pathlib,sys,time; time.sleep(2); pathlib.Path(sys.argv[1]).touch()', "
                "sys.argv[1]]); time.sleep(20)"
            )
            result = subprocess.run([sys.executable, str(SCRIPT), "--seconds", "1", "--",
                                     sys.executable, "-c", parent, str(marker)],
                                    capture_output=True, text=True, timeout=7)
            self.assertEqual(result.returncode, 124)
            time.sleep(2)
            self.assertFalse(marker.exists(), "Timed-out command left a child running")

    def test_nested_timeout_cleans_term_resistant_descendant(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "nested-descendant-survived"
            command = (
                "import subprocess,sys,time; "
                "subprocess.Popen([sys.executable, '-c', sys.argv[2], sys.argv[3]]); "
                "time.sleep(20)"
            )
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--seconds", "10", "--",
                 sys.executable, str(SCRIPT), "--seconds", "1", "--",
                 sys.executable, "-c", command, "unused", self.stubborn_child(marker), str(marker)],
                capture_output=True, text=True, timeout=15,
            )
            self.assertEqual(result.returncode, 124)
            time.sleep(2)
            self.assertFalse(marker.exists(), "Nested timeout left a separate command group alive")

    def test_normal_exit_cleans_background_descendant(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "background-descendant-survived"
            command = (
                "import subprocess,sys; "
                "subprocess.Popen([sys.executable, '-c', sys.argv[1], sys.argv[2]])"
            )
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--seconds", "5", "--",
                 sys.executable, "-c", command, self.stubborn_child(marker), str(marker)],
                capture_output=True, text=True, timeout=8,
            )
            self.assertEqual(result.returncode, 0)
            time.sleep(2)
            self.assertFalse(marker.exists(), "Successful command left a background child running")

    def test_interrupt_cleans_term_resistant_descendant(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "interrupted-descendant-survived"
            ready = Path(directory) / "child-ready"
            command = (
                "import pathlib,subprocess,sys,time; "
                "subprocess.Popen([sys.executable, '-c', sys.argv[1], sys.argv[2]]); "
                "pathlib.Path(sys.argv[3]).touch(); time.sleep(20)"
            )
            watchdog = subprocess.Popen(
                [sys.executable, str(SCRIPT), "--seconds", "10", "--",
                 sys.executable, "-c", command, self.stubborn_child(marker), str(marker), str(ready)],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            )
            try:
                deadline = time.monotonic() + 3
                while not ready.exists() and time.monotonic() < deadline:
                    time.sleep(0.02)
                self.assertTrue(ready.exists(), "Test command did not start")
                watchdog.terminate()
                _, stderr = watchdog.communicate(timeout=8)
                self.assertEqual(watchdog.returncode, 130, stderr)
                time.sleep(2)
                self.assertFalse(marker.exists(), "Interrupted command left a child running")
            finally:
                if watchdog.poll() is None:
                    watchdog.kill()
                    watchdog.communicate()


if __name__ == "__main__":
    unittest.main()
