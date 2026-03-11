---
tags: [ci, testing, rpe, shareplay, wellness, whats-new]
date: 2026-03-12
category: plan
status: approved
---

# CI Test Failure Fixes

## Problem

GitHub Actions run #22966361570 failed with 4 test suite failures (10+ individual test failures).

## Root Cause Analysis

### 1. RPELevelTests (3 tests) — Formula drift
- `averageSetRPE()` uses `Int(round(normalized * 9.0)) + 1`
- For RPE 8.0: `round(0.5 * 9.0) = round(4.5) = 5`, then `5 + 1 = 6`
- Tests expect `5` (truncation behavior: `Int(4.5) + 1 = 5`)
- **Fix**: Remove `round()` — use `Int(normalized * 9.0) + 1` (truncation)

### 2. VisionSharePlayWorkoutViewModelTests (5 tests) — Async timing
- Tests yield events via `controller.yield()`, then `await Task.yield()`, then check state
- The VM's event loop runs in a separate Task; `Task.yield()` is insufficient to guarantee event processing
- CI environment scheduling makes this consistently fail
- **Fix**: Replace `await Task.yield()` with `try? await Task.sleep(for: .milliseconds(100))` for reliable timing

### 3. WellnessViewModelTests (1 test) — Confidence calculation
- Test provides 3 `sleepDailyDurations` entries → expects `.low` confidence (< 7 days)
- But `buildSleepWeeklySeries()` always generates 7 entries (zero-padded)
- So `sleepDetailTrend.count = 7` → `computeConfidence(7) = .medium`
- **Fix**: Count only non-zero sleep entries for `dataAvailableDays`

### 4. WhatsNewManagerTests (2 tests) — Stale test data
- `whats-new.json` v0.2.0 now has 12 features (was 11)
- Added: cardioLiveTracking, coachingInsights, localization, airQuality
- Removed: conditionScore (moved to v0.1.0), wellness (moved to v0.1.0), muscleMap (moved to v0.1.0)
- **Fix**: Update test expectations to match current JSON

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Domain/UseCases/WorkoutIntensityService.swift` | Remove `round()` from effort mapping |
| `DUNETests/VisionSharePlayWorkoutViewModelTests.swift` | Replace `Task.yield()` with `Task.sleep()` |
| `DUNE/Presentation/Wellness/WellnessViewModel.swift` | Count non-zero days for confidence |
| `DUNETests/WhatsNewManagerTests.swift` | Update expected feature count and IDs |

## Implementation Steps

### Step 1: Fix RPE effort mapping formula
- In `WorkoutIntensityService.averageSetRPE()`, change `Int(round(normalized * 9.0)) + 1` to `Int(normalized * 9.0) + 1`

### Step 2: Fix VisionSharePlay test timing
- Replace `await Task.yield()` with `try? await Task.sleep(for: .milliseconds(100))` in all event-based tests

### Step 3: Fix sleep prediction confidence
- In `WellnessViewModel.recomputeSleepPrediction()`, use `sleepDetailTrend.filter { $0.minutes > 0 }.count` for `dataAvailableDays`

### Step 4: Update WhatsNew test expectations
- Change expected count from 11 to 12
- Update expected feature IDs to match current JSON

## Test Strategy

- Run full test suite locally after all fixes
- All 4 failing test suites should pass
- No regressions in other tests

## Risks

- RPE formula change affects effort display in UI → Verify RPE 6→1, 8→5, 10→10 mapping is correct
- Task.sleep timing may still be flaky → 100ms should be sufficient for CI
- Sleep confidence change may affect prediction accuracy → Only affects confidence label, not score
