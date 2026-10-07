"""Contract tests for the iOS UI runner's argv and execution evidence."""

import shlex
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / "scripts/test-ui.sh"
WATCH_RUNNER = ROOT / "scripts/test-watch-ui.sh"
VERIFIER = ROOT / "scripts/lib/verify-ui-test-log.py"
SMOKE = "DUNEUITests/DashboardSmokeTests"
EXTRA = "DUNEUITests/TodaySettingsRegressionTests"
DEFAULT_SKIP = "DUNEUITests/ActivitySmokeTests/testPullToRefreshShowsWaveIndicator"
DUO_UDID = "5A2A5D3F-3D53-4326-99DE-47823CA256FA"


def dry_run(*args: str) -> tuple[subprocess.CompletedProcess[str], list[str]]:
    result = subprocess.run(["bash", str(RUNNER), "--dry-run", *args], cwd=ROOT,
                            text=True, capture_output=True)
    command = next((line.removeprefix("DRY_RUN_COMMAND=") for line in result.stdout.splitlines()
                    if line.startswith("DRY_RUN_COMMAND=")), "")
    return result, shlex.split(command)


def values(command: list[str], flag: str) -> list[str]:
    return [command[i + 1] for i, part in enumerate(command[:-1]) if part == flag]


def dry_verify_command(result: subprocess.CompletedProcess[str]) -> list[str]:
    command = next((line.removeprefix("DRY_RUN_VERIFY_COMMAND=")
                    for line in result.stdout.splitlines()
                    if line.startswith("DRY_RUN_VERIFY_COMMAND=")), "")
    return shlex.split(command)


def fake_lock_verifier(directory: Path) -> Path:
    """Keep fixture runs independent of the repository's live simulator lock."""
    fake_bin = directory / "bin"
    fake_bin.mkdir()
    python = fake_bin / "python3"
    python.write_text("#!/bin/sh\ncase \"$1:$3\" in "
                      "*/simulator-test-lock.py:--verify) exit 0 ;; esac\n"
                      f'exec "{sys.executable}" "$@"\n')
    python.chmod(0o755)
    return fake_bin


