---
tags: [unit-testing, xcodebuild, selector, simulator-lock, zero-tests]
category: testing
date: 2026-10-30
severity: important
related_files:
  - scripts/test-unit.sh
  - scripts/lib/validate-unit-test-selectors.py
  - scripts/tests/test_unit_test_runner.py
related_solutions:
  - docs/solutions/testing/2026-09-27-simulator-test-serialization.md
  - docs/solutions/testing/2026-03-21-e2e-activity-exercise-closeout-042-064.md
---

# Solution: Focused unit tests through the standard runner

## Problem

### Symptoms

`scripts/test-unit.sh` always ran the full iOS suite before Watch. A screen change could not run only its related unit tests through the owned simulator and log path. A misspelled selector could also appear green if `xcodebuild` returned success after executing zero selected tests.

### Root Cause

The runner hardcoded `-only-testing DUNETests` and `-only-testing DUNEWatchTests`, with no selector parsing, per-target routing, or positive-count gate.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| `scripts/test-unit.sh` | Accept repeated `--only-testing`, validate before lock, route by target, offer side-effect-free `--dry-run`, check focused log counts | Preserve the existing runner while enabling focused tests |
| `scripts/lib/validate-unit-test-selectors.py` | Check each requested suite and method within its top-level test type in target Swift sources | Prevent a valid selector from hiding another selector that runs no tests |
| `scripts/tests/test_unit_test_runner.py` | Exercise real CLI parser with fake tools and log fixtures | Verify argv, rejection, split logs, and exit status without a simulator |

### Key Code

```bash
scripts/test-unit.sh --ios-only --only-testing DUNETests/CalculateConditionScoreUseCaseTests
scripts/test-unit.sh --only-testing DUNETests/CalculateConditionScoreUseCaseTests --only-testing DUNEWatchTests/WatchRPEEstimatorTests
scripts/test-unit.sh --dry-run --only-testing DUNETests/CalculateConditionScoreUseCaseTests
```

No selector keeps the original sequential iOS and Watch full-target runs. Focused runs require a positive XCTest or Swift Testing executed-test count in each selected suite log. Source validation scopes methods to their suite, and checks both `DUNETests/` and `DUNE/DUNETests/` plus `DUNEWatchTests/`.

## Validation

- `python3 -m unittest scripts.tests.test_unit_test_runner`: 9 passed, fake tools only.
- `bash -n scripts/test-unit.sh` and `git diff --check`: passed.
- Pre-commit checks passed. Real simulator and xcodebuild test execution were deferred because another worktree held the repository test lock; this tooling-only change has no UI gate.

## Prevention

Use target-qualified class or method selectors through the standard runner. Check dry-run argv for a new selection, and treat zero or unknown executed-test counts as failure. Keep the no-selector full run for broad CI coverage.

### Checklist Addition

- [ ] New runner options preserve the no-selector iOS and Watch dispatch.
- [ ] Every focused selector is validated before simulator work.
- [ ] A successful process exit includes positive test execution evidence.

## Lessons Learned

A positive aggregate count alone does not prove every requested selector exists. Preflight each selector, then check runtime execution per selected target.
