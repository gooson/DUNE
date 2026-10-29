---
tags: [swift-testing, xctest, unit-testing, xcodebuild, result-summary]
category: testing
date: 2026-10-30
severity: important
related_files:
  - scripts/test-unit.sh
  - scripts/lib/test-log-summary.py
  - scripts/tests/test_unit_test_runner.py
  - scripts/tests/test_test_log_summary.py
related_solutions:
  - docs/solutions/testing/2026-10-30-unit-test-selection.md
---

# Solution: Swift Testing suite counts in focused unit results

## Problem

A native focused unit run completed 20 tests successfully, but `scripts/test-unit.sh` returned 1. The supplied log at `/private/tmp/t04-native-evidence/t04-focused-unit.log` contains normal XCTest `Executed 0 tests` lines followed by `✔ Test run with 20 tests in 1 suite passed after 0.236 seconds.` The shared summary printed `Last reported test count: 0`.

The unit positive-count guard and `test-log-summary.py` recognized only `Test run with N tests passed`, without the newer `in N suite(s)` phrase.

## Solution

Both existing expressions now accept an optional suite-count phrase between the Swift Testing test count and status. The XCTest pattern and the positive test-count requirement are unchanged. This recognizes old and new Swift Testing lines while zero and missing focused counts still fail.

| File | Change |
|---|---|
| `scripts/test-unit.sh` | Extend focused positive-count grep to allow `in N suite(s)` |
| `scripts/lib/test-log-summary.py` | Parse the same phrase and display the last reported test count |
| `scripts/tests/test_unit_test_runner.py` | Mock singular/plural suite counts, XCTest zero plus Swift Testing 20, and zero/unknown cases |
| `scripts/tests/test_test_log_summary.py` | Check shared summary for modern singular/plural output and mixed-framework ordering |

## Validation

- The supplied real log replays as `Last reported test count: 20`; the focused positive-count expression matches it.
- The affected Python runner and summary contract modules pass with fake tools; no simulator or native test was launched.
- Shared summary UI consumer contracts pass. The full `test_ui_test_runner.py` module has four pre-existing `SimulatorVersionFloorTests` errors because it searches for an old `test-unit.sh` condition; those are outside this parser correction and were present on `origin/main`.
- `bash -n scripts/test-unit.sh` and `git diff --check` pass.

## Prevention

When xcodebuild output changes, check both the shared display parser and the selected-test success guard against a real log. A mixed XCTest zero plus Swift Testing positive line is a required fixture; zero and missing counts must remain failures.

## Lessons Learned

An XCTest zero line can coexist with a successful Swift Testing run. The final supported count line, including optional suite information, must determine focused unit execution evidence.
