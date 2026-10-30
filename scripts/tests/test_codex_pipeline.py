"""Behavior tests for explicit pipeline evidence and retry limits."""

import json
import fcntl
import hashlib
import os
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

    def prepare_lock_fixture(self):
        self.root = self.root.resolve()
        spec = importlib.util.spec_from_file_location("pipeline_lock_test", SCRIPT_DIR / "codex-pipeline.py")
        pipeline = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(pipeline)
        for name in pipeline.LOCK_SOURCES:
            target = self.root / name
            target.parent.mkdir(exist_ok=True, parents=True)
            shutil.copy2(SCRIPT_DIR.parent / name, target)
        self.git("add", "scripts")
        self.git("commit", "-qm", "reviewed runner fixture")
        self.pipeline = pipeline
        self.store = pipeline.store_for(self.root)
        self.lock_command = ["scripts/test-ui.sh", "--no-regen", "--only-testing", "DUNEUITests/Fake/testCase"]
        return pipeline

    def busy_lock_run(self, context="fixture", retry=False):
        # Only temporary-repository file locks are used. The real runner must
        # exit before any simulator query, build, installation, or test starts.
        spec = importlib.util.spec_from_file_location("lock_fixture", SCRIPT_DIR / "lib/simulator-test-lock.py")
        lock = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(lock)
        path = lock.lock_path(self.root)
        worktree_path, _ = lock.worktree_lock_path(self.root)
        fd = lock.open_lock(path)
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        args = self.verify_args(command=self.lock_command, context=context)
        if retry:
            position = args.index("--")
            args[position:position] = ["--retry-cause", "launch failure", "--remediation", "launch recovered",
                                      "--retry-evidence", "review.md"]
        env = os.environ.copy()
        env["DUNE_SIM_TEST_LOCK_WAIT_SECONDS"] = "0"
        for key in ("DUNE_SIM_TEST_LOCK_FD", "DUNE_SIM_TEST_WORKTREE_LOCK_FD", "DUNE_SIM_TEST_LOCK_SCOPE",
                    "DUNE_UI_WATCHDOG_ACTIVE", "BASH_ENV", "ENV"):
            env.pop(key, None)
        try:
            return subprocess.run([sys.executable, "scripts/codex-pipeline.py", *args], cwd=self.root,
                                  env=env, capture_output=True, text=True, timeout=15)
        finally:
            os.close(fd)
            path.unlink(missing_ok=True)
            worktree_path.unlink(missing_ok=True)

    def archived_lock_attempt(self, number=1):
        # Synthetic archived receipt, with the same strict shape as the real
        # busy-lock fixture. Negative tests vary one independently checked field.
        p = self.pipeline
        fingerprint = p.CHECK.fingerprint(self.root, True)
        log = f"check-{p.key_for('unit')}-{number:032x}.log"
        output = b"Simulator test lock: repository simulator test lock remained busy for 0s\n"
        (self.store / log).write_bytes(output)
        return {"status": "failed", "exit_code": 2, "command": self.lock_command,
                "context": "fixture", "scope": "unit", "content_only": True,
                "before": fingerprint, "after": fingerprint, "before_content": fingerprint,
                "after_content": fingerprint, "log": log, "log_hash": hashlib.sha256(output).hexdigest()}

    def save_lock_history(self, attempts):
        self.pipeline.write_json(self.store / f"check-{self.pipeline.key_for('unit')}.json",
                                 {"schema_version": 1, "id": "unit", "worktree": str(self.root), "attempts": attempts})

    def write_lock_audit(self, attempt):
        audit = {"schema_version": 1, "check_id": "unit", "worktree": str(self.root),
                 "attempt_log": attempt["log"], "attempt_hash": self.pipeline.object_hash(attempt),
                 "source_revision": self.git("rev-parse", "HEAD").stdout.decode().strip(),
                 "provenance": {"kind": "operator-attested", "reviewer": "contract fixture",
                                "source": "Fixture copies reviewed source closure before invocation.",
                                "environment": "Known test Python/PATH, no shell startup hooks; file lock held before start."},
                 "evidence": [{"file": "review.md", "hash": self.pipeline.CHECK.file_hash(self.root / "review.md")}]}
        path = self.root / ".codex-checks" / "lock-audit.json"
        path.write_text(json.dumps(audit))
        return path, audit

    def classify_lock(self):
        return self.cli("defer-lock", "unit", "--audit-file", ".codex-checks/lock-audit.json")

    def test_genuine_prestart_lock_is_audited_non_success_without_history_mutation(self):
        self.prepare_lock_fixture()
        result = self.busy_lock_run()
        self.assertNotEqual(result.returncode, 0, result.stderr)
        original = self.state()
        attempt = original["attempts"][-1]
        self.assertEqual(attempt["exit_code"], 2)
        self.assertEqual((self.store / attempt["log"]).read_bytes(),
                         b"Simulator test lock: repository simulator test lock remained busy for 0s\n")
        self.write_lock_audit(attempt)
        before = self.pipeline.CHECK.fingerprint(self.root)
        result = self.classify_lock()
        self.assertEqual(result.returncode, 1)
        self.assertIn("deferred (operator-attested", result.stdout, result.stderr)
        self.assertEqual(self.state()["attempts"], original["attempts"])
        self.assertEqual(before, self.pipeline.CHECK.fingerprint(self.root))
        report = json.loads(self.cli("status", "unit").stdout)["checks"][0]
        self.assertEqual(report["status"], "deferred")
        self.assertEqual(report["original_status"], "failed")
        self.assertFalse(report["test_success"])
        self.assertNotEqual(self.cli(*self.verify_args("check", command=self.lock_command)).returncode, 0)
        self.assertNotEqual(self.cli("phase", "UI", "passed", "--evidence", "unit").returncode, 0)
        self.assertIn("already recorded", self.classify_lock().stderr)
        # No retry metadata/content change needed for a deferred-only history,
        # but the next invocation must acquire the actual lock again.
        self.assertIn("direct scripts/test-ui.sh", self.cli(*self.verify_args()).stderr)
        again = self.busy_lock_run()
        self.assertNotEqual(again.returncode, 0)
        self.assertEqual(len(self.state()["attempts"]), 2)
        self.assertEqual(self.state()["attempts"][0], original["attempts"][0])

    def test_spoofed_command_output_and_non_lock_failures_rejected(self):
        self.prepare_lock_fixture()
        mutations = [
            ("fake command", {"command": [sys.executable, "-c", "print('lock busy')"]}),
            ("shell wrapper", {"command": ["bash", "scripts/test-ui.sh"]}),
            ("dry run", {"command": ["scripts/test-ui.sh", "--dry-run"]}),
            ("cleanup", {"command": ["scripts/test-ui.sh", "--cleanup-simulators"]}),
            ("unknown argument", {"command": ["scripts/test-ui.sh", "--unknown"]}),
            ("real timeout", {"status": "timeout", "exit_code": None}),
            ("runner timeout", {"exit_code": 124}),
            ("app failure", {"exit_code": 65}),
            ("unknown exit", {"exit_code": None}),
            ("success", {"status": "success", "exit_code": 0}),
            ("changed fingerprint", {"after_content": "0" * 64}),
        ]
        for label, mutation in mutations:
            with self.subTest(label=label):
                attempt = self.archived_lock_attempt()
                attempt.update(mutation)
                self.save_lock_history([attempt])
                self.write_lock_audit(attempt)
                result = self.classify_lock()
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("lock_deferrals", self.state(), result.stdout)
        for output in (b"BUILD STARTED\nSimulator test lock: repository simulator test lock remained busy for 0s\n",
                       b"Simulator test lock: repository simulator test lock remained busy for 0s\nTest failed\n",
                       b"Simulator test lock: unknown failure\n", b"", b"Executed 0 tests\n"):
            with self.subTest(output=output):
                attempt = self.archived_lock_attempt()
                (self.store / attempt["log"]).write_bytes(output)
                attempt["log_hash"] = hashlib.sha256(output).hexdigest()
                self.save_lock_history([attempt])
                self.write_lock_audit(attempt)
                self.assertIn("exclusive pre-start", self.classify_lock().stderr)
                self.assertNotIn("lock_deferrals", self.state())

    def test_missing_tampered_symlink_and_wrong_path_logs_rejected(self):
        self.prepare_lock_fixture()
        for kind in ("missing", "tampered", "symlink", "outside"):
            with self.subTest(kind=kind):
                attempt = self.archived_lock_attempt()
                log = self.store / attempt["log"]
                if kind == "missing":
                    log.unlink()
                elif kind == "tampered":
                    log.write_bytes(b"changed")
                elif kind == "symlink":
                    log.unlink()
                    log.symlink_to(self.root / "review.md")
                else:
                    attempt["log"] = "../outside.log"
                self.save_lock_history([attempt])
                self.write_lock_audit(attempt)
                self.assertNotIn("deferred (", self.classify_lock().stdout)
                self.assertNotIn("lock_deferrals", self.state())
                log.unlink(missing_ok=True)

    def test_source_and_provenance_must_be_reviewed_and_bound(self):
        self.prepare_lock_fixture()
        attempt = self.archived_lock_attempt()
        for field, value in (("source_revision", None), ("source_revision", "HEAD"),
                             ("provenance", {}), ("evidence", []), ("attempt_hash", "0" * 64)):
            with self.subTest(field=field, value=value):
                self.save_lock_history([attempt])
                path, audit = self.write_lock_audit(attempt)
                audit[field] = value
                path.write_text(json.dumps(audit))
                self.assertNotIn("deferred (", self.classify_lock().stdout)
                self.assertNotIn("lock_deferrals", self.state())
        for name in ("scripts/test-ui.sh", "scripts/lib/simulator-boot.sh", "scripts/lib/command-deadline.py"):
            with self.subTest(source=name):
                self.save_lock_history([attempt])
                self.write_lock_audit(attempt)
                source = self.root / name
                original = source.read_bytes()
                source.write_bytes(original + b"\n# modified\n")
                self.assertIn("unreviewed", self.classify_lock().stderr)
                source.write_bytes(original)
        source = self.root / "scripts/test-ui.sh"
        original = source.read_bytes()
        source.unlink()
        source.symlink_to(SCRIPT_DIR / "test-ui.sh")
        self.assertIn("symlink rejected", self.classify_lock().stderr)
        source.unlink()
        source.write_bytes(original)
        source.chmod(0o755)

    def test_tampered_audit_evidence_history_and_source_revoke_deferral(self):
        self.prepare_lock_fixture()
        attempt = self.archived_lock_attempt()
        self.save_lock_history([attempt])
        audit_path, _ = self.write_lock_audit(attempt)
        self.classify_lock()
        state_path = self.store / f"check-{self.pipeline.key_for('unit')}.json"
        for target in (audit_path, self.root / "review.md", self.store / attempt["log"],
                       self.root / "scripts/lib/simulator-test-lock.py", state_path):
            with self.subTest(target=target.name):
                original = target.read_bytes()
                if target == state_path:
                    changed = json.loads(original)
                    changed["attempts"][0]["context"] = "tampered"
                    target.write_text(json.dumps(changed))
                else:
                    target.write_bytes(original + b"\n")
                status = json.loads(self.cli("status", "unit").stdout)["checks"][0]
                self.assertEqual(status["status"], "invalid-audit")
                result = self.cli(*self.verify_args(command=self.lock_command))
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(len(self.state()["attempts"]), 1)
                target.write_bytes(original)

    def test_real_failure_before_deferral_still_requires_original_remediation(self):
        self.prepare_lock_fixture()
        failure = self.archived_lock_attempt(1)
        failure.update(exit_code=124, context="original-launch")
        deferred = self.archived_lock_attempt(2)
        deferred.update(context="recovered-launch")
        self.save_lock_history([failure, deferred])
        self.write_lock_audit(deferred)
        self.classify_lock()
        self.assertIn("retry requires", self.cli(*self.verify_args(command=self.lock_command, context="recovered-launch")).stderr)
        unchanged = self.busy_lock_run(context="original-launch", retry=True)
        self.assertIn("changed content or context", unchanged.stderr)
        self.assertEqual(len(self.state()["attempts"]), 2)
        # Compare against the real failure, not the newer deferred attempt.
        allowed = self.busy_lock_run(context="recovered-launch", retry=True)
        self.assertNotEqual(allowed.returncode, 0)
        self.assertEqual(len(self.state()["attempts"]), 3, allowed.stderr)
        self.assertEqual(self.state()["attempts"][:2], [failure, deferred])
        self.assertEqual(self.state()["attempts"][-1]["retry_cause"], "launch failure")
        self.assertEqual(self.state()["attempts"][-1]["exit_code"], 2)

    def test_two_real_failures_plus_deferral_cannot_execute(self):
        self.prepare_lock_fixture()
        failures = [self.archived_lock_attempt(1), self.archived_lock_attempt(2)]
        for failure in failures:
            failure["exit_code"] = 124
        deferred = self.archived_lock_attempt(3)
        self.save_lock_history([*failures, deferred])
        self.write_lock_audit(deferred)
        self.classify_lock()
        result = self.busy_lock_run(context="changed", retry=True)
        self.assertIn("retry limit reached", result.stderr)
        self.assertEqual(self.state()["attempts"], [*failures, deferred])

    def test_reviewed_legacy_source_and_sixty_second_worktree_message(self):
        self.prepare_lock_fixture()
        # Reconstruct the reviewed pre-resource-budget runner exactly, without
        # requiring the main repository's old commits in the isolated fixture.
        runner = self.root / "scripts/test-ui.sh"
        text = "".join(line for line in runner.read_text().splitlines(keepends=True)
                       if "xcodebuild-resources.sh" not in line
                       and line != "configure_xcodebuild_resources ui\n"
                       and "XCODEBUILD_RESOURCE_ARGS" not in line)
        runner.write_text(text)
        (self.root / "scripts/lib/xcodebuild-resources.sh").unlink()
        self.git("add", "scripts")
        self.git("commit", "-qm", "legacy runner fixture")
        self.assertEqual(self.pipeline.lock_source_profile(self.root),
                         "90cbfa3a0ddf8cbd59be62a6f6483251e6f0a2830df5d27ca76563a0b98552dd")
        attempt = self.archived_lock_attempt()
        output = b"Simulator test lock: worktree simulator test lock remained busy for 60s\n"
        (self.store / attempt["log"]).write_bytes(output)
        attempt["log_hash"] = hashlib.sha256(output).hexdigest()
        self.save_lock_history([attempt])
        self.write_lock_audit(attempt)
        result = self.classify_lock()
        self.assertIn("deferred (operator-attested", result.stdout, result.stderr)

    def test_unknown_historical_source_is_rejected_even_if_current_source_is_reviewed(self):
        self.prepare_lock_fixture()
        source = self.root / "scripts/lib/simulator-test-lock.py"
        original = source.read_bytes()
        source.write_bytes(original + b"\n# unreviewed historical version\n")
        self.git("add", "scripts")
        self.git("commit", "-qm", "unreviewed historical source")
        source.write_bytes(original)
        attempt = self.archived_lock_attempt()
        self.save_lock_history([attempt])
        self.write_lock_audit(attempt)
        self.assertIn("unreviewed simulator", self.classify_lock().stderr)
        self.assertNotIn("lock_deferrals", self.state())

    def test_later_success_retains_all_audited_history_and_checks_audit_integrity(self):
        self.prepare_lock_fixture()
        old_success = self.archived_lock_attempt(1)
        old_success.update(status="success", exit_code=0)
        deferred = self.archived_lock_attempt(2)
        self.save_lock_history([old_success, deferred])
        audit, _ = self.write_lock_audit(deferred)
        self.classify_lock()
        args = mock.Mock(id="unit", command=self.lock_command, context="fixture", scope="unit",
                         content_only=True, timeout=1, retry_cause=None, remediation=None, retry_evidence=None)
        child = mock.Mock(pid=999999)
        child.wait.return_value = 0
        # Simulate only a successful subprocess return to exercise receipt
        # preservation; this is not claimed as a UI/test execution.
        original_popen = subprocess.Popen

        def execute(command, *positional, **keywords):
            return child if command == self.lock_command else original_popen(command, *positional, **keywords)

        with mock.patch.object(self.pipeline.subprocess, "Popen", side_effect=execute), redirect_stdout(io.StringIO()):
            self.assertEqual(self.pipeline.run_check(self.root, self.store, args), 0)
        self.assertEqual(self.state()["attempts"][:2], [old_success, deferred])
        self.assertTrue((self.store / old_success["log"]).is_file())
        self.assertTrue((self.store / deferred["log"]).is_file())
        self.assertEqual(self.cli(*self.verify_args("check", command=self.lock_command)).returncode, 0)
        audit.write_text(audit.read_text() + "\n")
        self.assertNotEqual(self.cli(*self.verify_args("check", command=self.lock_command)).returncode, 0)

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
        try:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                try:
                    attempt = self.state("signal")["attempts"][-1]
                    if attempt.get("status") == "running" and attempt.get("child_pid"):
                        break
                except FileNotFoundError:
                    pass
                time.sleep(0.02)
            else:
                self.fail("signal check did not record a running child within 5s")
            process.send_signal(signal.SIGTERM)
            process.communicate(timeout=5)
            self.assertEqual(self.state("signal")["attempts"][-1]["status"], "interrupted")
            with self.assertRaises(ProcessLookupError):
                os.killpg(attempt["child_pgid"], 0)
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.communicate(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.communicate(timeout=5)

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
