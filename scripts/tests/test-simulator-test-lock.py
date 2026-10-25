#!/usr/bin/env python3
"""Subprocess tests for repository and opted-in worktree simulator locks."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest


LOCK = Path(__file__).resolve().parents[1] / "lib" / "simulator-test-lock.py"


def git(*args: str, cwd: Path) -> None:
    subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True)


def wait_for(path: Path, timeout: float = 5) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.exists():
            return
        time.sleep(0.02)
    raise AssertionError(f"Timed out waiting for {path}")


class SimulatorTestLockTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / "repo"
        self.repo.mkdir()
        git("init", "-q", cwd=self.repo)
        git("-c", "user.name=Test", "-c", "user.email=test@example.com",
            "commit", "--allow-empty", "-qm", "initial", cwd=self.repo)
        self.sibling = self.base / "sibling"
        git("worktree", "add", "--detach", "-q", str(self.sibling), cwd=self.repo)

    def command(self, root: Path, source: str, *args: str, env=None):
        return [sys.executable, str(LOCK), str(root), "--", sys.executable,
                "-c", source, *args]

    def test_sibling_worktrees_are_mutually_exclusive(self) -> None:
        first_started = self.base / "first-started"
        first_release = self.base / "first-release"
        second_started = self.base / "second-started"
        hold = ("import pathlib,sys,time\n"
                "pathlib.Path(sys.argv[1]).touch()\n"
                "release=pathlib.Path(sys.argv[2])\n"
                "while not release.exists(): time.sleep(.02)\n")
        first = subprocess.Popen(self.command(self.repo, hold, str(first_started), str(first_release)),
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.addCleanup(lambda: first.kill() if first.poll() is None else None)
        wait_for(first_started)
        second = subprocess.Popen(self.command(self.sibling,
                                  "import pathlib,sys; pathlib.Path(sys.argv[1]).touch()",
                                  str(second_started)), stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL)
        self.addCleanup(lambda: second.kill() if second.poll() is None else None)
        time.sleep(0.2)
        self.assertFalse(second_started.exists())
        first_release.touch()
        self.assertEqual(first.wait(timeout=5), 0)
        self.assertEqual(second.wait(timeout=5), 0)
        self.assertTrue(second_started.exists())

    def test_opted_in_other_worktree_can_run_beside_repository_runner(self) -> None:
        first_started = self.base / "repository-started"
        release = self.base / "repository-release"
        first = subprocess.Popen(self.command(self.repo,
            "import pathlib,sys,time; pathlib.Path(sys.argv[1]).touch(); "
            "release=pathlib.Path(sys.argv[2]); "
            "\nwhile not release.exists(): time.sleep(.02)",
            str(first_started), str(release)),
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.addCleanup(lambda: first.kill() if first.poll() is None else None)
        wait_for(first_started)
        result = subprocess.run(self.command(self.sibling, "print('parallel')"),
                                env={**os.environ, "DUNE_SIM_TEST_LOCK_SCOPE": "worktree",
                                     "DUNE_SIM_TEST_LOCK_WAIT_SECONDS": "0.2"},
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "parallel")
        release.touch()
        self.assertEqual(first.wait(timeout=5), 0)

    def test_opted_in_same_worktree_remains_exclusive(self) -> None:
        started = self.base / "worktree-started"
        release = self.base / "worktree-release"
        scope = {**os.environ, "DUNE_SIM_TEST_LOCK_SCOPE": "worktree"}
        first = subprocess.Popen(self.command(self.sibling,
            "import pathlib,sys,time; pathlib.Path(sys.argv[1]).touch(); "
            "release=pathlib.Path(sys.argv[2]); "
            "\nwhile not release.exists(): time.sleep(.02)",
            str(started), str(release)), env=scope,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.addCleanup(lambda: first.kill() if first.poll() is None else None)
        wait_for(started)
        blocked = subprocess.run(self.command(self.sibling, "print('should-not-run')"),
                                 env={**scope, "DUNE_SIM_TEST_LOCK_WAIT_SECONDS": "0.2"},
                                 capture_output=True, text=True, timeout=5)
        self.assertEqual(blocked.returncode, 2)
        self.assertIn("worktree simulator test lock remained busy", blocked.stderr)
        self.assertNotIn("should-not-run", blocked.stdout)
        release.touch()
        self.assertEqual(first.wait(timeout=5), 0)

    def test_repository_runner_blocks_opted_in_same_worktree(self) -> None:
        started = self.base / "repository-linked-started"
        release = self.base / "repository-linked-release"
        first = subprocess.Popen(self.command(self.sibling,
            "import pathlib,sys,time; pathlib.Path(sys.argv[1]).touch(); "
            "release=pathlib.Path(sys.argv[2]); "
            "\nwhile not release.exists(): time.sleep(.02)",
            str(started), str(release)),
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.addCleanup(lambda: first.kill() if first.poll() is None else None)
        wait_for(started)
        blocked = subprocess.run(self.command(self.sibling, "print('should-not-run')"),
                                 env={**os.environ, "DUNE_SIM_TEST_LOCK_SCOPE": "worktree",
                                      "DUNE_SIM_TEST_LOCK_WAIT_SECONDS": "0.2"},
                                 capture_output=True, text=True, timeout=5)
        self.assertEqual(blocked.returncode, 2)
        self.assertIn("worktree simulator test lock remained busy", blocked.stderr)
        release.touch()
        self.assertEqual(first.wait(timeout=5), 0)

    def test_argv_and_exit_code_are_preserved(self) -> None:
        arguments = ["one two", "unicode-한글", "--flag"]
        result = subprocess.run(self.command(self.repo,
            "import json,sys; print(json.dumps(sys.argv[1:])); sys.exit(23)",
            *arguments), capture_output=True, text=True)
        self.assertEqual(result.returncode, 23)
        self.assertEqual(json.loads(result.stdout), arguments)

    def test_bounded_wait_fails_while_another_worktree_owns_lock(self) -> None:
        started = self.base / "bounded-first-started"
        release = self.base / "bounded-first-release"
        hold = ("import pathlib,sys,time\n"
                "pathlib.Path(sys.argv[1]).touch()\n"
                "while not pathlib.Path(sys.argv[2]).exists(): time.sleep(.02)\n")
        first = subprocess.Popen(self.command(self.repo, hold, str(started), str(release)),
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.addCleanup(lambda: first.kill() if first.poll() is None else None)
        wait_for(started)
        result = subprocess.run(self.command(self.sibling, "print('should-not-run')"),
                                env={**os.environ, "DUNE_SIM_TEST_LOCK_WAIT_SECONDS": "0.2"},
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 2)
        self.assertIn("lock remained busy", result.stderr)
        self.assertNotIn("should-not-run", result.stdout)
        release.touch()
        self.assertEqual(first.wait(timeout=5), 0)

    def test_inherited_descriptor_survives_shell_reentry(self) -> None:
        script = self.base / "runner.sh"
        started = self.base / "shell-child-started"
        release = self.base / "shell-child-release"
        second_started = self.base / "second-runner-started"
        script.write_text(
            "#!/bin/bash\n"
            "set -euo pipefail\n"
            "if [[ -n \"${DUNE_SIM_TEST_LOCK_FD:-}\" ]]; then\n"
            f"    python3 '{LOCK}' '{self.repo}' --verify\n"
            "else\n"
            f"    exec python3 '{LOCK}' '{self.repo}' -- \"$0\" \"$@\"\n"
            "fi\n"
            "python3 -c 'import pathlib,sys,time\n"
            "pathlib.Path(sys.argv[1]).touch()\n"
            "release=pathlib.Path(sys.argv[2])\n"
            "while not release.exists(): time.sleep(.02)' \"$1\" \"$2\"\n"
        )
        script.chmod(0o755)
        first = subprocess.Popen([str(script), str(started), str(release)],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.addCleanup(lambda: first.kill() if first.poll() is None else None)
        wait_for(started)
        second = subprocess.Popen(self.command(self.sibling,
                                  "import pathlib,sys; pathlib.Path(sys.argv[1]).touch()",
                                  str(second_started)), stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL)
        self.addCleanup(lambda: second.kill() if second.poll() is None else None)
        time.sleep(0.2)
        self.assertFalse(second_started.exists())
        release.touch()
        self.assertEqual(first.wait(timeout=5), 0)
        self.assertEqual(second.wait(timeout=5), 0)
        self.assertTrue(second_started.exists())

    def test_opted_in_inherited_descriptor_verifies_expected_worktree(self) -> None:
        verify = (
            "import os,subprocess,sys; "
            "result=subprocess.run([sys.executable,sys.argv[1],sys.argv[2],"
            "'--verify'],pass_fds=(int(os.environ['DUNE_SIM_TEST_LOCK_FD']),),"
            "capture_output=True,text=True); print(result.returncode); "
            "sys.exit(result.returncode)"
        )
        result = subprocess.run(self.command(self.sibling, verify, str(LOCK), str(self.sibling)),
                                env={**os.environ, "DUNE_SIM_TEST_LOCK_SCOPE": "worktree"},
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "0")
        mismatch = subprocess.run(self.command(self.sibling, verify, str(LOCK), str(self.repo)),
                                  env={**os.environ, "DUNE_SIM_TEST_LOCK_SCOPE": "worktree"},
                                  capture_output=True, text=True, timeout=5)
        self.assertEqual(mismatch.returncode, 2)

    def test_lock_released_after_failure_and_interruption(self) -> None:
        failed = subprocess.run(self.command(self.repo, "import sys; sys.exit(19)"),
                                capture_output=True, timeout=5)
        self.assertEqual(failed.returncode, 19)
        started = self.base / "started"
        sleeper = subprocess.Popen(self.command(self.repo,
            "import pathlib,sys,time; pathlib.Path(sys.argv[1]).touch(); time.sleep(30)",
            str(started)), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.addCleanup(lambda: sleeper.kill() if sleeper.poll() is None else None)
        wait_for(started)
        sleeper.terminate()
        self.assertLess(sleeper.wait(timeout=5), 0)
        after = subprocess.run(self.command(self.sibling, "print('acquired')"),
                               capture_output=True, text=True, timeout=5)
        self.assertEqual(after.returncode, 0)
        self.assertEqual(after.stdout.strip(), "acquired")

    def test_invalid_repository_and_stale_guard_fail_closed(self) -> None:
        invalid = subprocess.run(self.command(self.base, "print('ran')"),
                                 capture_output=True, text=True, timeout=5)
        self.assertEqual(invalid.returncode, 2)
        self.assertNotIn("ran", invalid.stdout)
        environment = os.environ.copy()
        environment["DUNE_SIM_TEST_LOCK_FD"] = "99"
        stale = subprocess.run([sys.executable, str(LOCK), str(self.repo), "--verify"],
                               env=environment, capture_output=True, text=True, timeout=5)
        self.assertEqual(stale.returncode, 2)

    def test_invalid_scope_and_nonlinked_opt_in_fail_closed(self) -> None:
        invalid_scope = subprocess.run(self.command(self.sibling, "print('ran')"),
                                       env={**os.environ, "DUNE_SIM_TEST_LOCK_SCOPE": "global"},
                                       capture_output=True, text=True, timeout=5)
        self.assertEqual(invalid_scope.returncode, 2)
        self.assertNotIn("ran", invalid_scope.stdout)
        main_opt_in = subprocess.run(self.command(self.repo, "print('ran')"),
                                     env={**os.environ, "DUNE_SIM_TEST_LOCK_SCOPE": "worktree"},
                                     capture_output=True, text=True, timeout=5)
        self.assertEqual(main_opt_in.returncode, 2)
        self.assertNotIn("ran", main_opt_in.stdout)


if __name__ == "__main__":
    unittest.main()
