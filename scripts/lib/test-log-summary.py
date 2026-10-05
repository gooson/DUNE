#!/usr/bin/env python3
"""Print a bounded summary of an xcodebuild test log."""

import argparse
import re
from collections import deque
from pathlib import Path


EXECUTED = re.compile(
    r"Executed (\d+) tests?, with (?:(\d+) tests? skipped and )?(\d+) failures?(?: \((\d+) unexpected\))?"
)
SWIFT_TESTING = re.compile(r"Test run with (\d+) tests? (?:passed|failed)")
FAILURE = re.compile(
    r"(?:^|\s)(?:error:|Testing failed:|Test Case .* failed|Test .* failed|"
    r"\*\* TEST FAILED \*\*|Assertion Failure|failed - )",
    re.IGNORECASE,
)
MAX_FAILURES = 12
MAX_LINE_LENGTH = 300


def summarize(log_path: Path, exit_status: int, label: str) -> str:
    failures: deque[str] = deque(maxlen=MAX_FAILURES - 1)
    first_failure = None
    failure_count = 0
    count = None
    reported_skips = None
    reported_failures = None

    with log_path.open("r", encoding="utf-8", errors="replace") as log:
        for line_number, raw_line in enumerate(log, 1):
            line = raw_line.strip()
            match = EXECUTED.search(line)
            if match:
                count = int(match.group(1))
                reported_skips = int(match.group(2) or 0)
                reported_failures = int(match.group(3))
            else:
                match = SWIFT_TESTING.search(line)
                if match:
                    count = int(match.group(1))
                    reported_skips = None
                    reported_failures = None

            if exit_status != 0 and FAILURE.search(line):
                failure_count += 1
                detail = line[:MAX_LINE_LENGTH]
                if len(line) > MAX_LINE_LENGTH:
                    detail += "…"
                entry = f"  {line_number}: {detail}"
                if first_failure is None:
                    first_failure = entry
                elif not any(item.split(": ", 1)[-1] == detail for item in failures) and first_failure.split(": ", 1)[-1] != detail:
                    failures.append(entry)

    status = "passed" if exit_status == 0 else f"failed (exit {exit_status})"
    lines = [f"{label}: {status}",
             f"Last reported test count: {count if count is not None else 'unknown'}"]
    if reported_failures is not None:
        lines.append(f"Last reported failures: {reported_failures}")
    if reported_skips:
        lines.append(f"Last reported skips: {reported_skips}")
    if exit_status != 0:
        lines.append("Failure details:")
        if failure_count:
            if failure_count > MAX_FAILURES:
                lines.append(f"  Showing first and up to {MAX_FAILURES - 1} recent distinct lines of {failure_count} matching lines:")
            lines.append(first_failure)
            lines.extend(failures)
        else:
            lines.append("  No failure detail found in log.")
    lines.append(f"Full log: {log_path.resolve()}")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log_path", type=Path)
    parser.add_argument("exit_status", type=int)
    parser.add_argument("label")
    args = parser.parse_args()
    print(summarize(args.log_path, args.exit_status, args.label))


if __name__ == "__main__":
    main()
