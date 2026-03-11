---
topic: watch stair no-motion detection
date: 2026-03-11
status: approved
confidence: high
related_solutions:
  - docs/solutions/healthkit/flights-climbed-tracking.md
  - docs/solutions/healthkit/2026-03-05-watch-cardio-step-count-collection.md
  - docs/solutions/general/2026-03-10-watch-stair-climber-mixed-cardio-fallback.md
related_brainstorms:
  - docs/brainstorms/2026-03-11-watch-stair-no-motion-detection.md
  - docs/brainstorms/2026-03-07-cardio-no-motion-end-recommendation.md
---

# Implementation Plan: Watch Stair No-Motion Detection

## Context

Apple Watch cardio inactivity detection currently treats only `distance` and `steps` growth as proof of movement.
That works for distance-based cardio, but it produces false `No movement detected` prompts on stair and other machine-cardio sessions when the wrist stays relatively fixed.

The approved direction is to keep the existing inactivity thresholds and UX copy, while making the detector activity-aware for machine cardio:

- stair-based activities should count `floorsClimbed` progress as activity
- machine cardio should count `activeCalories` growth as a fallback activity signal

## Requirements

### Functional

- Reduce false inactivity prompts for machine cardio sessions on Watch.
- Preserve current inactivity behavior for distance-based cardio.
- Treat `floorsClimbed` as activity progress for stair-based cardio.
- Treat `activeCalories` growth as fallback activity progress for machine-cardio sessions.
- Keep existing thresholds (`75s`, `120s`, `10s countdown`) unchanged.

### Non-functional

- Keep the change watch-only and detector-only.
- Avoid copy or UI changes unless strictly required.
- Make the new detection rule testable with Swift Testing.
- Reuse existing domain semantics such as `isStairBased` and `supportsMachineLevel`.

## Approach

Introduce a small pure progress evaluator inside the Watch inactivity path and expand the tracked baseline metrics.

- Add previous-observed baselines for `floorsClimbed` and `activeCalories`.
- Evaluate “activity progressed” using activity-aware rules:
  - all cardio: `distance` or `steps` increase still counts
  - stair cardio: `floorsClimbed` increase also counts
  - machine cardio (`supportsMachineLevel == true`): `activeCalories` increase also counts
- Keep `CardioInactivityPolicy` thresholds and prompt flow unchanged.
- Add focused watch unit tests for the new activity-signal behavior.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Stair-only `floorsClimbed` support | Very small diff, low risk | Does not help elliptical/time-only machine cardio | Rejected |
| Machine-cardio-aware progress evaluator | Covers approved scope and stays local to detector | Needs extra baseline state and tests | Chosen |
| Heart-rate-based guard | Could catch more false positives | Harder to tune, slower recovery after actual stop | Deferred |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEWatch/Managers/WorkoutManager.swift` | Edit | Expand inactivity baseline state and apply machine-cardio-aware activity detection |
| `DUNEWatchTests/CardioInactivitySignalTests.swift` | New | Add unit tests for stair floors fallback, machine-cardio calorie fallback, and unchanged distance-cardio behavior |
| `docs/plans/2026-03-11-watch-stair-no-motion-detection.md` | New | Record implementation plan |

## Implementation Steps

### Step 1: Expand inactivity tracking baselines

- **Files**: `DUNEWatch/Managers/WorkoutManager.swift`
- **Changes**:
  - add observed baselines for `floorsClimbed` and `activeCalories`
  - update reset/start/inactivity-reset paths so all tracked metrics share the same baseline lifecycle
- **Verification**:
  - code compiles
  - baseline reset logic remains symmetric with existing `distance`/`steps` handling

### Step 2: Apply activity-aware no-motion detection

- **Files**: `DUNEWatch/Managers/WorkoutManager.swift`
- **Changes**:
  - introduce a small pure helper or local evaluator for “has activity progressed”
  - treat stair `floorsClimbed` progress as activity
  - treat machine-cardio `activeCalories` progress as fallback activity
  - keep thresholds, prompts, and countdown behavior unchanged
- **Verification**:
  - distance cardio still depends on existing progress signals
  - machine cardio uses the approved fallback signals without touching UI copy

### Step 3: Add regression tests

- **Files**: `DUNEWatchTests/CardioInactivitySignalTests.swift`
- **Changes**:
  - add tests for stair floors progress
  - add tests for machine-cardio calorie fallback
  - add tests proving ordinary distance cardio behavior is unchanged
  - add a negative case where machine-cardio metrics do not progress
- **Verification**:
  - Swift Testing coverage exists for the new evaluator
  - test names encode the intended behavior clearly

## Edge Cases

| Case | Handling |
|------|----------|
| Stair workout with no step increase but floors increase | Count as activity |
| Elliptical or other machine cardio with no distance/steps increase but calories increase | Count as activity |
| Machine cardio with static metrics after actual stop | Allow existing inactivity policy to proceed |
| Distance cardio with calorie increase only | Do not broaden behavior; keep existing distance/step rules |
| Very low-intensity machine cardio with delayed calorie updates | Accept slightly later false-positive reduction bias per approved priority |

## Testing Strategy

- Unit tests: add focused Swift Testing coverage in `DUNEWatchTests/CardioInactivitySignalTests.swift`
- Integration tests: none required; no HealthKit API contract changes are introduced
- Build verification: run `scripts/build-ios.sh`
- Manual verification:
  - verify no new copy/localization changes were introduced
  - if feasible later, smoke-test a Watch machine-cardio session to confirm prompts do not appear while floors/calories advance

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `activeCalories` lags and delays legitimate inactivity prompts | Medium | Medium | Restrict fallback to machine cardio only and keep thresholds unchanged |
| New baselines become inconsistent with reset/recovery paths | Medium | High | Update every reset path together and cover negative cases in unit tests |
| Detector becomes too permissive for non-machine cardio | Low | High | Gate calorie fallback behind `supportsMachineLevel` only |
| Extra helper introduces over-design | Low | Low | Keep helper small, pure, and local to inactivity logic |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: The fix is local to Watch inactivity detection, reuses existing `isStairBased` and `supportsMachineLevel` semantics, and can be regression-tested without introducing new API or UI surface.
