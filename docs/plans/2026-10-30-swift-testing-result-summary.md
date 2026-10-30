---
topic: Swift Testing result summary compatibility
date: 2026-10-30
status: implemented
confidence: high
related_solutions:
  - docs/solutions/testing/2026-10-30-unit-test-selection.md
related_brainstorms: []
---

# Implementation Plan: Swift Testing result summary compatibility

## Context

A focused native run completed 20 tests successfully, but `scripts/test-unit.sh` exited 1 because Swift Testing now printed `Test run with 20 tests in 1 suite passed`. The shared summary script displayed the preceding XCTest `Executed 0 tests` as the last count. The real output is in `/private/tmp/t04-native-evidence/t04-focused-unit.log`.

## Requirements

- Recognize optional `in N suite(s)` between the Swift Testing test count and passed/failed status in the unit positive-count gate and shared summary parser.
- Preserve old Swift Testing and XCTest counts; continue rejecting zero or missing focused counts.
- Verify the real log through parser replay and mock runner contracts without simulator use.

## Approach

Extend each existing count expression with an optional suite-count phrase. Keep the existing guard and summary API, because their consumers already rely on them.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| Parse xcresult in the runner | Rich result data | Expands runner and needs tool/result access | Rejected |
| Optional suite phrase in existing patterns | Small, compatible change | Must cover both parser locations | Accepted |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `scripts/test-unit.sh` | Modify | Accept positive modern Swift Testing count |
| `scripts/lib/test-log-summary.py` | Modify | Display modern Swift Testing count |
| `scripts/tests/test_unit_test_runner.py` | Modify | Mock modern, old, zero, and missing output |
| `scripts/tests/test_test_log_summary.py` | Modify | Assert modern summary after XCTest zero |
| `docs/solutions/testing/2026-10-30-swift-testing-result-summary.md` | Add | Record diagnosis and validation |

## Implementation Steps

### Step 1: Extend the two count patterns

- **Files**: `scripts/test-unit.sh`, `scripts/lib/test-log-summary.py`
- **Changes**: Permit optional `in <positive count> suite(s)` before passed/failed.
- **Verification**: Syntax check and replay the supplied 20-test log through the summary parser and guard expression.

### Step 2: Contract tests

- **Files**: `scripts/tests/test_unit_test_runner.py`, `scripts/tests/test_test_log_summary.py`
- **Changes**: Test modern singular/plural suite output, original Swift Testing and XCTest output, and zero/missing cases.
- **Verification**: Run only Python parser/runner contract tests with fake xcodebuild and no simulator.

## Edge Cases

| Case | Handling |
|---|---|
| XCTest zero followed by Swift Testing 20 | Summary reports 20; focused guard passes |
| Original Swift Testing line | Still accepted |
| Zero tests in a suite | Focused guard rejects |
| No count line | Focused guard rejects |

## Testing Strategy

- Replay `/private/tmp/t04-native-evidence/t04-focused-unit.log` through `test-log-summary.py` and the runner's grep shape.
- Run affected Python contract modules plus shared summary consumer fixtures; do not launch native tests or simulators.
- `bash -n`, Python compilation, and `git diff --check`.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Different Swift Testing count wording | Medium | Medium | Keep patterns narrowly optional and use exact observed line fixture |
| Regressing shared UI summaries | Low | Medium | Run existing summary tests and UI runner contracts |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: Both failures are caused by the same optional phrase in a single observed log line.
