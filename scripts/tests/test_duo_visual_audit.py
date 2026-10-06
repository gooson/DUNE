"""File-only contracts for the Duo VisualAudit host handshake."""

import importlib.util
import io
import json
import select
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
from unittest.mock import MagicMock


SCRIPT = Path(__file__).resolve().parents[1] / "duo-visual-audit.py"
SPEC = importlib.util.spec_from_file_location("duo_visual_audit", SCRIPT)
audit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit)
APP_ID = "11111111-2222-3333-4444-555555555555"
PORTS = ("Port:\nDisplay class: 0\nUUID: AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA\n"
         "Default width: 1398\nDefault height: 2034\n"
         "Port:\nDisplay class: 0\nUUID: BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB\n"
         "Default width: 2007\nDefault height: 2853\n")


class CaptureContracts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.output = self.base / "output"
        self.output.mkdir()
        self.container = self.base / "Application"
        self.ack = self.container / APP_ID / "tmp" / "dune-visual-audit-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.ack"
        self.ack.parent.mkdir(parents=True)
        self.ack.with_suffix(".ack.txt").write_text("hierarchy")
        self.captures = io.StringIO()
        self.checkpoints = io.StringIO()

    def line(self, action="ordinary", seconds=30, ack=None):
        return (f"DUNE_VISUAL_AUDIT_READY {action} [Test.swift:10] "
                f"DEADLINE={time.time() + seconds} ACK={ack or self.ack}\n")

    def run_checkpoint(self, line, display="all"):
        return audit.capture_checkpoint(line, 1, self.output, "DEVICE", display,
                                        self.container.resolve(), self.captures, self.checkpoints)

    def ledger(self):
        return json.loads(self.checkpoints.getvalue().splitlines()[-1])

    @staticmethod
    def screenshot(argv, **_kwargs):
        Path(argv[-1]).write_bytes(b"PNG")
        return subprocess.CompletedProcess(argv, 0)

    @patch.object(audit.subprocess, "run")
    @patch.object(audit.subprocess, "check_output", return_value=PORTS)
    def test_successful_two_display_capture_ack_and_hierarchy(self, enumerate_mock, screenshot_mock):
        screenshot_mock.side_effect = self.screenshot
        self.run_checkpoint(self.line())
        self.assertTrue(self.ack.is_file())
        self.assertEqual((self.output / "001-hierarchy.txt").read_text(), "hierarchy")
        self.assertEqual(len(list(self.output.glob("*.png"))), 2)
        self.assertEqual(len(self.captures.getvalue().splitlines()), 2)
        self.assertTrue(self.ledger()["valid_evidence"])
        self.assertTrue(self.ledger()["acknowledged"])
        self.assertEqual(enumerate_mock.call_count, 1)

    @patch.object(audit.subprocess, "run")
    @patch.object(audit.subprocess, "check_output")
    def test_expired_deadline_fails_without_simulator_calls(self, enumerate_mock, screenshot_mock):
        with self.assertRaisesRegex(RuntimeError, "expired"):
            self.run_checkpoint(self.line(seconds=-1))
        enumerate_mock.assert_not_called()
        screenshot_mock.assert_not_called()
        self.assertFalse(self.ack.exists())
        self.assertFalse(self.ledger()["valid_evidence"])

    @patch.object(audit.subprocess, "run", side_effect=subprocess.TimeoutExpired("screenshot", 1))
    @patch.object(audit.subprocess, "check_output", return_value=PORTS)
    def test_screenshot_timeout_fails_closed(self, _enumerate_mock, _screenshot_mock):
        (self.output / "001-1398x2034.png").write_bytes(b"stale")
        with self.assertRaisesRegex(RuntimeError, "Capture failed"):
            self.run_checkpoint(self.line())
        self.assertFalse(self.ack.exists())
        self.assertFalse((self.output / "001-1398x2034.png").exists())
        self.assertFalse(self.ledger()["valid_evidence"])
        self.assertIn("\t124\t0", self.captures.getvalue())

    @patch.object(audit.subprocess, "run", return_value=subprocess.CompletedProcess([], 0))
    @patch.object(audit.subprocess, "check_output", return_value=PORTS)
    def test_zero_exit_without_new_image_is_not_valid_evidence(self, _enumerate_mock, _screenshot_mock):
        with self.assertRaisesRegex(RuntimeError, "Capture failed"):
            self.run_checkpoint(self.line())
        self.assertFalse(self.ack.exists())
        self.assertFalse(self.ledger()["valid_evidence"])
        self.assertIn("\t0\t0", self.captures.getvalue())

    @patch.object(audit.subprocess, "run")
    @patch.object(audit.subprocess, "check_output", return_value=PORTS)
    def test_no_matching_display_fails_closed(self, _enumerate_mock, screenshot_mock):
        with self.assertRaisesRegex(RuntimeError, "No matching"):
            self.run_checkpoint(self.line(), display="999x999")
        screenshot_mock.assert_not_called()
        self.assertFalse(self.ledger()["valid_evidence"])

    @patch.object(audit.subprocess, "run")
    @patch.object(audit.subprocess, "check_output")
    def test_unsafe_ack_path_fails_before_capture(self, enumerate_mock, screenshot_mock):
        unsafe = self.base / "dune-visual-audit-aaaaaaaa.ack"
        with self.assertRaisesRegex(RuntimeError, "Unexpected capture acknowledgement path"):
            self.run_checkpoint(self.line(ack=unsafe))
        enumerate_mock.assert_not_called()
        screenshot_mock.assert_not_called()
        self.assertFalse(unsafe.exists())
        self.assertFalse(self.ledger()["valid_evidence"])

    @patch.object(audit.subprocess, "run")
    @patch.object(audit.subprocess, "check_output", return_value=PORTS)
    def test_fold_checkpoint_waits_for_sequence_release_then_captures(self, _enumerate_mock, screenshot_mock):
        screenshot_mock.side_effect = self.screenshot
        observed = []

        def release():
            pending_path = self.output / "pending.json"
            for _ in range(100):
                if pending_path.exists():
                    pending = json.loads(pending_path.read_text())
                    observed.append(pending)
                    Path(pending["release_file"]).touch()
                    break
                time.sleep(0.01)
            refresh = self.ack.with_suffix(".ack.refresh")
            for _ in range(100):
                if refresh.exists():
                    self.ack.with_suffix(".ack.txt").write_text("postfold hierarchy")
                    self.ack.with_suffix(".ack.ready").touch()
                    return
                time.sleep(0.01)

        thread = threading.Thread(target=release)
        thread.start()
        try:
            with patch("sys.stdout", new_callable=io.StringIO) as printed:
                self.run_checkpoint("runner: " + self.line("FOLD:partiallyOpen", seconds=120))
            self.assertIn("FOLD_PENDING partiallyOpen", printed.getvalue())
            self.assertEqual(observed[0]["sequence"], 1)
            self.assertEqual(observed[0]["state"], "partiallyOpen")
            self.assertFalse((self.output / "pending.json").exists())
            self.assertTrue(self.ledger()["valid_evidence"])
            self.assertEqual(len(list(self.output.glob("*.png"))), 2)
            self.assertEqual((self.output / "001-hierarchy.txt").read_text(), "postfold hierarchy")
            self.assertFalse(self.ack.with_suffix(".ack.refresh").exists())
            self.assertFalse(self.ack.with_suffix(".ack.ready").exists())
        finally:
            thread.join(timeout=2)

    @patch.object(audit.subprocess, "run")
    @patch.object(audit.subprocess, "check_output")
    def test_fold_without_capture_budget_fails_and_clears_pending(self, enumerate_mock, screenshot_mock):
        with self.assertRaisesRegex(RuntimeError, "insufficient time"):
            self.run_checkpoint(self.line("FOLD:openFlat", seconds=10))
        self.assertFalse((self.output / "pending.json").exists())
        self.assertFalse(self.ledger()["valid_evidence"])
        enumerate_mock.assert_not_called()
        screenshot_mock.assert_not_called()

    @patch.object(audit.subprocess, "run")
    @patch.object(audit.subprocess, "check_output")
    def test_fold_refresh_timeout_has_invalid_ledger_and_no_ack(self, enumerate_mock, screenshot_mock):
        def release():
            pending_path = self.output / "pending.json"
            for _ in range(100):
                if pending_path.exists():
                    pending = json.loads(pending_path.read_text())
                    Path(pending["release_file"]).touch()
                    return
                time.sleep(0.01)

        thread = threading.Thread(target=release)
        thread.start()
        original_refresh = audit.refresh_fold_hierarchy
        try:
            with patch.object(audit, "refresh_fold_hierarchy",
                              side_effect=lambda ack, deadline: original_refresh(ack, deadline, timeout=0.05)):
                with patch("sys.stdout", new_callable=io.StringIO):
                    with self.assertRaisesRegex(RuntimeError, "refresh timed out"):
                        self.run_checkpoint(self.line("FOLD:openFlat", seconds=120))
            self.assertFalse(self.ack.exists())
            self.assertFalse(self.ack.with_suffix(".ack.refresh").exists())
            self.assertFalse(self.ack.with_suffix(".ack.ready").exists())
            self.assertFalse(self.ledger()["valid_evidence"])
            enumerate_mock.assert_not_called()
            screenshot_mock.assert_not_called()
        finally:
            thread.join(timeout=2)

    @patch.object(audit.subprocess, "Popen")
    def test_interruption_terminates_child_process(self, popen_mock):
        class InterruptedOutput:
            def __iter__(self):
                raise KeyboardInterrupt

        process = MagicMock()
        process.stdout = InterruptedOutput()
        popen_mock.return_value = process
        with patch.object(audit.sys, "argv", ["duo-visual-audit.py", str(self.output),
                                            "DEVICE", "all", "fake-runner"]):
            with self.assertRaises(KeyboardInterrupt):
                audit.main()
        process.terminate.assert_called_once()
        process.wait.assert_called_once()

    @patch.object(audit.subprocess, "Popen")
    def test_outer_simulator_lock_is_inherited_by_test_runner(self, popen_mock):
        process = MagicMock()
        process.stdout = []
        process.wait.return_value = 0
        popen_mock.return_value = process
        with (self.base / "lock").open("w") as lock:
            with patch.dict(audit.os.environ, {"DUNE_SIM_TEST_LOCK_FD": str(lock.fileno())}), \
                    patch.object(audit.sys, "argv", ["duo-visual-audit.py", str(self.output),
                                                   "DEVICE", "all", "fake-runner"]):
                self.assertEqual(audit.main(), 0)
            self.assertEqual(popen_mock.call_args.kwargs["pass_fds"], (lock.fileno(),))

    @patch.object(audit, "stop_runner", side_effect=PermissionError("descendant cleanup denied"))
    @patch.object(audit, "runner_lines", side_effect=TimeoutError("SDK cleanup exceeded"))
    @patch.object(audit.subprocess, "Popen")
    def test_cleanup_denial_preserves_original_timeout_and_receipt(self, popen_mock, _lines, _stop):
        process = MagicMock()
        process.pid = 123
        process.poll.return_value = -15
        popen_mock.return_value = process
        with patch.object(audit.sys, "argv", ["duo-visual-audit.py", str(self.output), "DEVICE", "all", "fake-runner"]):
            with self.assertRaisesRegex(TimeoutError, "SDK cleanup exceeded"):
                audit.main()
        receipt = json.loads((self.output / "runner-result.json").read_text())
        self.assertEqual(receipt["cleanup_error"], "descendant cleanup denied")
        self.assertEqual(receipt["termination"], "SDK cleanup exceeded")
        self.assertEqual(receipt["returncode"], -15)


