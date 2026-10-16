"""Contract tests for the live AI evaluation result gate."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "lib" / "verify-ai-evaluation-result.py"
REQUIRED = (
    "AIFeatureEvaluationTests/evaluatesHealthDataQA()",
    "AIFeatureEvaluationTests/evaluatesWorkoutTemplateGeneration()",
)


class VerifyAIEvaluationResultTests(unittest.TestCase):
    def run_gate(self, statuses: dict[str, str]) -> subprocess.CompletedProcess[str]:
        nodes = [
            {"nodeType": "Test Case", "nodeIdentifier": identifier, "result": result, "name": identifier}
            for identifier, result in statuses.items()
        ]
        with tempfile.TemporaryDirectory() as temporary:
            report = Path(temporary) / "result.json"
            report.write_text(json.dumps({"testNodes": [{"nodeType": "Test Suite", "name": "AI", "children": nodes}]}))
            return subprocess.run([sys.executable, str(SCRIPT), str(report)], capture_output=True, text=True)

    def test_both_live_tests_pass(self) -> None:
        completed = self.run_gate({identifier: "Passed" for identifier in REQUIRED})
        self.assertEqual(completed.returncode, 0)

    def test_skipped_model_test_is_incomplete(self) -> None:
        completed = self.run_gate({REQUIRED[0]: "Passed", REQUIRED[1]: "Skipped"})
        self.assertEqual(completed.returncode, 1)
        self.assertIn("Skipped", completed.stderr)

    def test_missing_live_test_is_incomplete(self) -> None:
        completed = self.run_gate({REQUIRED[0]: "Passed"})
        self.assertEqual(completed.returncode, 1)
        self.assertIn("missing", completed.stderr)


if __name__ == "__main__":
    unittest.main()
