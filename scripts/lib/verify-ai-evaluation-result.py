#!/usr/bin/env python3
"""Require both model-backed evaluation tests to have actually passed."""

import json
from pathlib import Path
import sys


REQUIRED = {
    "AIFeatureEvaluationTests/evaluatesHealthDataQA()",
    "AIFeatureEvaluationTests/evaluatesWorkoutTemplateGeneration()",
}


def results_by_identifier(report: dict) -> dict[str, str]:
    pending = list(report.get("testNodes", []))
    results = {}
    while pending:
        node = pending.pop()
        pending.extend(node.get("children", []))
        if node.get("nodeType") == "Test Case":
            identifier = node.get("nodeIdentifier")
            if isinstance(identifier, str):
                results[identifier] = node.get("result", "unknown")
    return results


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: verify-ai-evaluation-result.py RESULT_JSON", file=sys.stderr)
        return 2

    report = json.loads(Path(sys.argv[1]).read_text())
    results = results_by_identifier(report)
    incomplete = {identifier: results.get(identifier, "missing") for identifier in REQUIRED
                  if results.get(identifier) != "Passed"}
    if incomplete:
        for identifier, result in sorted(incomplete.items()):
            print(f"Live AI evaluation {identifier}: {result}", file=sys.stderr)
        return 1

    print("Both model-backed AI evaluations passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
