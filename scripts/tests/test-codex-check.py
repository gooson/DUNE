#!/usr/bin/env python3
"""Integration tests for explicit verification receipts in isolated Git repos."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest


HELPER = Path(__file__).resolve().parents[1] / "codex-check.py"
PASS = [sys.executable, "-c", "print('passed')"]


class CodexCheckTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git("init", "-q")
        (self.root / ".gitignore").write_text(".codex-checks/\n")
        (self.root / "tracked.txt").write_text("original\n")
        self.git("add", ".")
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.com",
                 "commit", "-qm", "init")

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.root, check=True,
                              capture_output=True)

    def helper(self, action, command=PASS, context="test-context", content_only=False):
        mode = ["--content-only"] if content_only else []
        return subprocess.run(
            [sys.executable, str(HELPER), action, "unit", "--context", context,
             *mode, "--", *command], cwd=self.root, capture_output=True, text=True
        )

    def test_success_is_explicit_and_reusable(self):
        self.assertNotEqual(self.helper("check").returncode, 0)
        self.assertEqual(self.helper("run").returncode, 0)
        self.assertEqual(self.helper("check").returncode, 0)
        self.assertNotEqual(self.helper("check", context="other").returncode, 0)
        self.assertNotEqual(self.helper("check", command=[sys.executable, "-c", "pass"]).returncode, 0)

    def test_content_changes_and_deletion_invalidate(self):
        for change in (
            lambda: (self.root / "tracked.txt").write_text("changed\n"),
            lambda: (self.root / "new.txt").write_text("untracked\n"),
            lambda: (self.root / "tracked.txt").unlink(),
        ):
            self.assertEqual(self.helper("run").returncode, 0)
            change()
            self.assertNotEqual(self.helper("check").returncode, 0)
            self.git("reset", "--hard", "-q", "HEAD")
            (self.root / "new.txt").unlink(missing_ok=True)

    def test_failed_rerun_invalidates_success_and_preserves_log(self):
        self.assertEqual(self.helper("run").returncode, 0)
        fail = [sys.executable, "-c", "print('failure detail'); raise SystemExit(7)"]
        result = self.helper("run", command=fail)
        self.assertEqual(result.returncode, 7)
        self.assertNotEqual(self.helper("check").returncode, 0)
        logs = list((self.root / ".codex-checks").glob("*.log"))
        self.assertEqual(len(logs), 2)
        self.assertTrue(any("failure detail" in log.read_text() for log in logs))

    def test_missing_log_invalidates(self):
        self.assertEqual(self.helper("run").returncode, 0)
        next((self.root / ".codex-checks").glob("*.log")).unlink()
        self.assertNotEqual(self.helper("check").returncode, 0)

    def test_modified_log_invalidates(self):
        self.assertEqual(self.helper("run").returncode, 0)
        next((self.root / ".codex-checks").glob("*.log")).write_text("replaced")
        self.assertNotEqual(self.helper("check").returncode, 0)

    def test_index_only_change_invalidates(self):
        (self.root / "tracked.txt").write_text("staged\n")
        self.git("add", "tracked.txt")
        (self.root / "tracked.txt").write_text("original\n")
        self.assertEqual(self.helper("run").returncode, 0)
        self.git("reset", "-q", "HEAD", "--", "tracked.txt")
        self.assertNotEqual(self.helper("check").returncode, 0)

    def test_content_only_survives_commit_of_identical_content(self):
        (self.root / "tracked.txt").write_text("new content\n")
        self.git("add", "tracked.txt")
        self.assertEqual(self.helper("run", content_only=True).returncode, 0)
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.com",
                 "commit", "-qm", "next")
        self.assertEqual(self.helper("check", content_only=True).returncode, 0)
        self.assertNotEqual(self.helper("check").returncode, 0)
        (self.root / "tracked.txt").write_text("changed again\n")
        self.assertNotEqual(self.helper("check", content_only=True).returncode, 0)

    def test_default_mode_invalidates_on_head_only_commit(self):
        self.assertEqual(self.helper("run").returncode, 0)
        self.git("-c", "user.name=Test", "-c", "user.email=test@example.com",
                 "commit", "--allow-empty", "-qm", "empty")
        self.assertNotEqual(self.helper("check").returncode, 0)

    def test_content_only_detects_mode_change(self):
        self.assertEqual(self.helper("run", content_only=True).returncode, 0)
        path = self.root / "tracked.txt"
        path.chmod(path.stat().st_mode | 0o111)
        self.assertNotEqual(self.helper("check", content_only=True).returncode, 0)

    def test_change_during_run_prevents_success(self):
        modify = [sys.executable, "-c", "from pathlib import Path; Path('tracked.txt').write_text('during run')"]
        result = self.helper("run", command=modify)
        self.assertEqual(result.returncode, 1)
        self.assertNotEqual(self.helper("check", command=modify).returncode, 0)

    def test_interrupted_run_invalidates_previous_success(self):
        self.assertEqual(self.helper("run").returncode, 0)
        interrupt = [sys.executable, "-c", "import os,signal; os.kill(os.getppid(), signal.SIGKILL)"]
        result = self.helper("run", command=interrupt)
        self.assertNotEqual(result.returncode, 0)
        receipt = next((self.root / ".codex-checks").glob("*.json"))
        self.assertEqual(json.loads(receipt.read_text())["status"], "running")
        self.assertNotEqual(self.helper("check").returncode, 0)

    def test_check_while_running_fails_without_waiting(self):
        slow = [sys.executable, "-c", "import time; time.sleep(2)"]
        process = subprocess.Popen(
            [sys.executable, str(HELPER), "run", "unit", "--context", "test-context",
             "--", *slow], cwd=self.root, stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        try:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                receipts = list((self.root / ".codex-checks").glob("*.json"))
                if receipts and json.loads(receipts[0].read_text())["status"] == "running":
                    break
                time.sleep(0.02)
            else:
                self.fail("run did not write its running receipt")
            started = time.monotonic()
            self.assertNotEqual(self.helper("check", command=slow).returncode, 0)
            self.assertLess(time.monotonic() - started, 1.5)
        finally:
            process.wait(timeout=5)


if __name__ == "__main__":
    unittest.main()