class RunnerArgvTests(unittest.TestCase):
    def test_explicit_simulator_dry_run_uses_exact_id_without_simulator_calls(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            fake_bin = Path(directory)
            marker = fake_bin / "xcrun-called"
            fake = fake_bin / "xcrun"
            fake.write_text(f"#!/bin/sh\ntouch '{marker}'\nexit 1\n")
            fake.chmod(0o755)
            result = subprocess.run(["bash", str(RUNNER), "--dry-run", "--simulator-udid", DUO_UDID],
                                    cwd=ROOT, env={**os.environ, "PATH": str(fake_bin) + os.pathsep + os.environ["PATH"]},
                                    text=True, capture_output=True)
            command = next((line.removeprefix("DRY_RUN_COMMAND=")
                            for line in result.stdout.splitlines() if line.startswith("DRY_RUN_COMMAND=")), "")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(values(shlex.split(command), "-destination"), ["id=" + DUO_UDID])
            self.assertFalse(marker.exists(), "Dry-run must not query, boot, or clone a simulator")

    def test_invalid_explicit_simulator_udid_fails_without_command(self) -> None:
        for value in ("", "not-a-uuid", DUO_UDID + "-extra"):
            with self.subTest(value=value):
                result, command = dry_run("--simulator-udid", value)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(command, [])

    def test_dry_run_does_not_verify_or_wait_for_simulator_lock(self) -> None:
        result = subprocess.run(["bash", str(RUNNER), "--dry-run"], cwd=ROOT,
                                env={**os.environ, "DUNE_SIM_TEST_LOCK_FD": "invalid"},
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("simulator test lock", result.stderr)

    def test_dry_run_cannot_cleanup_in_either_option_order(self) -> None:
        for args in [("--dry-run", "--cleanup-simulators"),
                     ("--cleanup-simulators", "--dry-run")]:
            with self.subTest(args=args):
                result = subprocess.run(["bash", str(RUNNER), *args], cwd=ROOT,
                                        text=True, capture_output=True)
                self.assertEqual(result.returncode, 2)
                self.assertIn("cannot be combined", result.stderr)

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
        verify = dry_verify_command(result)
        self.assertEqual(values(verify, "--only"), values(command, "-only-testing"))
        self.assertEqual(values(verify, "--skip"), values(command, "-skip-testing"))

    def test_smoke_and_explicit_union_uses_full_plan(self) -> None:
        result, command = dry_run("--smoke", "--only-testing", EXTRA)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(values(command, "-testPlan"), ["DUNEUITests-Full"])
        self.assertIn(SMOKE, values(command, "-only-testing"))
        self.assertIn(EXTRA, values(command, "-only-testing"))
        verify = dry_verify_command(result)
        self.assertEqual(values(verify, "--only"), values(command, "-only-testing"))
        self.assertEqual(values(verify, "--skip"), values(command, "-skip-testing"))

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

    def test_final_skipped_summary_is_authoritative(self) -> None:
        case = "Test Case '-[DUNEUITests.DashboardSmokeTests testLaunch]' passed\n"
        success = case + "Executed 3 tests, with 1 test skipped and 0 failures (0 unexpected)\n"
        self.assertEqual(self.verify(success).returncode, 0)
        failed = (case + "Executed 3 tests, with 0 failures\n"
                  "Executed 3 tests, with 1 test skipped and 1 failure (0 unexpected)\n")
        self.assertNotEqual(self.verify(failed).returncode, 0)

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

    def test_result_json_is_atomic_and_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            log = base / "ui.log"
            output = base / "nested" / "ui.result.json"
            selector = "DUNEUITests/DashboardSmokeTests/testAppLaunchesOnDashboard"
            log.write_text("Test Case '-[DUNEUITests.DashboardSmokeTests testAppLaunchesOnDashboard]' passed\n"
                           "Executed 2 tests, with 1 test skipped and 0 failures\n")
            skip = "DUNEUITests/UnusedTests/testUnused"
            command = [sys.executable, str(VERIFIER), "--log", str(log), "--only", selector,
                       "--skip", skip, "--result-json", str(output)]
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 0)
            data = json.loads(output.read_text())
            self.assertEqual(data["status"], "passed")
            self.assertEqual(data["counts"], {"executed": 2, "passed": 1, "skipped": 1, "failed": 0})
            self.assertEqual(data["passed_cases"], 1)
            self.assertEqual(data["log_path"], str(log.resolve()))
            self.assertEqual(data["requested_selectors"], [selector])
            self.assertEqual(data["skipped_selectors"], [skip])
            self.assertEqual(data["evidence_scope"],
                             {"kind": "selector_execution", "complete_test_inventory": False})
            self.assertEqual(list(output.parent.glob(".*.json.*")), [])

            log.write_text("Executed 0 tests, with 0 failures\n")
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 1)
            data = json.loads(output.read_text())
            self.assertEqual(data["status"], "failed")
            self.assertEqual(data["required_selectors_missing"], [selector])

    def test_watch_target_requires_watch_case_and_exit_zero(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "watch.log"
            output = Path(directory) / "watch.json"
            watch = "DUNEWatchUITests/WatchHomeSmokeTests/testHomeRenders"
            log.write_text("Test Case '-[DUNEUITests.WatchHomeSmokeTests testHomeRenders]' passed\n"
                           "Executed 1 test, with 0 failures\n")
            command = [sys.executable, str(VERIFIER), "--log", str(log), "--target", "DUNEWatchUITests",
                       "--only", watch, "--result-json", str(output)]
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 1)
            self.assertEqual(json.loads(output.read_text())["required_selectors_missing"], [watch])
            log.write_text("Test Case '-[DUNEWatchUITests.WatchHomeSmokeTests testHomeRenders]' passed\n"
                           "Executed 1 test, with 0 failures\n")
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 0)
            self.assertEqual(subprocess.run(command + ["--exit-status", "65"], capture_output=True).returncode, 1)
            self.assertEqual(json.loads(output.read_text())["run_exit_status"], 65)


