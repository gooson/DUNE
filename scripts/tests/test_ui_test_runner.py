"""Contract tests for the iOS UI runner's argv and execution evidence."""

import shlex
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / "scripts/test-ui.sh"
VERIFIER = ROOT / "scripts/lib/verify-ui-test-log.py"
SMOKE = "DUNEUITests/DashboardSmokeTests"
EXTRA = "DUNEUITests/TodaySettingsRegressionTests"
DEFAULT_SKIP = "DUNEUITests/ActivitySmokeTests/testPullToRefreshShowsWaveIndicator"


def dry_run(*args: str) -> tuple[subprocess.CompletedProcess[str], list[str]]:
    result = subprocess.run(["bash", str(RUNNER), "--dry-run", *args], cwd=ROOT,
                            text=True, capture_output=True)
    command = next((line.removeprefix("DRY_RUN_COMMAND=") for line in result.stdout.splitlines()
                    if line.startswith("DRY_RUN_COMMAND=")), "")
    return result, shlex.split(command)


def values(command: list[str], flag: str) -> list[str]:
    return [command[i + 1] for i, part in enumerate(command[:-1]) if part == flag]


class RunnerArgvTests(unittest.TestCase):
    def test_default_is_full_target(self) -> None:
        result, command = dry_run()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(values(command, "-testPlan"), ["DUNEUITests-Full"])
        self.assertEqual(values(command, "-only-testing"), ["DUNEUITests"])

    def test_plain_smoke_keeps_suite_and_exclusions(self) -> None:
        result, command = dry_run("--smoke")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(values(command, "-testPlan"), ["DUNEUITests-PR"])
        self.assertIn(SMOKE, values(command, "-only-testing"))
        self.assertIn(DEFAULT_SKIP, values(command, "-skip-testing"))

    def test_smoke_and_explicit_union_uses_full_plan(self) -> None:
        result, command = dry_run("--smoke", "--only-testing", EXTRA)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(values(command, "-testPlan"), ["DUNEUITests-Full"])
        self.assertIn(SMOKE, values(command, "-only-testing"))
        self.assertIn(EXTRA, values(command, "-only-testing"))

    def test_explicit_suite_overrides_smoke_default_skip(self) -> None:
        result, command = dry_run("--smoke", "--only-testing", "DUNEUITests/ActivitySmokeTests")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn(DEFAULT_SKIP, values(command, "-skip-testing"))

    def test_user_skip_still_wins(self) -> None:
        result, command = dry_run("--smoke", "--only-testing", "DUNEUITests/ActivitySmokeTests",
                                  "--skip-testing", DEFAULT_SKIP)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(DEFAULT_SKIP, values(command, "-skip-testing"))

    def test_log_path_with_spaces_is_preserved_and_no_log_created(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "UI results" / "test log.txt"
            result, command = dry_run("--log-file", str(path))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(values(command, "-destination"), ["platform=iOS Simulator,name=iPhone 17,OS=26.2"])
            self.assertFalse(path.parent.exists())

    def test_invalid_selector_and_excluded_plan_fail(self) -> None:
        for args in [("--only-testing", "DUNEUITests/Full/TodaySettingsRegressionTests"),
                     ("--only-testing", "DUNEUITests/HealthKitPermissionUITests"),
                     ("--test-plan", "DUNEUITests-PR", "--only-testing", "DUNEUITests/SakuraThemeSnapshotTests")]:
            with self.subTest(args=args):
                result, command = dry_run(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(command, [])


class LogVerifierTests(unittest.TestCase):
    def verify(self, contents: str, *args: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "log with spaces.txt"
            path.write_text(contents)
            return subprocess.run([sys.executable, str(VERIFIER), "--log", str(path), *args],
                                  text=True, capture_output=True)

    def test_missing_or_zero_count_fails(self) -> None:
        case = "Test Case '-[DUNEUITests.DashboardSmokeTests testLaunch]' passed\n"
        for log in (case, case + "Executed 0 tests, with 0 failures\n"):
            with self.subTest(log=log):
                self.assertNotEqual(self.verify(log).returncode, 0)

    def test_final_zero_or_failure_count_fails(self) -> None:
        case = "Test Case '-[DUNEUITests.DashboardSmokeTests testLaunch]' passed\n"
        for ending in ("Executed 0 tests, with 0 failures\n",
                       "Executed 1 test, with 1 failure\n"):
            with self.subTest(ending=ending):
                log = case + "Executed 1 test, with 0 failures\n" + ending
                self.assertNotEqual(self.verify(log).returncode, 0)

    def test_started_or_failed_case_is_not_execution_evidence(self) -> None:
        for status in ("started", "failed"):
            with self.subTest(status=status):
                log = (f"Test Case '-[DUNEUITests.DashboardSmokeTests testLaunch]' {status}\n"
                       "Executed 1 test, with 0 failures\n")
                self.assertNotEqual(self.verify(log).returncode, 0)

    def test_unknown_execution_fails(self) -> None:
        self.assertNotEqual(self.verify("Executed 1 test, with 0 failures\n").returncode, 0)

    def test_missing_requested_suite_or_method_fails(self) -> None:
        log = ("Test Case '-[DUNEUITests.DashboardSmokeTests testLaunch]' passed\n"
               "Executed 1 test, with 0 failures\n")
        self.assertEqual(self.verify(log, "--only", SMOKE).returncode, 0)
        self.assertNotEqual(self.verify(log, "--only", EXTRA).returncode, 0)
        self.assertNotEqual(self.verify(log, "--only", SMOKE + "/testMissing").returncode, 0)

    def test_partially_skipped_class_needs_a_passed_case(self) -> None:
        log = ("Test Case '-[DUNEUITests.DashboardSmokeTests testLaunch]' passed\n"
               "Executed 1 test, with 0 failures\n")
        suite = "DUNEUITests/DashboardSmokeTests"
        self.assertEqual(self.verify(log, "--only", suite,
                                     "--skip", suite + "/testUnused").returncode, 0)
        self.assertNotEqual(self.verify(log, "--only", EXTRA, "--skip", EXTRA).returncode, 0)

    def test_all_requested_class_cases_skipped_fails(self) -> None:
        log = ("Test Case '-[DUNEUITests.DashboardSmokeTests testLaunch]' passed\n"
               "Executed 1 test, with 0 failures\n")
        self.assertNotEqual(self.verify(log, "--only", EXTRA,
                                        "--skip", EXTRA + "/testPlaceholder").returncode, 0)


if __name__ == "__main__":
    unittest.main()
