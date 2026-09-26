"""Fixture tests for the bounded xcodebuild test summary."""

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


HELPER = Path(__file__).resolve().parents[1] / "lib" / "test-log-summary.py"
SPEC = importlib.util.spec_from_file_location("test_log_summary", HELPER)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class TestLogSummaryTests(unittest.TestCase):
    def summarize(self, contents: str, exit_status: int) -> tuple[str, Path]:
        with tempfile.TemporaryDirectory(prefix="test logs ") as directory:
            log_path = Path(directory) / "xcode build output.log"
            log_path.write_text(contents, encoding="utf-8")
            return MODULE.summarize(log_path, exit_status, "UI tests"), log_path

    def test_failed_exit_overrides_success_line(self) -> None:
        summary, path = self.summarize(
            "Test Suite 'All tests' passed\nExecuted 42 tests, with 0 failures\n"
            "** TEST SUCCEEDED **\nerror: simulator disconnected\n",
            65,
        )
        self.assertIn("UI tests: failed (exit 65)", summary)
        self.assertIn("Last reported test count: 42", summary)
        self.assertIn("error: simulator disconnected", summary)
        self.assertIn(f"Full log: {path.resolve()}", summary)
        self.assertNotIn("UI tests: passed", summary)

    def test_unknown_count_when_no_execution_summary(self) -> None:
        summary, _ = self.summarize("Testing failed:\nerror: build failed\n", 1)
        self.assertIn("Last reported test count: unknown", summary)
        self.assertIn("error: build failed", summary)

    def test_long_log_is_bounded_and_keeps_recent_failures(self) -> None:
        lines = ["noise\n"] * 10_000
        lines += [f"error: failure {number} {'x' * 500}\n" for number in range(30)]
        summary, _ = self.summarize("".join(lines), 1)
        self.assertIn("Showing last 12 of 30 matching lines", summary)
        self.assertNotIn("failure 0", summary)
        self.assertIn("failure 29", summary)
        self.assertLess(len(summary), 5_000)

    def test_success_with_swift_testing_count(self) -> None:
        summary, _ = self.summarize("Test run with 5 tests passed after 1.2 seconds.\n", 0)
        self.assertIn("UI tests: passed", summary)
        self.assertIn("Last reported test count: 5", summary)
        self.assertNotIn("Failure details:", summary)

    def test_mixed_framework_output_does_not_claim_total(self) -> None:
        summary, _ = self.summarize(
            "Executed 12 tests, with 0 failures (0 unexpected)\n"
            "Test run with 3 tests passed after 0.4 seconds.\n",
            0,
        )
        self.assertIn("Last reported test count: 3", summary)
        self.assertNotIn("Tests: 15", summary)

    def test_cli_accepts_log_path_with_spaces(self) -> None:
        with tempfile.TemporaryDirectory(prefix="test logs ") as directory:
            log_path = Path(directory) / "xcode build output.log"
            log_path.write_text("error: fixture failure\n", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(HELPER), str(log_path), "65", "Watch UI tests"],
                capture_output=True,
                text=True,
                check=True,
            )
            self.assertIn("Watch UI tests: failed (exit 65)", result.stdout)
            self.assertIn(f"Full log: {log_path.resolve()}", result.stdout)


if __name__ == "__main__":
    unittest.main()
