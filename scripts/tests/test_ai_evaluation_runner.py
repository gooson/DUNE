"""Contract checks for the opt-in live AI evaluation wrapper."""

import os
from pathlib import Path
import shlex
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / "scripts" / "evaluate-ai-features.sh"
PROJECT = ROOT / "DUNE" / "project.yml"
TESTS = ROOT / "DUNETests" / "AIFeatureEvaluationTests.swift"


class AIEvaluationRunnerTests(unittest.TestCase):
    def dry_run(self, *arguments: str) -> list[str]:
        environment = os.environ.copy()
        environment["DAILVE_AI_EVALUATION_LOG_FILE"] = ".xcodebuild/ai-evaluation-contract.log"
        completed = subprocess.run(
            ["bash", str(RUNNER), "--dry-run", *arguments],
            cwd=ROOT,
            env=environment,
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertTrue(completed.stdout.startswith("DRY_RUN_COMMAND="))
        return shlex.split(completed.stdout.split("=", 1)[1])

    def test_live_command_uses_dedicated_scheme_and_exact_suite(self) -> None:
        command = self.dry_run()
        self.assertEqual(command[0], str(ROOT / "scripts" / "test-unit.sh"))
        self.assertEqual(command[command.index("--ios-scheme") + 1], "DUNEAIEvaluations")
        self.assertEqual(command[command.index("--only-testing") + 1], "DUNETests/AIFeatureEvaluationTests")
        self.assertEqual(command[command.index("--log-file") + 1], ".xcodebuild/ai-evaluation-contract.log")
        self.assertIn("--ios-only", command)
        self.assertIn("--result-bundle-path", command)
        self.assertNotIn("--no-regen", command)

    def test_no_regen_is_forwarded_without_changing_selector(self) -> None:
        command = self.dry_run("--no-regen")
        self.assertIn("--no-regen", command)
        self.assertEqual(command[command.index("--only-testing") + 1], "DUNETests/AIFeatureEvaluationTests")

    def test_live_opt_in_is_only_in_dedicated_scheme(self) -> None:
        project = PROJECT.read_text()
        unit_scheme = project.split("  DUNETests:\n", 1)[1].split("  DUNEAIEvaluations:\n", 1)[0]
        live_scheme = project.split("  DUNEAIEvaluations:\n", 1)[1].split("  DUNEWatch:\n", 1)[0]
        self.assertNotIn("DUNE_RUN_LIVE_AI_EVALUATIONS", unit_scheme)
        self.assertIn('DUNE_RUN_LIVE_AI_EVALUATIONS: "1"', live_scheme)
        source = TESTS.read_text()
        self.assertEqual(source.count(".enabled(if: Self.liveEvaluationsEnabled)"), 2)
        self.assertIn('environment["DUNE_RUN_LIVE_AI_EVALUATIONS"] == "1"', source)


if __name__ == "__main__":
    unittest.main()
