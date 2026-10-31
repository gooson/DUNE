"""Subprocess contracts for the unit runner without simulator or xcodebuild launches."""

import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / "scripts/test-unit.sh"
IOS = "DUNETests/CalculateConditionScoreUseCaseTests"
WATCH = "DUNEWatchTests/WatchRPEEstimatorTests"


def option_values(command: list[str], flag: str) -> list[str]:
    return [command[i + 1] for i, item in enumerate(command[:-1]) if item == flag]


class UnitRunnerTests(unittest.TestCase):
    def dry_run(self, *args: str) -> tuple[subprocess.CompletedProcess[str], list[list[str]]]:
        result = subprocess.run(["bash", str(RUNNER), "--dry-run", *args], cwd=ROOT,
                                env={**os.environ, "DUNE_SIM_TEST_LOCK_FD": "invalid"},
                                capture_output=True, text=True, timeout=10)
        commands = [shlex.split(line.removeprefix("DRY_RUN_COMMAND="))
                    for line in result.stdout.splitlines() if line.startswith("DRY_RUN_COMMAND=")]
        return result, commands

    def test_default_keeps_both_suites_in_order(self) -> None:
        result, commands = self.dry_run()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([option_values(command, "-scheme") for command in commands],
                         [["DUNETests"], ["DUNEWatchTests"]])
        self.assertEqual([option_values(command, "-only-testing") for command in commands],
                         [["DUNETests"], ["DUNEWatchTests"]])

    def test_uncompiled_ios_test_source_is_rejected(self) -> None:
        result, commands = self.dry_run("--only-testing", "DUNETests/PredictSleepDebtRecoveryUseCaseTests")
        self.assertEqual(result.returncode, 2)
        self.assertEqual(commands, [])

    def test_condition_score_detail_suite_is_selectable(self) -> None:
        result, commands = self.dry_run("--only-testing", "DUNETests/ConditionScoreDetailViewModelTests")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(option_values(commands[0], "-only-testing"),
                         ["DUNETests/ConditionScoreDetailViewModelTests"])

    def test_xctest_case_method_is_selectable(self) -> None:
        selector = "DUNETests/WorkoutTypeCorrectionStoreTests/testSetAndGetCorrectedTitle"
        result, commands = self.dry_run("--only-testing", selector)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(option_values(commands[0], "-only-testing"), [selector])

    def test_repeated_selectors_route_to_their_target(self) -> None:
        result, commands = self.dry_run("--only-testing", IOS, "--only-testing", IOS + "/scoreClamped",
                                        "--only-testing", WATCH)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([option_values(command, "-only-testing") for command in commands],
                         [[IOS, IOS + "/scoreClamped"], [WATCH]])

    def test_single_target_selector_skips_other_suite(self) -> None:
        for mode, selector, scheme in (("--ios-only", IOS, "DUNETests"),
                                       ("--watch-only", WATCH, "DUNEWatchTests")):
            with self.subTest(mode=mode):
                result, commands = self.dry_run(mode, "--only-testing", selector)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(len(commands), 1)
                self.assertEqual(option_values(commands[0], "-scheme"), [scheme])
                self.assertEqual(option_values(commands[0], "-only-testing"), [selector])

    def test_invalid_selectors_fail_before_any_command(self) -> None:
        for args in (("--only-testing",), ("--only-testing", ""),
                     ("--only-testing", "--ios-only"),
                     ("--only-testing", "DUNETests/Full/ConditionScoreTests/extra"),
                     ("--only-testing", "DUNETests/Bad-Class"),
                     ("--only-testing", "DUNETests/UnknownSuite"),
                     ("--only-testing", "DUNETests/MockHRVService"),
                     ("--only-testing", "DUNETests/MockHRVService/fetchHRVSamples"),
                     ("--only-testing", IOS + "/unknownMethod"),
                     ("--only-testing", "DUNEWatchTests/RunningFeedbackSettingsTests/targetAlert"),
                     ("--watch-only", "--only-testing", IOS),
                     ("--ios-only", "--only-testing", WATCH),
                     ("--ios-only", "--watch-only")):
            with self.subTest(args=args):
                result, commands = self.dry_run(*args)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(commands, [])

    def fake_run(self, directory: Path, *args: str, log_text: str = "Executed 1 test, with 0 failures\n",
                 build_exit: int = 0, with_boot: bool = False,
                 watch_lookup_exit: int = 0) -> tuple[subprocess.CompletedProcess[str], list[list[str]]]:
        fake_bin = directory / "bin"
        fake_bin.mkdir()
        python = fake_bin / "python3"
        python.write_text("#!/bin/sh\n"
                          'case "$1:$3" in */simulator-test-lock.py:--verify) exit 0 ;; esac\n'
                          f'exec "{sys.executable}" "$@"\n')
        python.chmod(0o755)
        xcodegen = fake_bin / "xcodegen"
        xcodegen.write_text("#!/bin/sh\nexit 0\n")
        xcodegen.chmod(0o755)
        xcodebuild = fake_bin / "xcodebuild"
        xcodebuild.write_text(f"#!{sys.executable}\n"
                              "import json, os, sys\n"
                              "with open(os.environ['FAKE_ARGV'], 'a') as output:\n"
                              "    output.write(json.dumps(sys.argv[1:]) + '\\n')\n"
                              "if os.environ.get('FAKE_EVENTS'):\n"
                              "    with open(os.environ['FAKE_EVENTS'], 'a') as output:\n"
                              "        output.write(sys.argv[sys.argv.index('-scheme') + 1] + '\\n')\n"
                              "print(os.environ['FAKE_LOG'])\n"
                              "sys.exit(int(os.environ['FAKE_EXIT']))\n")
        xcodebuild.chmod(0o755)
        argv_file = directory / "argv.jsonl"
        log_file = directory / "unit test.log"
        env = {**os.environ, "PATH": str(fake_bin) + os.pathsep + os.environ["PATH"],
               "DUNE_SIM_TEST_LOCK_FD": "fixture", "DAILVE_IOS_DESTINATION": "platform=iOS Simulator,name=Fixture",
               "DAILVE_WATCH_DESTINATION": "platform=watchOS Simulator,name=Fixture",
               "FAKE_ARGV": str(argv_file), "FAKE_LOG": log_text, "FAKE_EXIT": str(build_exit)}
        if with_boot:
            # Exercise real boot/destination helpers against fake tools only.
            git = fake_bin / "git"
            git.write_text("#!/bin/sh\nexit 1\n")
            git.chmod(0o755)
            xcrun = fake_bin / "xcrun"
            xcrun.write_text(f"#!{sys.executable}\n"
                              "import os, sys\n"
                              "from pathlib import Path\n"
                              "events = Path(os.environ['FAKE_EVENTS'])\n"
                              "command = sys.argv[2]\n"
                              "if command == 'list':\n"
                              "    if (int(os.environ['FAKE_WATCH_LOOKUP_EXIT']) and\n"
                              "            events.exists() and 'DUNETests' in events.read_text()):\n"
                              "        sys.exit(int(os.environ['FAKE_WATCH_LOOKUP_EXIT']))\n"
                              "    print('AAAA-1111 (Shutdown)\\nBBBB-2222 (Shutdown)')\n"
                              "elif command == 'boot':\n"
                              "    with events.open('a') as output:\n"
                              "        output.write('boot:' + sys.argv[3] + '\\n')\n"
                              "elif command != 'bootstatus':\n"
                              "    sys.exit(99)\n")
            xcrun.chmod(0o755)
            env.update({"DAILVE_IOS_DESTINATION": "platform=iOS Simulator,id=AAAA-1111",
                        "DAILVE_WATCH_DESTINATION": "platform=watchOS Simulator,id=BBBB-2222",
                        "FAKE_EVENTS": str(directory / "events.log"),
                        "FAKE_WATCH_LOOKUP_EXIT": str(watch_lookup_exit),
                        "SIMULATOR_BOOT_RETRIES": "0", "SIMULATOR_BOOT_TIMEOUT": "3"})
        result = subprocess.run(["bash", str(RUNNER), "--no-regen", "--log-file", str(log_file), *args],
                                cwd=ROOT, env=env, capture_output=True, text=True, timeout=15)
        commands = [json.loads(line) for line in argv_file.read_text().splitlines()] if argv_file.exists() else []
        return result, commands

    def test_each_platform_boots_immediately_before_its_suite(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            result, commands = self.fake_run(path, with_boot=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(len(commands), 2)
            self.assertEqual((path / "events.log").read_text().splitlines(),
                             ["boot:AAAA-1111", "DUNETests", "boot:BBBB-2222", "DUNEWatchTests"])

    def test_watch_preflight_failure_preserves_completed_ios_suite(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            result, commands = self.fake_run(path, with_boot=True, watch_lookup_exit=17)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertEqual([option_values(command, "-scheme") for command in commands], [["DUNETests"]])
            self.assertIn("device lookup failed", result.stdout)
            self.assertIn("exit 17", result.stdout)
            self.assertIn("Executed 1 test", (path / "unit test.log").read_text())

    def test_single_platform_does_not_boot_the_other(self) -> None:
        for mode, device, suite in (("--ios-only", "AAAA-1111", "DUNETests"),
                                    ("--watch-only", "BBBB-2222", "DUNEWatchTests")):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                path = Path(directory)
                result, commands = self.fake_run(path, mode, with_boot=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(len(commands), 1)
                self.assertEqual((path / "events.log").read_text().splitlines(), [f"boot:{device}", suite])

    def test_fake_execution_preserves_routing_and_split_logs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            result, commands = self.fake_run(path, "--only-testing", IOS, "--only-testing", WATCH)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual([option_values(command, "-scheme") for command in commands],
                             [["DUNETests"], ["DUNEWatchTests"]])
            self.assertEqual([option_values(command, "-only-testing") for command in commands],
                             [[IOS], [WATCH]])
            self.assertTrue((path / "unit test.log").exists())
            self.assertTrue((path / "unit test-watch.log").exists())

    def test_valid_and_helper_selectors_do_not_launch(self) -> None:
        for helper in ("DUNETests/MockHRVService", "DUNETests/MockHRVService/fetchHRVSamples"):
            with self.subTest(helper=helper), tempfile.TemporaryDirectory() as directory:
                result, commands = self.fake_run(Path(directory), "--only-testing", IOS,
                                                 "--only-testing", helper)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(commands, [])

    def test_mixed_valid_and_unknown_selector_does_not_launch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result, commands = self.fake_run(Path(directory), "--only-testing", IOS,
                                             "--only-testing", "DUNETests/UnknownSuite")
            self.assertEqual(result.returncode, 2)
            self.assertEqual(commands, [])

    def test_invalid_selector_does_not_launch_fake_xcodebuild(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result, commands = self.fake_run(Path(directory), "--watch-only", "--only-testing", IOS)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(commands, [])
            self.assertFalse((Path(directory) / "unit test.log").exists())

    def test_no_argument_invocation_reenters_lock_wrapper(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            fake_bin = path / "bin"
            fake_bin.mkdir()
            argv_file = path / "argv.jsonl"
            log_file = path / "default.log"
            python = fake_bin / "python3"
            python.write_text("#!/bin/sh\n"
                              'case "$1:$3" in\n'
                              '  */simulator-test-lock.py:--)\n'
                              '    shift 3\n'
                              '    [ "$#" -eq 1 ] || exit 42\n'
                              '    DUNE_SIM_TEST_LOCK_FD=fixture exec "$1" --no-regen --log-file "$FAKE_DEFAULT_LOG" ;;\n'
                              '  */simulator-test-lock.py:--verify) exit 0 ;;\n'
                              'esac\n'
                              f'exec "{sys.executable}" "$@"\n')
            python.chmod(0o755)
            xcodegen = fake_bin / "xcodegen"
            xcodegen.write_text("#!/bin/sh\nexit 0\n")
            xcodegen.chmod(0o755)
            xcodebuild = fake_bin / "xcodebuild"
            xcodebuild.write_text(f"#!{sys.executable}\n"
                                  "import json, os, sys\n"
                                  "with open(os.environ['FAKE_ARGV'], 'a') as output:\n"
                                  "    output.write(json.dumps(sys.argv[1:]) + '\\n')\n"
                                  "print('Executed 1 test, with 0 failures')\n")
            xcodebuild.chmod(0o755)
            env = {**os.environ, "PATH": str(fake_bin) + os.pathsep + os.environ["PATH"],
                   "FAKE_ARGV": str(argv_file), "FAKE_DEFAULT_LOG": str(log_file),
                   "DAILVE_IOS_DESTINATION": "platform=iOS Simulator,name=Fixture",
                   "DAILVE_WATCH_DESTINATION": "platform=watchOS Simulator,name=Fixture"}
            result = subprocess.run(["bash", str(RUNNER)], cwd=ROOT, env=env,
                                    capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            commands = [json.loads(line) for line in argv_file.read_text().splitlines()]
            self.assertEqual([option_values(command, "-only-testing") for command in commands],
                             [["DUNETests"], ["DUNEWatchTests"]])

    def test_zero_and_missing_execution_count_fail(self) -> None:
        for log_text in ("Executed 0 tests, with 0 failures", "** TEST SUCCEEDED **",
                         "Test run with 0 tests in 1 suite passed after 0.1 seconds."):
            with self.subTest(log_text=log_text), tempfile.TemporaryDirectory() as directory:
                result, commands = self.fake_run(Path(directory), "--ios-only", "--only-testing", IOS,
                                                 log_text=log_text)
                self.assertEqual(len(commands), 1)
                self.assertEqual(result.returncode, 1)
                self.assertIn("no positive execution count", result.stderr)

    def test_modern_swift_testing_count_after_xctest_zero(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result, commands = self.fake_run(
                Path(directory), "--ios-only", "--only-testing", IOS,
                log_text="Executed 0 tests, with 0 failures (0 unexpected)\n"
                         "✔ Test run with 20 tests in 1 suite passed after 0.236 seconds.")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(len(commands), 1)
            self.assertIn("Last reported test count: 20", result.stdout)

    def test_modern_swift_testing_plural_suites(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result, _ = self.fake_run(Path(directory), "--ios-only", "--only-testing", IOS,
                                      log_text="Test run with 21 tests in 2 suites passed after 0.3 seconds.")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("Last reported test count: 21", result.stdout)

    def test_swift_testing_count_and_nonzero_exit(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result, _ = self.fake_run(Path(directory), "--ios-only", "--only-testing", IOS,
                                      log_text="Test run with 1 test passed")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        with tempfile.TemporaryDirectory() as directory:
            result, _ = self.fake_run(Path(directory), "--ios-only", "--only-testing", IOS,
                                      build_exit=65)
            self.assertEqual(result.returncode, 65)


if __name__ == "__main__":
    unittest.main()
