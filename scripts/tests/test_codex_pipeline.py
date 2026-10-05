"""Behavior tests for explicit pipeline evidence and retry limits."""

import json
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest


SCRIPT_DIR = Path(__file__).resolve().parents[1]


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "scripts").mkdir()
        for name in ("codex-pipeline.py", "codex-check.py"):
            shutil.copy2(SCRIPT_DIR / name, self.root / "scripts" / name)
        (self.root / ".gitignore").write_text(".codex-checks/\n", encoding="utf-8")
        (self.root / "input.txt").write_text("original\n", encoding="utf-8")
        (self.root / "review.md").write_text("Reviewed change\n", encoding="utf-8")
        self.git("init", "-q")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.invalid")
        self.git("add", ".")
        self.git("commit", "-qm", "fixture")

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.root, check=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def cli(self, *args, timeout=10):
        return subprocess.run([sys.executable, "scripts/codex-pipeline.py", *args],
                              cwd=self.root, text=True, capture_output=True, timeout=timeout)

    def verify_args(self, action="run", ident="unit", command=None, context="fixture"):
        if command is None:
            command = [sys.executable, "-c", "print('ok')"]
        return [action, ident, "--context", context, "--scope", "unit", "--content-only", "--", *command]

    def state(self, ident="unit"):
        import hashlib
        key = hashlib.sha256(ident.encode()).hexdigest()[:24]
        return json.loads((self.root / ".codex-checks" / "pipeline" / f"check-{key}.json").read_text())

    def test_success_reuse_and_mutation(self):
        args = self.verify_args()
        self.assertEqual(self.cli(*args).returncode, 0)
        self.assertEqual(self.cli(*self.verify_args("check")).returncode, 0)
        self.assertNotEqual(self.cli(*args).returncode, 0)
        (self.root / "input.txt").write_text("changed\n", encoding="utf-8")
        self.assertNotEqual(self.cli(*self.verify_args("check")).returncode, 0)
        self.assertEqual(self.cli(*args).returncode, 0)

    def test_context_and_log_tamper(self):
        self.assertEqual(self.cli(*self.verify_args()).returncode, 0)
        self.assertNotEqual(self.cli(*self.verify_args("check", context="other")).returncode, 0)
        log = self.root / ".codex-checks" / "pipeline" / self.state()["attempts"][-1]["log"]
        log.write_text("tampered", encoding="utf-8")
        self.assertNotEqual(self.cli(*self.verify_args("check")).returncode, 0)

    def test_failure_retry_cap_survives_command_and_context_changes(self):
        fail = [sys.executable, "-c", "raise SystemExit(2)"]
        args = self.verify_args(command=fail)
        self.assertNotEqual(self.cli(*args).returncode, 0)
        retry = ["run", "unit", "--context", "fixed", "--scope", "unit", "--content-only",
                 "--retry-cause", "bad input", "--remediation", "fixed input",
                 "--retry-evidence", "review.md", "--", *fail]
        self.assertNotEqual(self.cli(*retry).returncode, 0)
        self.assertEqual(len(self.state()["attempts"]), 2)
        (self.root / "input.txt").write_text("changed\n", encoding="utf-8")
        third = retry[:]
        third[third.index("fixed")] = "fixed again"
        self.assertNotEqual(self.cli(*third).returncode, 0)
        self.assertEqual(len(self.state()["attempts"]), 2)

    def test_retry_needs_change_and_reason(self):
        fail = [sys.executable, "-c", "raise SystemExit(1)"]
        self.cli(*self.verify_args(command=fail))
        self.assertNotEqual(self.cli(*self.verify_args(command=fail)).returncode, 0)
        retry = ["run", "unit", "--context", "fixture", "--scope", "unit", "--content-only",
                 "--retry-cause", "failure", "--remediation", "claim",
                 "--retry-evidence", "review.md", "--", *fail]
        self.assertNotEqual(self.cli(*retry).returncode, 0)
        self.assertEqual(len(self.state()["attempts"]), 1)

    def test_timeout_and_interrupt_cleanup(self):
        sleeper = [sys.executable, "-c", "import time; time.sleep(5)"]
        args = ["run", "slow", "--context", "fixture", "--scope", "unit", "--timeout", "0.2", "--", *sleeper]
        timeout_result = self.cli(*args)
        self.assertNotEqual(timeout_result.returncode, 0)
        self.assertEqual(self.state("slow")["attempts"][-1]["status"], "timeout", timeout_result.stderr)
        command = [sys.executable, "scripts/codex-pipeline.py", "run", "signal", "--context", "fixture",
                   "--scope", "unit", "--", *sleeper]
        process = subprocess.Popen(command, cwd=self.root, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        time.sleep(0.3)
        process.send_signal(signal.SIGTERM)
        process.communicate(timeout=5)
        self.assertEqual(self.state("signal")["attempts"][-1]["status"], "interrupted")

    def test_timeout_stops_descendant(self):
        marker = self.root / "orphan.txt"
        child = f"import time; from pathlib import Path; time.sleep(1); Path({str(marker)!r}).write_text('orphan')"
        parent = f"import subprocess,sys,time; subprocess.Popen([sys.executable,'-c',{child!r}]); time.sleep(5)"
        result = self.cli("run", "tree", "--context", "fixture", "--scope", "unit",
                          "--timeout", "0.2", "--", sys.executable, "-c", parent)
        self.assertNotEqual(result.returncode, 0)
        time.sleep(1.1)
        self.assertFalse(marker.exists())

    def test_concurrent_duplicate_rejected(self):
        sleeper = [sys.executable, "-c", "import time; time.sleep(1)"]
        args = self.verify_args(command=sleeper)
        process = subprocess.Popen([sys.executable, "scripts/codex-pipeline.py", *args],
                                   cwd=self.root, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            time.sleep(0.2)
            duplicate = self.cli(*args)
            self.assertNotEqual(duplicate.returncode, 0)
            self.assertIn("already running", duplicate.stderr)
        finally:
            process.communicate(timeout=5)

    def test_document_and_review_staleness(self):
        self.assertEqual(self.cli("doc", "remember", "input.txt").returncode, 0)
        self.assertEqual(self.cli("doc", "check", "input.txt").returncode, 0)
        self.assertEqual(self.cli("phase", "Review", "passed", "--review-file", "review.md",
                                  "--source", "agent", "--context", "diff", "--scope", "architecture",
                                  "--content-only").returncode, 0)
        self.assertEqual(json.loads(self.cli("report").stdout)["phases"][0]["status"], "passed")
        (self.root / "input.txt").write_text("changed\n", encoding="utf-8")
        self.assertNotEqual(self.cli("doc", "check", "input.txt").returncode, 0)
        self.assertEqual(json.loads(self.cli("report").stdout)["phases"][0]["status"], "stale")

    def test_phase_requires_valid_evidence_or_skip_reason(self):
        self.assertNotEqual(self.cli("phase", "Build", "passed", "--evidence", "missing").returncode, 0)
        self.assertNotEqual(self.cli("phase", "UI", "skipped").returncode, 0)
        self.assertEqual(self.cli(*self.verify_args()).returncode, 0)
        self.assertEqual(self.cli("phase", "Build", "passed", "--evidence", "unit").returncode, 0)
        self.assertEqual(self.cli("phase", "UI", "skipped", "--reason", "no app change").returncode, 0)
        phases = {item["phase"]: item for item in json.loads(self.cli("report").stdout)["phases"]}
        self.assertEqual(phases["Build"]["status"], "passed")
        self.assertEqual(phases["UI"]["status"], "skipped")
        (self.root / "input.txt").write_text("new content\n", encoding="utf-8")
        phases = {item["phase"]: item for item in json.loads(self.cli("report").stdout)["phases"]}
        self.assertEqual(phases["UI"]["status"], "stale")

    def test_recover_abandoned_running_state(self):
        self.assertEqual(self.cli(*self.verify_args()).returncode, 0)
        import hashlib
        key = hashlib.sha256(b"unit").hexdigest()[:24]
        path = self.root / ".codex-checks" / "pipeline" / f"check-{key}.json"
        state = self.state()
        state["attempts"][-1]["status"] = "running"
        path.write_text(json.dumps(state), encoding="utf-8")
        self.assertEqual(self.cli("recover", "unit", "--reason", "runner terminated").returncode, 0)
        self.assertEqual(self.state()["attempts"][-1]["status"], "interrupted")

    def test_symlink_store_rejected(self):
        (self.root / ".codex-checks").symlink_to(self.root / "input.txt")
        self.assertNotEqual(self.cli("report").returncode, 0)


if __name__ == "__main__":
    unittest.main()
