"""Behavior tests for explicit pipeline evidence and retry limits."""

import json
import importlib.util
import io
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock
from contextlib import redirect_stdout


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

    def test_killed_wrapper_cannot_overlap_live_child(self):
        command = [sys.executable, "-c", "import time; time.sleep(1.5)"]
        wrapper = subprocess.Popen([sys.executable, "scripts/codex-pipeline.py",
                                    *self.verify_args(command=command)], cwd=self.root,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            for _ in range(50):
                try:
                    if self.state()["attempts"][-1].get("child_pgid"):
                        break
                except FileNotFoundError:
                    pass
                time.sleep(0.02)
            else:
                self.fail("child process group was not recorded")
            wrapper.kill()
            wrapper.communicate(timeout=5)
            self.assertIn("still alive", self.cli("recover", "unit", "--reason", "wrapper killed").stderr)
            self.assertIn("live process group", self.cli(*self.verify_args(ident="other")).stderr)
            time.sleep(1.6)
            self.assertEqual(self.cli("recover", "unit", "--reason", "wrapper killed").returncode, 0)
            self.assertEqual(self.cli(*self.verify_args(ident="other")).returncode, 0)
        finally:
            if wrapper.poll() is None:
                wrapper.kill()
                wrapper.communicate(timeout=5)

    def test_missing_child_pid_blocks_recovery(self):
        self.cli(*self.verify_args())
        import hashlib
        path = self.root / ".codex-checks" / "pipeline" / f"check-{hashlib.sha256(b'unit').hexdigest()[:24]}.json"
        state = self.state()
        state["attempts"][-1]["status"] = "running"
        state["attempts"][-1].pop("child_pgid")
        path.write_text(json.dumps(state), encoding="utf-8")
        self.assertNotEqual(self.cli("recover", "unit", "--reason", "unknown").returncode, 0)
        self.assertNotEqual(self.cli(*self.verify_args(ident="other")).returncode, 0)

    def test_retry_ignored_evidence_tamper(self):
        fail = [sys.executable, "-c", "raise SystemExit(1)"]
        self.cli(*self.verify_args(command=fail))
        evidence = self.root / ".codex-checks" / "repair.txt"
        evidence.write_text("dependency recovered", encoding="utf-8")
        success = [sys.executable, "-c", "print('fixed')"]
        retry = ["run", "unit", "--context", "fixed", "--scope", "unit", "--content-only",
                 "--retry-cause", "dependency down", "--remediation", "dependency restored",
                 "--retry-evidence", ".codex-checks/repair.txt", "--", *success]
        self.assertEqual(self.cli(*retry).returncode, 0)
        check = self.verify_args("check", command=success, context="fixed")
        self.assertEqual(self.cli(*check).returncode, 0)
        evidence.write_text("altered", encoding="utf-8")
        self.assertIn("retry evidence changed", self.cli(*check).stderr)

    def test_head_and_mode_change_do_not_satisfy_content_retry(self):
        fail = [sys.executable, "-c", "raise SystemExit(1)"]
        self.cli("run", "unit", "--context", "fixture", "--scope", "unit", "--", *fail)
        self.git("commit", "--allow-empty", "-qm", "metadata only")
        retry = ["run", "unit", "--context", "fixture", "--scope", "unit",
                 "--content-only", "--retry-cause", "failed", "--remediation", "claimed repair",
                 "--retry-evidence", "review.md", "--", *fail]
        self.assertIn("changed content or context", self.cli(*retry).stderr)
        self.assertEqual(len(self.state()["attempts"]), 1)

    def test_failure_budget_resets_after_success_and_prunes_old_success(self):
        fail = [sys.executable, "-c", "raise SystemExit(1)"]
        good = [sys.executable, "-c", "print('ok')"]
        self.cli(*self.verify_args(command=fail))
        retry = ["run", "unit", "--context", "repair", "--scope", "unit", "--content-only",
                 "--retry-cause", "first cause", "--remediation", "fixed",
                 "--retry-evidence", "review.md", "--", *good]
        self.assertEqual(self.cli(*retry).returncode, 0)
        first_success_log = self.root / ".codex-checks" / "pipeline" / self.state()["attempts"][-1]["log"]
        (self.root / "input.txt").write_text("new input\n", encoding="utf-8")
        self.assertNotEqual(self.cli(*self.verify_args(command=fail, context="next")).returncode, 0)
        second_retry = retry[:]
        second_retry[second_retry.index("repair")] = "second repair"
        self.assertEqual(self.cli(*second_retry).returncode, 0)
        history = self.state()["attempts"]
        self.assertEqual(len(history), 4)
        self.assertFalse(first_success_log.exists())
        self.assertTrue(history[1]["log_pruned"])
        self.assertIn("command_hash", history[1])
        self.assertNotIn("command", history[1])
        self.assertTrue((self.root / ".codex-checks" / "pipeline" / history[0]["log"]).exists())

    def test_report_caches_fingerprint_and_log_hash(self):
        self.assertEqual(self.cli(*self.verify_args()).returncode, 0)
        self.assertEqual(self.cli("phase", "Build", "passed", "--evidence", "unit").returncode, 0)
        spec = importlib.util.spec_from_file_location("pipeline_under_test", SCRIPT_DIR / "codex-pipeline.py")
        pipeline = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(pipeline)
        fingerprint = pipeline.CHECK.fingerprint
        file_hash = pipeline.CHECK.file_hash
        with mock.patch.object(pipeline.CHECK, "repo_root", return_value=self.root.resolve()), \
             mock.patch.object(pipeline.CHECK, "fingerprint", wraps=fingerprint) as fp, \
             mock.patch.object(pipeline.CHECK, "file_hash", wraps=file_hash) as hashed, \
             mock.patch.object(sys, "argv", ["codex-pipeline.py", "report"]), redirect_stdout(io.StringIO()):
            self.assertEqual(pipeline.main(), 0)
        self.assertEqual(fp.call_count, 1)
        self.assertEqual(hashed.call_count, 1)

    def test_status_filters_before_validating_other_checks(self):
        self.assertEqual(self.cli(*self.verify_args()).returncode, 0)
        self.assertEqual(self.cli(*self.verify_args(ident="other")).returncode, 0)
        other_log = self.root / ".codex-checks" / "pipeline" / self.state("other")["attempts"][-1]["log"]
        other_log.write_text("tampered", encoding="utf-8")
        status = self.cli("status", "unit")
        self.assertEqual(status.returncode, 0)
        checks = json.loads(status.stdout)["checks"]
        self.assertEqual([item["id"] for item in checks], ["unit"])
        self.assertEqual(checks[0]["status"], "success")

    def test_symlink_store_rejected(self):
        (self.root / ".codex-checks").symlink_to(self.root / "input.txt")
        self.assertNotEqual(self.cli("report").returncode, 0)


if __name__ == "__main__":
    unittest.main()
