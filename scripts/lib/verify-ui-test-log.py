#!/usr/bin/env python3
"""Validate UI test evidence and optionally save a bounded, atomic result receipt."""

import argparse
import json
import os
import re
import sys
import tempfile
from pathlib import Path


COUNT = re.compile(r"Executed (\d+) tests?, with (?:(\d+) tests? skipped and )?(\d+) failures?")
CASE = re.compile(r"Test Case '-\[([A-Za-z_][\w]*)\.([A-Za-z_][\w]*) ([A-Za-z_][\w]*)\]' passed")
ALT_CASE = re.compile(r"Test Case '([A-Za-z_][\w]*)\.([A-Za-z_][\w]*)\.([A-Za-z_][\w]*)\(\)' passed")
ERROR = re.compile(r"(?:^|\s)(?:error:|Testing failed:|Test Case .* failed|Test .* failed|\*\* TEST FAILED \*\*|Assertion Failure|failed - )", re.IGNORECASE)
MAX_FAILURES = 12
MAX_LINE_LENGTH = 300


def covers(selector: str, case: str) -> bool:
    return selector == case or case.startswith(selector + "/")


def check_plan(path: Path, selectors: list[str], target: str = "DUNEUITests") -> None:
    plan = json.loads(path.read_text(encoding="utf-8"))
    skipped = [target + "/" + test for entry in plan.get("testTargets", [])
               for test in entry.get("skippedTests", [])]
    sources = list(path.parent.rglob("*.swift"))
    for selector in selectors:
        if selector == target:
            continue
        parts = selector.split("/")
        if parts[0] != target or len(parts) not in (2, 3):
            raise ValueError(f"invalid UI test selector: {selector}")
        suite = parts[1]
        suite_sources = [source for source in sources
                         if re.search(r"\bclass\s+" + re.escape(suite) + r"\b", source.read_text())]
        if not suite_sources:
            raise ValueError(f"unknown UI test suite: {suite}")
        if len(parts) == 3 and not any(re.search(r"\bfunc\s+" + re.escape(parts[2]) + r"\s*\(",
                                                  source.read_text()) for source in suite_sources):
            raise ValueError(f"unknown UI test method: {selector}")
        for skip in skipped:
            if covers(skip, selector):
                raise ValueError(f"test plan {path.stem} excludes requested selector {selector}")


def read_log(path: Path, target: str) -> tuple[tuple[int, int, int] | None, set[str], list[str]]:
    count = None
    cases: set[str] = set()
    failures: list[str] = []
    with path.open(encoding="utf-8", errors="replace") as log:
        for line_number, raw in enumerate(log, 1):
            line = raw.strip()
            match = COUNT.search(line)
            if match:
                count = (int(match.group(1)), int(match.group(2) or 0), int(match.group(3)))
            case = CASE.search(line) or ALT_CASE.search(line)
            if case and case.group(1) == target:
                cases.add(f"{target}/{case.group(2)}/{case.group(3)}")
            if ERROR.search(line):
                entry = f"{line_number}: {line[:MAX_LINE_LENGTH]}" + ("…" if len(line) > MAX_LINE_LENGTH else "")
                if not failures or entry.split(": ", 1)[-1] not in [item.split(": ", 1)[-1] for item in failures]:
                    if len(failures) == MAX_FAILURES:
                        failures.pop(1)  # Preserve the first error and recent distinct details.
                    failures.append(entry)
    return count, cases, failures


def result(path: Path, target: str, selectors: list[str], skips: list[str], exit_status: int) -> dict:
    receipt = {
        "schema_version": 1,
        "status": "failed",
        "target": target,
        "run_exit_status": exit_status,
        "requested_selectors": selectors,
        "skipped_selectors": skips,
        "evidence_scope": {"kind": "selector_execution", "complete_test_inventory": False},
        "counts": {"executed": None, "passed": None, "skipped": None, "failed": None},
        "passed_cases": 0,
        "failures": [],
        "required_selectors_missing": [],
        "log_path": str(path.resolve()),
    }
    try:
        count, cases, failures = read_log(path, target)
    except OSError as error:
        receipt["failures"] = [f"log unavailable: {error}"]
        return receipt
    receipt["failures"] = failures
    receipt["passed_cases"] = len(cases)
    if count is not None:
        executed, skipped, failed = count
        receipt["counts"] = {
            "executed": executed, "passed": max(0, executed - skipped - failed),
            "skipped": skipped, "failed": failed,
        }
    for selector in selectors:
        if selector == target:
            continue
        # An exact method intentionally skipped by the caller has no execution obligation.
        if len(selector.split("/")) == 3 and any(covers(skip, selector) for skip in skips):
            continue
        if not any(covers(selector, case) and not any(covers(skip, case) for skip in skips)
                   for case in cases):
            receipt["required_selectors_missing"].append(selector)
    if exit_status != 0:
        receipt["failures"].append(f"xcodebuild exited {exit_status}")
    if count is None:
        receipt["failures"].append("UI test log has no executed-test count")
    elif count[0] == 0 or count[0] - count[1] - count[2] <= 0:
        receipt["failures"].append("UI test log has no positive passed-test count")
    elif count[2] != 0:
        receipt["failures"].append(f"UI test log reports {count[2]} failures")
    if not cases:
        receipt["failures"].append("UI test log has no identifiable passed UI test cases")
    if receipt["required_selectors_missing"]:
        receipt["failures"].append("requested UI test selector has no execution evidence")
    if not receipt["failures"]:
        receipt["status"] = "passed"
    return receipt


def write_result(path: Path, receipt: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    name = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent,
                                         prefix=f".{path.name}.", delete=False) as output:
            name = output.name
            json.dump(receipt, output, indent=2, ensure_ascii=False)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
        os.replace(name, path)
    finally:
        if name and os.path.exists(name):
            os.unlink(name)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check-plan", type=Path)
    mode.add_argument("--log", type=Path)
    parser.add_argument("--target", choices=("DUNEUITests", "DUNEWatchUITests"), default="DUNEUITests")
    parser.add_argument("--only", action="append", default=[])
    parser.add_argument("--skip", action="append", default=[])
    parser.add_argument("--exit-status", type=int, default=0)
    parser.add_argument("--result-json", type=Path)
    args = parser.parse_args()
    try:
        if args.check_plan:
            check_plan(args.check_plan, args.only, args.target)
            return 0
        receipt = result(args.log, args.target, args.only, args.skip, args.exit_status)
        if args.result_json:
            write_result(args.result_json, receipt)
        if receipt["status"] != "passed":
            print("UI test verification failed: " + "; ".join(receipt["failures"]), file=sys.stderr)
            if receipt["required_selectors_missing"]:
                print("Missing: " + ", ".join(receipt["required_selectors_missing"]), file=sys.stderr)
            return 1
        print(f"Verified UI test execution: {receipt['counts']['executed']} reported, {receipt['passed_cases']} passed cases")
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"UI test verification failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
