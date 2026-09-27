#!/usr/bin/env python3
"""Reject a successful xcodebuild run without evidence of requested UI tests."""

import argparse
import json
import re
import sys
from pathlib import Path


COUNT = re.compile(r"Executed (\d+) tests?, with (?:(\d+) tests? skipped and )?(\d+) failures?")
CASE = re.compile(r"Test Case '-\[DUNEUITests\.([A-Za-z_][\w]*) ([A-Za-z_][\w]*)\]' passed")
ALT_CASE = re.compile(r"Test Case 'DUNEUITests\.([A-Za-z_][\w]*)\.([A-Za-z_][\w]*)\(\)' passed")


def covers(skip: str, selector: str) -> bool:
    return selector == skip or selector.startswith(skip + "/")


def check_plan(path: Path, selectors: list[str]) -> None:
    plan = json.loads(path.read_text(encoding="utf-8"))
    skipped = ["DUNEUITests/" + test for target in plan.get("testTargets", [])
               for test in target.get("skippedTests", [])]
    sources = list(path.parent.rglob("*.swift"))
    for selector in selectors:
        if selector == "DUNEUITests":
            continue
        parts = selector.split("/")
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


def verify(path: Path, selectors: list[str], skips: list[str]) -> None:
    counts: list[tuple[int, int]] = []
    cases: set[str] = set()
    with path.open(encoding="utf-8", errors="replace") as log:
        for line in log:
            count = COUNT.search(line)
            if count:
                counts.append((int(count.group(1)), int(count.group(3))))
            case = CASE.search(line) or ALT_CASE.search(line)
            if case:
                cases.add(f"DUNEUITests/{case.group(1)}/{case.group(2)}")

    if not counts or counts[-1][0] == 0:
        raise ValueError("UI test log has no positive executed-test count")
    if counts[-1][1] != 0:
        raise ValueError(f"UI test log reports {counts[-1][1]} failures")
    if not cases:
        raise ValueError("UI test log has no identifiable executed UI test cases")

    for selector in selectors:
        if selector == "DUNEUITests":
            continue
        # An exact method intentionally skipped by the caller has no execution obligation.
        if len(selector.split("/")) == 3 and any(covers(skip, selector) for skip in skips):
            continue
        if not any(covers(selector, case) and not any(covers(skip, case) for skip in skips)
                   for case in cases):
            raise ValueError(f"requested UI test selector has no execution evidence: {selector}")
    print(f"Verified UI test execution: {counts[-1][0]} reported, {len(cases)} passed cases")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check-plan", type=Path)
    mode.add_argument("--log", type=Path)
    parser.add_argument("--only", action="append", default=[])
    parser.add_argument("--skip", action="append", default=[])
    args = parser.parse_args()
    try:
        if args.check_plan:
            check_plan(args.check_plan, args.only)
        else:
            verify(args.log, args.only, args.skip)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"UI test verification failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
