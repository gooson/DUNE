---
topic: Unit test runner selection
date: 2026-10-30
status: approved
confidence: high
related_solutions:
  - docs/solutions/testing/2026-09-27-simulator-test-serialization.md
  - docs/solutions/testing/2026-03-21-e2e-activity-exercise-closeout-042-064.md
related_brainstorms: []
---

# Implementation Plan: Unit test runner selection

## Context

The standard unit runner always launches every iOS test before a Watch run. Screen work needs repeatable focused selectors while preserving the default full gate and simulator ownership.

## Requirements

- Accept repeated target-qualified `--only-testing` selectors and route them to the correct scheme.
- Reject empty, malformed, or mode-incompatible selectors before regeneration or simulator work.
- Keep no-selector iOS plus Watch behavior and existing lock, boot, and log handling.
- Reject an apparently successful focused run that executed no tests.

## Approach

Parse and validate selectors before side effects, then partition them by target. A focused invocation runs only targets that received selectors. Add dry-run command output for isolated argv checks and use the existing summary patterns for positive-count verification.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| Direct `xcodebuild` from callers | No script change | Loses standard simulator and log contract | Rejected |
| Selector-aware standard runner | Shared entry point; preserves defaults | Small parser and log guard | Accepted |
| Source-level selector discovery | Can reject unknown classes early | Swift Testing discovery is complex and brittle | Rejected |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `scripts/test-unit.sh` | Modify | Parse, validate, route selectors and dry-run commands |
| `scripts/tests/test_unit_test_runner.py` | Add | Mocked CLI argv and error-path tests |
| `docs/solutions/testing/2026-10-30-unit-test-selection.md` | Add | Record result and usage |

## Implementation Steps

### Step 1: Parse and route selectors

- **Files**: `scripts/test-unit.sh`
- **Changes**: Validate before lock/regen, partition by target, assemble per-suite `-only-testing` args; dry-run before simulator work.
- **Verification**: `bash -n scripts/test-unit.sh`; dry-run CLI output for both targets.

### Step 2: Add execution guard and contracts

- **Files**: `scripts/test-unit.sh`, `scripts/tests/test_unit_test_runner.py`
- **Changes**: For focused runs, inspect suite log for positive executed-test evidence; test real shell parser and arrays with fake tools.
- **Verification**: `python3 -m unittest scripts.tests.test_unit_test_runner` without real simulator or xcodebuild.

## Edge Cases

| Case | Handling |
|---|---|
| Selector missing or empty | Exit 2 before side effects |
| Wrong target for mode | Exit 2 before side effects |
| No selectors | Original two-suite behavior |
| Both target selectors | Run iOS then Watch, each with own options/log |
| Zero or missing count | Focused run fails even if xcodebuild exits 0 |

## Testing Strategy

- Python subprocess contracts with fake `xcodebuild`, `xcrun`, lock verifier, and simulator helpers.
- Shell syntax and diff checks.
- No real simulator or unit test launch while another worktree owns the lock. UI gate does not apply to tooling-only changes.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Swift Testing log formats differ | Medium | Medium | Accept existing XCTest and Swift Testing count patterns; cover both fixtures |
| Changing default execution | Low | High | Test no-selector iOS and Watch argv |
| Unexpected simulator side effect in dry-run | Low | Medium | Test fake tools are untouched |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: Runner already has separate suite dispatch, and the UI runner supplies an established dry-run pattern.
