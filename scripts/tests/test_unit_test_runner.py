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

    def test_nested_ios_test_source_is_selectable(self) -> None:
        result, commands = self.dry_run("--only-testing", "DUNETests/PredictSleepDebtRecoveryUseCaseTests")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(option_values(commands[0], "-only-testing"),
                         ["DUNETests/PredictSleepDebtRecoveryUseCaseTests"])

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
                 build_exit: int = 0) -> tuple[subprocess.CompletedProcess[str], list[list[str]]]:
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
                              "print(os.environ['FAKE_LOG'])\n"
                              "sys.exit(int(os.environ['FAKE_EXIT']))\n")
        xcodebuild.chmod(0o755)
        argv_file = directory / "argv.jsonl"
        log_file = directory / "unit test.log"
        env = {**os.environ, "PATH": str(fake_bin) + os.pathsep + os.environ["PATH"],
               "DUNE_SIM_TEST_LOCK_FD": "fixture", "DAILVE_IOS_DESTINATION": "platform=iOS Simulator,name=Fixture",
               "DAILVE_WATCH_DESTINATION": "platform=watchOS Simulator,name=Fixture",
               "FAKE_ARGV": str(argv_file), "FAKE_LOG": log_text, "FAKE_EXIT": str(build_exit)}
        result = subprocess.run(["bash", str(RUNNER), "--no-regen", "--log-file", str(log_file), *args],
                                cwd=ROOT, env=env, capture_output=True, text=True, timeout=15)
        commands = [json.loads(line) for line in argv_file.read_text().splitlines()] if argv_file.exists() else []
        return result, commands

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

    def test_zero_and_missing_execution_count_fail(self) -> None:
        for log_text in ("Executed 0 tests, with 0 failures", "** TEST SUCCEEDED **"):
            with self.subTest(log_text=log_text), tempfile.TemporaryDirectory() as directory:
                result, commands = self.fake_run(Path(directory), "--ios-only", "--only-testing", IOS,
                                                 log_text=log_text)
                self.assertEqual(len(commands), 1)
                self.assertEqual(result.returncode, 1)
                self.assertIn("no positive execution count", result.stderr)

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