class DiagnosticOutputTests(unittest.TestCase):
    def test_error_selector_stack_frames_do_not_flood_output(self):
        self.assertFalse(audit.should_report_line("7 -[IDEScheme operation:outError:error:] (in IDEFoundation)"))
        self.assertFalse(audit.should_report_line("note: compiling views"))
        for diagnostic in ["error: build failed", "/tmp/App.swift:42:12: error: invalid member", "Test Case 'case' passed", "** TEST FAILED **", "Executed 2 tests, with 0 failures"]:
            self.assertTrue(audit.should_report_line(diagnostic), diagnostic)


class RunnerCleanupContracts(unittest.TestCase):
    def runner(self, code):
        process = subprocess.Popen([sys.executable, "-u", "-c", code],
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, start_new_session=True)
        self.addCleanup(process.stdout.close)
        self.addCleanup(lambda: audit.stop_runner(process) if process.poll() is None else None)
        return process

    def test_completed_runner_preserves_output(self):
        process = self.runner("print(\"Test Suite 'Selected tests' passed\"); print('receipt')")
        self.assertEqual(list(audit.runner_lines(process, cleanup_timeout=1)),
                         ["Test Suite 'Selected tests' passed\n", "receipt\n"])
        self.assertEqual(process.wait(), 0)

    def test_cleanup_hang_is_bounded_and_owned_runner_is_reaped(self):
        process = self.runner("import time; print(\"Test Suite 'Selected tests' failed\"); time.sleep(30)")
        with self.assertRaisesRegex(TimeoutError, "cleanup exceeded"):
            list(audit.runner_lines(process, cleanup_timeout=0.1))
        audit.stop_runner(process)
        self.assertIsNotNone(process.returncode)

    def test_stdout_eof_does_not_hide_cleanup_hang(self):
        process = self.runner("import os,time; print(\"Test Suite 'Selected tests' passed\"); os.close(1); os.close(2); time.sleep(30)")
        with self.assertRaises(TimeoutError):
            list(audit.runner_lines(process, cleanup_timeout=0.1))

    def test_new_case_clears_cleanup_deadline(self):
        process = self.runner("import time; print('exceeded execution time allowance'); print(\"Test Case 'next' started.\"); time.sleep(0.3); print(\"Test Case 'next' passed\")")
        lines = list(audit.runner_lines(process, cleanup_timeout=0.1))
        self.assertIn("Test Case 'next' passed\n", lines)
        self.assertEqual(process.wait(), 0)

    def test_cleanup_releases_descendant_pipe_without_stopping_other_runner(self):
        bystander = self.runner("import time; time.sleep(30)")
        process = self.runner(
            "import subprocess,sys,time; "
            "subprocess.Popen([sys.executable,'-u','-c',"
            "\"import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); print('ready',flush=True); time.sleep(30)\"]); "
            "time.sleep(30)"
        )
        self.assertEqual(process.stdout.readline(), "ready\n")
        audit.stop_runner(process)
        self.assertTrue(select.select([process.stdout], [], [], 1)[0])
        self.assertEqual(process.stdout.read(), "")
        self.assertIsNone(bystander.poll())


