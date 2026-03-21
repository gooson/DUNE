---
topic: nightly-run-23359618963-failure-fix
date: 2026-03-22
status: completed
confidence: medium
related_solutions:
  - docs/solutions/testing/2026-03-12-ci-nightly-test-failures-fix.md
  - docs/solutions/general/2026-03-09-muscle-map-anatomy-layer-toggle.md
  - docs/solutions/architecture/2026-03-15-template-workout-exercise-reorder.md
  - docs/solutions/testing/2026-03-09-watch-workout-surface-inventory.md
related_brainstorms:
  - docs/brainstorms/2026-03-15-reorder-workout-exercises.md
  - docs/brainstorms/2026-03-15-watch-template-exercise-reorder.md
---

# Implementation Plan: Nightly Run #23359618963 Failure Fix

## Context

GitHub Actions run `23359618963` for `Nightly Full Tests (Unit + UI)` failed on `2026-03-20` against commit `d24c4df9`.
The run failed in two actionable jobs:

- `nightly-ios-unit-tests`
- `nightly-watch-ui-tests`

Current workspace HEAD is `7c1b8a77` on `main`, so this task must separate failures that were already fixed after the run from failures that are still reproducible now.

Log review shows two categories:

1. historical failures that already appear to have follow-up fixes on current HEAD
2. current unit-test contract drift that likely still exists in the workspace

## Requirements

### Functional

- Reproduce the actionable nightly failures on current HEAD and classify them as fixed vs still open.
- Fix any still-open regressions so the same nightly lane would pass from current code.
- Preserve the intended shipped behavior documented in existing solution notes.

### Non-functional

- Minimize behavior changes and prefer restoring documented contracts over inventing new ones.
- Keep test expectations aligned with current product behavior where the code is already correct.
- Leave clear documentation of root cause and prevention after verification.

## Approach

Treat the historical CI run as the incident report, but use current HEAD as the repair target.

- First, run focused iOS/watch verification to confirm which failures are still live.
- For `DashboardViewModel` and watch `SetInputSheet`, current code already contains likely follow-up fixes, so these should be verified rather than re-fixed blindly.
- For `MuscleMap3DState`, `postureImageDisplayContext`, and `TemplateWorkoutViewModel` reorder behavior, compare current code against the documented intended contract and repair either implementation or stale tests.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Patch only the tests to make current HEAD green | Fastest | Risks codifying incorrect runtime behavior if production regressed | Rejected |
| Revert current production code toward the old failing run state | Simple mental model | Would discard fixes already landed after the incident | Rejected |
| Reproduce on current HEAD, then fix only still-open regressions with contract review | Separates historical noise from live defects | Requires more upfront analysis | Chosen |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-22-nightly-run-23359618963-failure-fix.md` | add | Investigation and implementation plan |
| `DUNETests/MuscleMapDetailViewModelTests.swift` | verify / modify | Align anatomy-layer and camera expectations with shipped 3D contract |
| `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift` | verify / modify | Restore documented shell opacity / preferred yaw behavior if regressed |
| `DUNETests/PostureAnalysisServiceTests.swift` | verify / modify | Confirm normalized JPEG marker handling and legacy correction expectations |
| `DUNE/Presentation/Posture/Components/ZoomablePostureImageView.swift` | verify / modify | Fix marker-aware image/joint correction if runtime behavior regressed |
| `DUNETests/TemplateWorkoutTests.swift` | modify | Remove or update stale completed-reorder expectation |
| `DUNE/Presentation/Exercise/TemplateWorkoutViewModel.swift` | verify | Confirm reorder guard matches intended completed-item contract |
| `DUNETests/DashboardViewModelTests.swift` | verify | Confirm deferred shared snapshot fallback test remains fixed |
| `DUNEWatch/Views/SetInputSheet.swift` | verify | Confirm watch overflow fix remains effective |
| `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift` | verify / modify | Stabilize rest/summary progression only if watch smoke still fails |
| `DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.swift` | verify / modify | Keep nightly watch flow assertions aligned with current watch lane |

## Implementation Steps

### Step 1: Reproduce current failures from the historical nightly set

- **Files**: none
- **Changes**:
  - Run focused iOS unit tests for the historically failing suites.
  - Run focused watch smoke tests if the local simulator environment allows it.
  - Record which failures are already resolved on current HEAD.
- **Verification**: focused test command output clearly separates passing vs failing suites.

### Step 2: Repair live iOS unit regressions

- **Files**: `DUNETests/MuscleMapDetailViewModelTests.swift`, `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift`, `DUNETests/PostureAnalysisServiceTests.swift`, `DUNE/Presentation/Posture/Components/ZoomablePostureImageView.swift`, `DUNETests/TemplateWorkoutTests.swift`
- **Changes**:
  - Restore `MuscleMap3DState` to the documented anatomy-layer contract if production regressed, otherwise update stale tests.
  - Fix posture normalized-JPEG marker handling if the helper regressed, otherwise adjust the test if image decoding changed and the contract was updated intentionally.
  - Reconcile reorder tests so completed exercises are consistently guarded from movement.
- **Verification**: targeted iOS unit tests pass with no residual failures in the affected suites.

### Step 3: Verify historical watch/UI fixes and patch only if still failing

- **Files**: `DUNEWatch/Views/SetInputSheet.swift`, `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift`, `DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.swift`
- **Changes**:
  - Confirm the existing `ScrollView` set-input fix resolved the historical overflow issue.
  - If watch smoke still flakes, tighten the helper around rest timer / summary transitions without changing user behavior.
- **Verification**: focused watch smoke lane passes locally or, if simulator constraints block that, iOS/watch build evidence plus code-path review support the fix.

### Step 4: Run broader verification and document the repair

- **Files**: `docs/solutions/testing/...` or a new solution note if needed
- **Changes**:
  - Run the standard build/test checks required for this repair.
  - Write a solution note describing the true remaining root causes and which historical failures were already fixed upstream.
- **Verification**: `scripts/build-ios.sh` and relevant test commands complete successfully, and the solution doc is saved.

## Edge Cases

| Case | Handling |
|------|----------|
| Historical run failed on an older commit but current HEAD already contains partial fixes | Treat as verification only; do not re-edit blindly |
| Local watch simulator cannot faithfully reproduce CI | Use focused code-path review plus any runnable watch evidence, and report the gap explicitly |
| Test failures are caused by stale expectations, not runtime bugs | Update tests only after cross-checking the intended behavior in existing solution docs |
| UIImage metadata decoding differs across environments | Verify marker parsing directly before changing posture correction logic |

## Testing Strategy

- Unit tests: focused `DUNETests` runs for `DashboardViewModelTests`, `MuscleMapDetailViewModelTests`, `PostureAnalysisServiceTests`, `TemplateWorkoutTests`
- Integration tests: `scripts/build-ios.sh`, targeted watch smoke run if environment supports it
- Manual verification: compare current HEAD behavior against run `23359618963` logs and existing solution docs

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Fixing tests around muscle-map behavior could hide a real 3D runtime regression | Medium | High | Cross-check against the existing shipped-scope solution doc before changing assertions |
| Watch smoke remains environment-sensitive locally | High | Medium | Keep code changes minimal and report any simulator-specific verification gap |
| Posture image decoding differs between CI and local simulator | Medium | Medium | Verify metadata marker parsing independently from the UI layer |
| Detached HEAD causes commit/ship friction | Medium | Low | Create a `codex/` branch before implementation if edits are required |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: The incident logs are clear and current HEAD already contains some follow-up fixes, but several remaining failures require careful contract validation to avoid "fixing" the wrong side of the test.