class RunnerIntegrationTests(unittest.TestCase):
    def run_explicit_device_fixture(self, devices: dict, requested: str = DUO_UDID,
                                    list_failure: bool = False) -> tuple[subprocess.CompletedProcess[str], list[str], list[str]]:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            fake_bin = fake_lock_verifier(base)
            calls = base / "simctl.calls"
            build_calls = base / "xcodebuild.calls"
            device_json = base / "devices.json"
            device_json.write_text(json.dumps({"devices": devices}))
            xcrun = fake_bin / "xcrun"
            xcrun.write_text("#!/bin/sh\n"
                             "echo \"$*\" >> \"$FAKE_SIMCTL_CALLS\"\n"
                             "if [ \"$1 $2 $3 $4\" = 'simctl list devices available' ]; then\n"
                             "  if [ \"$FAKE_LIST_FAILURE\" = 1 ]; then exit 1; fi\n"
                             "  cat \"$FAKE_DEVICES_JSON\"; exit 0\n"
                             "fi\n"
                             "if [ \"$1 $2 $3\" = 'simctl list devices' ]; then\n"
                             "  echo \"$FAKE_REQUESTED_UDID (Booted)\"; exit 0\n"
                             "fi\n"
                             "exit 0\n")
            xcrun.chmod(0o755)
            xcodebuild = fake_bin / "xcodebuild"
            xcodebuild.write_text("#!/bin/sh\necho \"$*\" >> \"$FAKE_BUILD_CALLS\"\n"
                                  "echo \"Test Case '-[DUNEUITests.DashboardSmokeTests testAppLaunchesOnDashboard]' passed\"\n"
                                  "echo 'Executed 1 test, with 0 failures'\n")
            xcodebuild.chmod(0o755)
            log = base / "test.log"
            env = {**os.environ, "PATH": str(fake_bin) + os.pathsep + os.environ["PATH"],
                   "DUNE_SIM_TEST_LOCK_FD": "fixture", "FAKE_SIMCTL_CALLS": str(calls),
                   "FAKE_BUILD_CALLS": str(build_calls), "FAKE_DEVICES_JSON": str(device_json),
                   "FAKE_REQUESTED_UDID": requested,
                   "FAKE_LIST_FAILURE": "1" if list_failure else "0"}
            result = subprocess.run(["bash", str(RUNNER), "--no-regen", "--no-stream-log",
                                     "--log-file", str(log), "--simulator-udid", requested,
                                     "--only-testing", "DUNEUITests/DashboardSmokeTests"],
                                    cwd=ROOT, env=env, text=True, capture_output=True, timeout=20)
            return result, calls.read_text().splitlines() if calls.exists() else [], \
                build_calls.read_text().splitlines() if build_calls.exists() else []

    def test_explicit_ios_device_never_clones_or_falls_back(self) -> None:
        devices = {"com.apple.CoreSimulator.SimRuntime.iOS-27-1":
                   [{"udid": DUO_UDID, "name": "DUNE Duo Visual Audit", "isAvailable": True}]}
        result, simctl_calls, build_calls = self.run_explicit_device_fixture(devices)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(build_calls), 1)
        self.assertIn("-destination id=" + DUO_UDID, build_calls[0])
        self.assertNotIn("clone", " ".join(simctl_calls))
        self.assertTrue(any(call == "simctl boot " + DUO_UDID for call in simctl_calls))

    def test_missing_unavailable_or_non_ios_device_fails_closed(self) -> None:
        cases = [
            {},
            {"com.apple.CoreSimulator.SimRuntime.iOS-27-1":
             [{"udid": DUO_UDID, "name": "DUNE Duo Visual Audit", "isAvailable": False}]},
            {"com.apple.CoreSimulator.SimRuntime.watchOS-27-1":
             [{"udid": DUO_UDID, "name": "Watch", "isAvailable": True}]},
        ]
        for devices in cases:
            with self.subTest(devices=devices):
                result, simctl_calls, build_calls = self.run_explicit_device_fixture(devices)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn("unavailable", result.stderr)
                self.assertEqual(build_calls, [])
                self.assertEqual(simctl_calls, ["simctl list devices available -j"])
        result, simctl_calls, build_calls = self.run_explicit_device_fixture({}, list_failure=True)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(build_calls, [])
        self.assertEqual(simctl_calls, ["simctl list devices available -j"])

    def test_preflight_failure_invalidates_old_receipt_for_both_runners(self) -> None:
        for runner, target in ((RUNNER, "DUNEUITests"), (WATCH_RUNNER, "DUNEWatchUITests")):
            for arguments in (("--only-testing", target + "/Bad-Selector"),
                              ("--test-plan", "NoSuchPlan")):
                with self.subTest(runner=runner.name, arguments=arguments):
                    with tempfile.TemporaryDirectory() as directory:
                        fake_bin = fake_lock_verifier(Path(directory))
                        log = Path(directory) / "old log.log"
                        receipt = Path(str(log) + ".result.json")
                        receipt.write_text('{"status":"passed"}')
                        run = subprocess.run(["bash", str(runner), "--no-regen", "--log-file",
                                              str(log), *arguments], cwd=ROOT,
                                             env={**os.environ, "DUNE_SIM_TEST_LOCK_FD": "fixture",
                                                  "PATH": str(fake_bin) + os.pathsep + os.environ["PATH"]},
                                             text=True, capture_output=True, timeout=10)
                        self.assertNotEqual(run.returncode, 0)
                        self.assertFalse(receipt.exists(), run.stderr)

    def test_ios_dry_run_keeps_prior_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "old log.log"
            receipt = Path(str(log) + ".result.json")
            receipt.write_text('{"status":"passed"}')
            run = subprocess.run(["bash", str(RUNNER), "--dry-run", "--log-file", str(log)],
                                 cwd=ROOT, text=True, capture_output=True, timeout=10)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(receipt.read_text(), '{"status":"passed"}')

    def run_fixture(self, runner: Path, log_text: str, target: str, selector: str | None,
                    exit_code: int = 0, *extra: str) -> tuple[subprocess.CompletedProcess[str], dict]:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            fake_bin = fake_lock_verifier(base)
            fixture = base / "fixture.log"
            fixture.write_text(log_text)
            (fake_bin / "xcrun").write_text("#!/bin/sh\necho '{\"devices\":{}}'\n")
            (fake_bin / "xcodebuild").write_text("#!/bin/sh\ncat \"$FAKE_TEST_LOG\"\nexit \"$FAKE_TEST_EXIT\"\n")
            for fake in fake_bin.iterdir():
                fake.chmod(0o755)
            log = base / "output with spaces.log"
            env = {**os.environ, "PATH": str(fake_bin) + os.pathsep + os.environ["PATH"],
                   "FAKE_TEST_LOG": str(fixture), "FAKE_TEST_EXIT": str(exit_code),
                   "DUNE_SIM_TEST_LOCK_FD": "fixture"}
            args = ["bash", str(runner), "--no-regen", "--no-stream-log", "--log-file", str(log)]
            if selector:
                args += ["--only-testing", selector]
            args += list(extra)
            run = subprocess.run(args,
                                 cwd=ROOT, env=env, text=True, capture_output=True, timeout=30)
            receipt = json.loads(Path(str(log) + ".result.json").read_text())
            self.assertEqual(receipt["target"], target)
            return run, receipt

    def test_ios_runner_writes_passed_receipt(self) -> None:
        selector = "DUNEUITests/DashboardSmokeTests/testAppLaunchesOnDashboard"
        log = "Test Case '-[DUNEUITests.DashboardSmokeTests testAppLaunchesOnDashboard]' passed\nExecuted 1 test, with 0 failures\n"
        run, receipt = self.run_fixture(RUNNER, log, "DUNEUITests", selector)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(receipt["status"], "passed")

    def test_watch_runner_rejects_missing_smoke_selector(self) -> None:
        selector = "DUNEWatchUITests/WatchHomeSmokeTests/testHomeRenders"
        log = "Test Case '-[DUNEWatchUITests.OtherTests testOther]' passed\nExecuted 1 test, with 0 failures\n"
        run, receipt = self.run_fixture(WATCH_RUNNER, log, "DUNEWatchUITests", selector)
        self.assertEqual(run.returncode, 1, run.stderr)
        self.assertEqual(receipt["required_selectors_missing"], [selector])

    def test_watch_smoke_requires_both_suites(self) -> None:
        log = "Test Case '-[DUNEWatchUITests.WatchHomeSmokeTests testHomeRenders]' passed\nExecuted 1 test, with 0 failures\n"
        run, receipt = self.run_fixture(WATCH_RUNNER, log, "DUNEWatchUITests", None, 0, "--smoke")
        self.assertEqual(run.returncode, 1, run.stderr)
        self.assertEqual(receipt["required_selectors_missing"],
                         ["DUNEWatchUITests/WatchWorkoutStartSmokeTests"])

    def test_watch_runner_preserves_xcodebuild_exit(self) -> None:
        selector = "DUNEWatchUITests/WatchHomeSmokeTests/testHomeRenders"
        run, receipt = self.run_fixture(WATCH_RUNNER, "error: simulator disconnected\n",
                                        "DUNEWatchUITests", selector, 65)
        self.assertEqual(run.returncode, 65)
        self.assertEqual(receipt["run_exit_status"], 65)
        self.assertEqual(receipt["status"], "failed")


if __name__ == "__main__":
    unittest.main()