class HingeCLIContracts(unittest.TestCase):
    line = CaptureContracts.line
    ledger = CaptureContracts.ledger
    screenshot = staticmethod(CaptureContracts.screenshot)

    def setUp(self):
        CaptureContracts.setUp(self)
        self.cli = self.base / "hinge"
        self.cli.write_text("#!/bin/sh\n")
        self.cli.chmod(0o700)

    def automatic_checkpoint(self):
        return audit.capture_checkpoint(self.line("FOLD:partiallyOpen", seconds=120), 1,
                                        self.output, APP_ID, "all", self.container.resolve(),
                                        self.captures, self.checkpoints)

    @patch.object(audit.time, "sleep")
    @patch.object(audit.subprocess, "run")
    @patch.object(audit.subprocess, "check_output", return_value=PORTS)
    def test_verified_cli_fold_refreshes_then_captures(self, _ports, run_mock, _sleep):
        def commands(argv, **kwargs):
            if argv[0] == str(self.cli.resolve()):
                return subprocess.CompletedProcess(argv, 0, "90.0" if argv[-1] == "get" else "", "")
            return self.screenshot(argv, **kwargs)

        def refresh(ack, _deadline):
            ack.with_suffix(".ack.txt").write_text("verified postfold hierarchy")

        run_mock.side_effect = commands
        with patch.dict(audit.os.environ, {"DAILVE_DUO_HINGE_CLI": str(self.cli)}), \
                patch.object(audit, "refresh_fold_hierarchy", side_effect=refresh), \
                patch.object(audit, "wait_for_fold_release") as manual_wait:
            self.automatic_checkpoint()
        manual_wait.assert_not_called()
        self.assertTrue(self.ledger()["valid_evidence"])
        receipt = json.loads((self.output / "001-fold.json").read_text())
        self.assertEqual(receipt["actual_angle"], 90.0)
        self.assertTrue(receipt["verified"])
        self.assertEqual(run_mock.call_args_list[0].args[0], [str(self.cli.resolve()), "-d", APP_ID, "90"])
        self.assertEqual((self.output / "001-hierarchy.txt").read_text(), "verified postfold hierarchy")

    @patch.object(audit.time, "sleep")
    @patch.object(audit.subprocess, "run")
    @patch.object(audit.subprocess, "check_output")
    def test_wrong_readback_never_refreshes_captures_or_acknowledges(self, ports, run_mock, _sleep):
        run_mock.return_value = subprocess.CompletedProcess([], 0, "0.0", "")
        with patch.dict(audit.os.environ, {"DAILVE_DUO_HINGE_CLI": str(self.cli)}), \
                patch.object(audit, "refresh_fold_hierarchy") as refresh:
            with self.assertRaisesRegex(RuntimeError, "readback mismatch"):
                self.automatic_checkpoint()
        ports.assert_not_called()
        refresh.assert_not_called()
        self.assertFalse(self.ack.exists())
        self.assertFalse(self.ledger()["valid_evidence"])
        self.assertFalse(json.loads((self.output / "001-fold.json").read_text())["verified"])

    @patch.object(audit.time, "sleep")
    @patch.object(audit.subprocess, "run")
    def test_nonfinite_readback_cannot_be_valid_evidence(self, run_mock, _sleep):
        run_mock.return_value = subprocess.CompletedProcess([], 0, "nan", "")
        with patch.dict(audit.os.environ, {"DAILVE_DUO_HINGE_CLI": str(self.cli)}):
            with self.assertRaisesRegex(RuntimeError, "finite angle"):
                self.automatic_checkpoint()
        receipt = json.loads((self.output / "001-fold.json").read_text())
        self.assertIsNone(receipt["actual_angle"])
        self.assertFalse(self.ack.exists())

    @patch.object(audit.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "dispatch failed"))
    def test_failed_setter_does_not_read_back_or_acknowledge(self, run_mock):
        with patch.dict(audit.os.environ, {"DAILVE_DUO_HINGE_CLI": str(self.cli)}):
            with self.assertRaisesRegex(RuntimeError, "Hinge 90 failed"):
                self.automatic_checkpoint()
        self.assertEqual(run_mock.call_count, 1)
        self.assertFalse(self.ack.exists())

    @patch.object(audit.subprocess, "run")
    def test_expired_fold_budget_never_dispatches(self, run_mock):
        with patch.dict(audit.os.environ, {"DAILVE_DUO_HINGE_CLI": str(self.cli)}):
            with self.assertRaisesRegex(RuntimeError, "insufficient capture budget"):
                audit.set_fold_with_cli(self.output, 1, "openFlat", APP_ID, time.time() + 10)
        run_mock.assert_not_called()

    @patch.object(audit.subprocess, "run")
    def test_ambiguous_booted_device_is_refused(self, run_mock):
        with patch.dict(audit.os.environ, {"DAILVE_DUO_HINGE_CLI": str(self.cli)}):
            with self.assertRaisesRegex(RuntimeError, "explicit simulator UDID"):
                audit.set_fold_with_cli(self.output, 1, "closed", "booted", time.time() + 120)
        run_mock.assert_not_called()


