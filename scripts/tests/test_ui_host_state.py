"""Contract tests for the read-only UI host context receipt."""

import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "lib" / "ui-host-state.py"
SPEC = importlib.util.spec_from_file_location("ui_host_state", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
host_state = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(host_state)


class UIHostStateTests(unittest.TestCase):
    def test_launch_manager_probe_is_bounded_and_failure_is_unknown(self) -> None:
        with mock.patch.object(host_state.subprocess, "run") as run:
            run.return_value = subprocess.CompletedProcess([], 0, "Aqua\n", "")
            self.assertEqual(host_state.caller_launch_manager(), "Aqua")
            run.assert_called_once_with(
                ["launchctl", "managername"], capture_output=True,
                text=True, timeout=1.5, check=False,
            )

        with mock.patch.object(host_state.subprocess, "run", side_effect=subprocess.TimeoutExpired("launchctl", 1.5)):
            self.assertEqual(host_state.caller_launch_manager(), "unknown")
        with mock.patch.object(host_state.subprocess, "run", side_effect=FileNotFoundError):
            self.assertEqual(host_state.caller_launch_manager(), "unknown")

    def test_lock_probe_is_bounded_and_failure_is_unknown(self) -> None:
        data = plistlib.dumps({"IOConsoleUsers": [self.console_user(503, True)]})
        with mock.patch.object(host_state.subprocess, "run") as run, \
             mock.patch.object(host_state.os, "getuid", return_value=503):
            run.return_value = subprocess.CompletedProcess([], 0, data, b"")
            self.assertEqual(host_state.host_locked(), "yes")
            run.assert_called_once_with(
                ["/usr/sbin/ioreg", "-n", "Root", "-d", "1", "-a"],
                capture_output=True, timeout=1.5, check=False,
            )
        with mock.patch.object(host_state.subprocess, "run", side_effect=subprocess.TimeoutExpired("ioreg", 1.5)):
            self.assertEqual(host_state.host_locked(), "unknown")

    @staticmethod
    def console_user(uid: int, locked: bool) -> dict[str, object]:
        return {
            "kCGSSessionUserIDKey": uid,
            "kCGSSessionOnConsoleKey": True,
            "CGSSessionScreenIsLocked": locked,
        }

    def test_lock_parser_handles_valid_missing_cross_user_and_conflicting(self) -> None:
        locked = self.console_user(503, True)
        unlocked = self.console_user(503, False)
        cases = (
            ({"IOConsoleUsers": [locked]}, "yes"),
            ([{"IOConsoleUsers": [unlocked]}], "no"),
            ({"IOConsoleUsers": [{}]}, "unknown"),
            ({"IOConsoleUsers": [self.console_user(504, True)]}, "unknown"),
            ({"IOConsoleUsers": [locked, unlocked]}, "unknown"),
            ({"IOConsoleUsers": [locked, self.console_user(504, False)]}, "unknown"),
        )
        for root, expected in cases:
            with self.subTest(expected=expected, root=root):
                self.assertEqual(host_state.parse_host_lock(plistlib.dumps(root), 503), expected)
        self.assertEqual(host_state.parse_host_lock(b"invalid plist", 503), "unknown")

    def test_receipt_does_not_infer_lock_sleep_or_permission(self) -> None:
        with mock.patch.object(host_state, "caller_launch_manager", return_value="Aqua"), \
             mock.patch.object(host_state, "console_user_session", return_value="yes"), \
             mock.patch.object(host_state, "host_locked", return_value="yes"):
            result = host_state.receipt("ios")

        self.assertEqual(result["caller_launch_manager"], "Aqua")
        self.assertEqual(result["console_user_session"], "yes")
        self.assertEqual(result["host_locked"], "yes")
        self.assertIn("implementation-specific", result["host_lock_source"])
        for key in ("display_sleep", "system_sleep", "ui_automation_permission"):
            self.assertEqual(result[key], "unknown")
        self.assertIn("do not establish UI test eligibility", result["interpretation"])

    def test_writes_atomic_sidecar_without_stale_temporary_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "nested" / "ui.log.host.json"
            host_state.write_receipt(output, {"runner": "watch"})

            self.assertEqual(json.loads(output.read_text()), {"runner": "watch"})
            self.assertEqual(list(output.parent.glob("*.tmp")), [])


if __name__ == "__main__":
    unittest.main()
