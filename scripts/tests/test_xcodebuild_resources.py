"""Resource budgets without starting Xcode or a simulator."""

import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "scripts/lib/xcodebuild-resources.sh"


def environment(**overrides: str) -> dict[str, str]:
    env = dict(os.environ)
    for key in ("CI", "DAILVE_XCODEBUILD_JOBS", "DAILVE_COMPILER_INDEX_STORE_ENABLE"):
        env.pop(key, None)
    env.update(overrides)
    return env


class ResourceBudgetTests(unittest.TestCase):
    def configure(self, mode: str, **env: str) -> tuple[int, list[str], str]:
        result = subprocess.run(
            ["bash", "-c", 'set -euo pipefail; source "$1"; '
             'configure_xcodebuild_resources "$2"; '
             'for arg in ${XCODEBUILD_RESOURCE_ARGS[@]+"${XCODEBUILD_RESOURCE_ARGS[@]}"}; '
             'do printf "%s\\n" "$arg"; done', "fixture", str(HELPER), mode],
            env=environment(**env), capture_output=True, text=True, timeout=5)
        return result.returncode, result.stdout.splitlines(), result.stderr

    def test_local_build_and_ui_budget(self) -> None:
        for mode in ("build", "target", "ui"):
            with self.subTest(mode=mode):
                code, args, error = self.configure(mode)
                self.assertEqual(code, 0, error)
                self.assertEqual(args, ["-jobs", "2", "COMPILER_INDEX_STORE_ENABLE=NO"])

    def test_local_unit_disables_parallel_workers(self) -> None:
        code, args, error = self.configure("unit")
        self.assertEqual(code, 0, error)
        self.assertEqual(args, ["-parallel-testing-enabled", "NO", "-jobs", "2",
                                "COMPILER_INDEX_STORE_ENABLE=NO"])

    def test_ci_defaults_are_preserved(self) -> None:
        for mode, expected in (("build", ["-jobs", "4", "COMPILER_INDEX_STORE_ENABLE=NO"]),
                               ("target", []), ("unit", []), ("ui", [])):
            with self.subTest(mode=mode):
                code, args, error = self.configure(mode, CI="true")
                self.assertEqual(code, 0, error)
                self.assertEqual(args, expected)

    def test_explicit_overrides_apply_locally_and_in_ci(self) -> None:
        for mode in ("build", "target", "unit", "ui"):
            for ci in ("false", "true"):
                with self.subTest(mode=mode, ci=ci):
                    code, args, error = self.configure(
                        mode, CI=ci, DAILVE_XCODEBUILD_JOBS="1",
                        DAILVE_COMPILER_INDEX_STORE_ENABLE="YES")
                    self.assertEqual(code, 0, error)
                    self.assertEqual(args[-3:], ["-jobs", "1", "COMPILER_INDEX_STORE_ENABLE=YES"])

    def test_invalid_budget_fails_before_emitting_command_arguments(self) -> None:
        for value in ("", "0", "-1", "2.5", "two", "2 3"):
            with self.subTest(value=value):
                code, args, error = self.configure("unit", DAILVE_XCODEBUILD_JOBS=value)
                self.assertEqual(code, 2)
                self.assertEqual(args, [])
                self.assertIn("DAILVE_XCODEBUILD_JOBS", error)
        code, args, error = self.configure("ui", DAILVE_COMPILER_INDEX_STORE_ENABLE="AUTO")
        self.assertEqual((code, args), (2, []))
        self.assertIn("DAILVE_COMPILER_INDEX_STORE_ENABLE", error)

    def test_unit_and_ios_ui_commands_receive_budget_and_keep_selector(self) -> None:
        for runner, selector in (("test-unit.sh", "DUNETests/CalculateConditionScoreUseCaseTests"),
                                 ("test-ui.sh", "DUNEUITests/DashboardSmokeTests")):
            with self.subTest(runner=runner):
                run = subprocess.run(
                    ["bash", str(ROOT / "scripts" / runner), "--dry-run", "--only-testing", selector],
                    cwd=ROOT, env=environment(), capture_output=True, text=True, timeout=10)
                self.assertEqual(run.returncode, 0, run.stderr)
                commands = [shlex.split(line.split("=", 1)[1]) for line in run.stdout.splitlines()
                            if line.startswith("DRY_RUN_COMMAND=")]
                self.assertEqual(len(commands), 1)
                command = commands[0]
                self.assertEqual(command[command.index("-jobs") + 1], "2")
                self.assertIn("COMPILER_INDEX_STORE_ENABLE=NO", command)
                self.assertEqual(command[command.index("-parallel-testing-enabled") + 1], "NO")
                self.assertEqual(command[command.index("-only-testing") + 1], selector)

    def fake_build(self, runner: str, *args: str, **overrides: str) -> list[str]:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            for name, body in {
                "xcodegen": "#!/bin/sh\nexit 0\n",
                "swift": "#!/bin/sh\nexit 0\n",
                "xcodebuild": f"#!{sys.executable}\nimport json, os, sys\n"
                              "with open(os.environ['RESOURCE_ARGV'], 'w') as output:\n"
                              "    json.dump(sys.argv[1:], output)\n"
                              "print('BUILD SUCCEEDED')\n",
            }.items():
                tool = base / name
                tool.write_text(body)
                tool.chmod(0o755)
            argv = base / "argv.json"
            run = subprocess.run(
                ["bash", str(ROOT / "scripts" / runner), "--no-regen",
                 "--log-file", str(base / "build.log"), *args], cwd=ROOT,
                env=environment(PATH=str(base) + os.pathsep + os.environ["PATH"],
                                RESOURCE_ARGV=str(argv), DAILVE_BUILD_DERIVED_DATA_DIR=str(base / "cache"),
                                **overrides),
                capture_output=True, text=True, timeout=10)
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            return json.loads(argv.read_text())

    def test_build_command_receives_budget_without_real_tools(self) -> None:
        command = self.fake_build("build-ios.sh")
        self.assertEqual(command[command.index("-jobs") + 1], "2")
        self.assertIn("COMPILER_INDEX_STORE_ENABLE=NO", command)

    def test_targeted_commit_build_receives_budget_and_preserves_ci_defaults(self) -> None:
        args = ("--scheme", "DUNETests", "--platform", "ios", "--build-for-testing")
        local_command = self.fake_build("build-target.sh", *args)
        self.assertEqual(local_command[0], "build-for-testing")
        self.assertEqual(local_command[local_command.index("-jobs") + 1], "2")
        self.assertIn("COMPILER_INDEX_STORE_ENABLE=NO", local_command)
        ci_command = self.fake_build("build-target.sh", *args, CI="true")
        self.assertEqual(ci_command[0], "build-for-testing")
        self.assertNotIn("-jobs", ci_command)
        self.assertFalse(any(arg.startswith("COMPILER_INDEX_STORE_ENABLE=") for arg in ci_command))

    def test_precommit_build_paths_use_owned_deadline_and_propagate_timeout(self) -> None:
        scenarios = (("DUNE/App/Example.swift", "build-ios.sh", 900, 0),
                     ("DUNE/project.yml", "build-ios.sh", 900, 0),
                     ("DUNETests/ExampleTests.swift", "build-target.sh", 900, 0),
                     ("DUNETests/ExampleTests.swift", "build-target.sh", 60, 124))
        for staged, runner, seconds, exit_code in scenarios:
            with self.subTest(staged=staged, seconds=seconds), tempfile.TemporaryDirectory() as directory:
                base = Path(directory)
                fake_bin = base / "bin"
                fake_bin.mkdir()
                hooks = base / "scripts/hooks"
                hooks.mkdir(parents=True)
                (hooks / "cleanup-artifacts.sh").write_text("#!/bin/sh\nexit 0\n")
                (hooks / "cleanup-artifacts.sh").chmod(0o755)
                (fake_bin / "git").write_text(
                    f"#!{sys.executable}\nimport os, sys\n"
                    "args = sys.argv[1:]\n"
                    "if args == ['rev-parse', '--show-toplevel']:\n"
                    "    print(os.environ['FAKE_ROOT'])\n"
                    "elif args == ['diff', '--cached', '--name-only']:\n"
                    "    print(os.environ['FAKE_STAGED'])\n"
                    "elif args[:2] == ['config', '--get']:\n"
                    "    print('scripts/lib/xcscheme-clean-filter.sh')\n")
                (fake_bin / "python3").write_text(
                    f"#!{sys.executable}\nimport json, os, sys\n"
                    "with open(os.environ['RESOURCE_ARGV'], 'w') as output:\n"
                    "    json.dump({'args': sys.argv[1:], 'fast': os.environ.get('DAILVE_FAST_LOCAL_BUILD')}, output)\n"
                    "sys.exit(int(os.environ['FAKE_EXIT']))\n")
                for tool in fake_bin.iterdir():
                    tool.chmod(0o755)
                argv = base / "argv.json"
                run = subprocess.run(
                    ["bash", str(ROOT / "scripts/hooks/pre-commit.sh")], cwd=base,
                    env=environment(PATH=str(fake_bin) + os.pathsep + os.environ["PATH"],
                                    FAKE_ROOT=str(base), FAKE_STAGED=staged, FAKE_EXIT=str(exit_code),
                                    RESOURCE_ARGV=str(argv), DAILVE_SKIP_PRECOMMIT_BUILD="0",
                                    DUNE_BUILD_WALL_TIMEOUT=str(seconds)),
                    capture_output=True, text=True, timeout=10)
                self.assertEqual(run.returncode, exit_code, run.stdout + run.stderr)
                invocation = json.loads(argv.read_text())
                self.assertEqual(invocation['fast'], '1')
                command = invocation['args']
                self.assertEqual(command[:4], [str(base / 'scripts/lib/command-deadline.py'),
                                               '--seconds', str(seconds), '--'])
                self.assertEqual(command[4], str(base / 'scripts' / runner))
                self.assertEqual('--no-regen' in command, staged != 'DUNE/project.yml')
                if runner == 'build-target.sh':
                    self.assertIn('--build-for-testing', command)


if __name__ == "__main__":
    unittest.main()