class OrientationCLIContracts(unittest.TestCase):
    line = CaptureContracts.line
    ledger = CaptureContracts.ledger
    screenshot = staticmethod(CaptureContracts.screenshot)

    def setUp(self):
        CaptureContracts.setUp(self)

    def orientation_checkpoint(self):
        return audit.capture_checkpoint(self.line("ORIENT:landscapeLeft", seconds=120), 1,
                                        self.output, APP_ID, "all", self.container.resolve(),
                                        self.captures, self.checkpoints)

    @patch.object(audit.subprocess, "run")
    @patch.object(audit.subprocess, "check_output", return_value=PORTS)
    def test_verified_orientation_requires_fresh_hierarchy_and_both_screens(self, _ports, run_mock):
        def commands(argv, **kwargs):
            if "orientation" in argv:
                payload = {"result": {"deviceOrientation": "landscapeLeft"}}
                return subprocess.CompletedProcess(argv, 0, json.dumps(payload), "")
            return self.screenshot(argv, **kwargs)

        run_mock.side_effect = commands
        with patch.object(audit, "refresh_fold_hierarchy") as refresh:
            self.orientation_checkpoint()
        refresh.assert_called_once()
        self.assertEqual(len(self.captures.getvalue().splitlines()), 2)
        self.assertTrue(self.ledger()["acknowledged"])
        receipt = json.loads((self.output / "001-orientation.json").read_text())
        self.assertEqual(receipt["actual_orientation"], "landscapeLeft")
        self.assertTrue(receipt["verified"])

    @patch.object(audit.subprocess, "run")
    @patch.object(audit.subprocess, "check_output")
    def test_orientation_mismatch_is_not_acknowledged(self, ports, run_mock):
        run_mock.return_value = subprocess.CompletedProcess([], 0, json.dumps({
            "result": {"deviceOrientation": "portrait"}
        }), "")
        with patch.object(audit, "refresh_fold_hierarchy") as refresh:
            with self.assertRaisesRegex(RuntimeError, "Orientation readback mismatch"):
                self.orientation_checkpoint()
        refresh.assert_not_called()
        ports.assert_not_called()
        self.assertFalse(self.ack.exists())
        self.assertFalse(self.ledger()["valid_evidence"])

    @patch.object(audit.subprocess, "run", side_effect=subprocess.TimeoutExpired("devicectl", 12))
    def test_orientation_timeout_is_not_acknowledged(self, _run):
        with self.assertRaises(subprocess.TimeoutExpired):
            self.orientation_checkpoint()
        self.assertFalse(self.ack.exists())
        self.assertFalse(self.ledger()["valid_evidence"])

    def test_unknown_orientation_is_refused(self):
        with self.assertRaisesRegex(RuntimeError, "Unknown orientation"):
            audit.orientation_state("ORIENT:invalid")

    @patch.object(audit.subprocess, "run")
    def test_guest_driver_still_requires_official_readback(self, run_mock):
        cli = self.output / "orientation-driver"
        cli.write_text("#!/bin/sh\nexit 0\n")
        cli.chmod(0o700)
        run_mock.side_effect = [
            subprocess.CompletedProcess([], 0, "", ""),
            subprocess.CompletedProcess([], 0, json.dumps({
                "result": {"deviceOrientation": "landscapeLeft"}
            }), ""),
        ]
        with patch.dict(audit.os.environ, {"DAILVE_DUO_ORIENTATION_CLI": str(cli)}):
            audit.set_device_orientation(self.output, 1, "landscapeLeft", APP_ID, time.time() + 120)
        self.assertEqual(run_mock.call_args_list[0].args[0],
                         [str(cli.resolve()), "-d", APP_ID, "landscapeLeft"])
        self.assertEqual(run_mock.call_args_list[1].args[0][:5],
                         ["xcrun", "devicectl", "device", "orientation", "get"])
        self.assertTrue(json.loads((self.output / "001-orientation.json").read_text())["verified"])

    @patch.object(audit.subprocess, "run")
    def test_guest_driver_failure_does_not_read_or_ack(self, run_mock):
        cli = self.output / "orientation-driver"
        cli.write_text("#!/bin/sh\nexit 1\n")
        cli.chmod(0o700)
        run_mock.return_value = subprocess.CompletedProcess([], 1, "", "dispatch failed")
        with patch.dict(audit.os.environ, {"DAILVE_DUO_ORIENTATION_CLI": str(cli)}):
            with self.assertRaisesRegex(RuntimeError, "Orientation set failed"):
                self.orientation_checkpoint()
        self.assertEqual(run_mock.call_count, 1)
        self.assertFalse(self.ack.exists())
        self.assertFalse(self.ledger()["valid_evidence"])


if __name__ == "__main__":
    unittest.main()
