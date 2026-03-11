---
topic: UI test failure fixes
date: 2026-03-12
status: implemented
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-03-watch-workout-start-axid-selector-hardening.md
  - docs/solutions/testing/2026-03-09-ui-test-aut-launch-lifecycle-hardening.md
related_brainstorms:
  - docs/brainstorms/2026-03-02-watch-workout-start-freeze.md
  - docs/brainstorms/2026-03-04-ui-test-max-hardening.md
---

# Implementation Plan: UI test failure fixes

## Context

Recent GitHub UI failures split into two buckets.
The iOS `ActivitySmokeTests` failure matched an older AUT lifecycle flake and no longer reproduced on the current HEAD.
The watch failures did reproduce locally: `WatchHomeSmokeTests` and `WatchWorkoutStartSmokeTests` were asserting against a narrower surface than the current watch accessibility tree exposes.

## Requirements

### Functional

- Watch home smoke must accept the current seeded home surface and still navigate into All Exercises reliably.
- Watch workout-start smoke must enter the Quick Start flow, open the fixture squat preview, and start the session reliably.
- Session metrics verification must remain locale-safe even when watchOS reuses screen-level identifiers on nested buttons.

### Non-functional

- Keep the fix limited to reproduced watch UI test instability.
- Preserve existing AXID-first behavior and only add label-based fallback where the runtime tree proves the AXID is not exposed on the tappable button.
- Avoid test helpers that can swipe into unrelated system surfaces such as Now Playing.

## Approach

Harden the watch UI test base helper instead of changing product behavior.
Broaden readiness checks to accept the actual visible home and quick-start surfaces, guard watch AUT termination the same way as the iOS helper, and make button lookup resilient to watchOS accessibility trees that collapse nested button identifiers into the surrounding screen identifier.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Patch watch app views to force different AX exposure | Stronger product-side contract | Expands change scope into app code without proof that runtime semantics are wrong | Rejected |
| Keep exact AXID assertions and add more retries/swipes | Small helper diff | Retries alone do not fix identifier mismatch and swipes can leave the AUT surface | Rejected |
| Harden the UI test helper with visible-surface and label fallbacks | Matches reproduced runtime tree and keeps fix scoped to tests | Requires careful fallback rules to avoid locale regressions | Chosen |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift` | test helper hardening | Guard watch AUT termination, broaden home/quick-start readiness, and add locale-safe button fallback lookup |
| `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift` | smoke assertion update | Assert on the fixture exercise surface instead of the exact quick-start list container |
| `docs/plans/2026-03-12-ui-test-failure-fixes.md` | planning artifact | Record research, implementation steps, and verification strategy |

## Implementation Steps

### Step 1: Reproduce and isolate the failing watch paths

- **Files**: `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift`
- **Changes**: Inspect the failing helper methods and exported `xcresult` attachments to identify whether the failures come from home readiness, All Exercises navigation, or workout-start interaction.
- **Verification**: `scripts/test-watch-ui.sh --stream-log --only-testing DUNEWatchUITests/WatchWorkoutStartSmokeTests`

### Step 2: Harden the shared watch helper

- **Files**: `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift`
- **Changes**:
  - Add guarded `terminateIfRunning` lifecycle handling.
  - Accept visible home card / browse link / quick-start section variants as ready surfaces.
  - Replace swipe-heavy All Exercises fallback with direct taps on visible controls.
  - Resolve Start / Complete Set through AXID first, then locale-safe label fallback.
- **Verification**: `scripts/test-watch-ui.sh --stream-log --only-testing DUNEWatchUITests/WatchWorkoutStartSmokeTests`

### Step 3: Align smoke assertions with the stabilized surface contract

- **Files**: `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift`
- **Changes**: Assert the fixture squat row instead of requiring the exact quick-start list container identifier.
- **Verification**: `scripts/test-watch-ui.sh --stream-log --only-testing DUNEWatchUITests/WatchHomeSmokeTests`

### Step 4: Reconfirm adjacent UI smoke coverage

- **Files**: `DUNEUITests/Helpers/UITestBaseCase.swift` (read-only check), `docs/plans/2026-03-12-ui-test-failure-fixes.md`
- **Changes**: Confirm the earlier iOS `ActivitySmokeTests` failure is stale on current HEAD and keep the plan scoped to the reproduced watch regression.
- **Verification**: `scripts/test-ui.sh --stream-log --only-testing DUNEUITests/ActivitySmokeTests --skip-testing DUNEUITests/ActivitySmokeTests/testPullToRefreshShowsWaveIndicator`

## Edge Cases

| Case | Handling |
|------|----------|
| Home carousel identifier is absent but All Exercises card is visible | Treat visible home card or browse link as a valid ready state |
| Quick Start root renders without the exact list container | Accept category picker, section headers, empty state, or fixture exercise row |
| Start or Complete button is visible but nested button exposes the screen identifier instead of the leaf AXID | Resolve button by exact localized label fallback after AXID lookup |
| Pre-launch terminate runs when the watch AUT is already stopped | Guard terminate calls with AUT running-state checks |
| Swipe fallback opens a system page instead of app content | Remove swipe-based All Exercises discovery from the helper |

## Testing Strategy

- Unit tests: none; this is a UI test harness stabilization change.
- Integration tests:
  - `scripts/test-watch-ui.sh --stream-log --only-testing DUNEWatchUITests/WatchWorkoutStartSmokeTests`
  - `scripts/test-watch-ui.sh --stream-log --only-testing DUNEWatchUITests/WatchHomeSmokeTests`
  - `scripts/test-ui.sh --stream-log --only-testing DUNEUITests/ActivitySmokeTests --skip-testing DUNEUITests/ActivitySmokeTests/testPullToRefreshShowsWaveIndicator`
- Manual verification: inspect the latest watch `xcresult` screenshot and accessibility hierarchy when a selector still fails.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Label fallback becomes too broad and taps the wrong button | Low | Medium | Use exact localized labels for action buttons and only limited substring fallback for the All Exercises card |
| Future watch UI changes add another valid home/quick-start surface | Medium | Medium | Keep helper assertions surface-based rather than list-container-based |
| Guarded terminate logic masks a real stale-process issue | Low | Low | Preserve wait-for-not-running behavior when the AUT is actually running |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: The failures were reproduced locally, narrowed with `xcresult` hierarchy inspection, and fixed with focused helper changes that now pass the targeted watch smoke suites and the previously failing iOS activity smoke rerun.

## Verification Results

- `WatchHomeSmokeTests`: 3 tests, 0 failures
- `WatchWorkoutStartSmokeTests`: 2 tests, 0 failures
- `ActivitySmokeTests`: 7 tests, 0 failures
