---
tags: [cardio, distance, gps, watch, healthkit, hkworkoutsession, live-tracking, workout-mode]
date: 2026-03-02
category: solution
status: implemented
---

# Watch Cardio Distance Auto-Tracking

## Problem

Watch workout tracking only supported strength mode (weight x reps). Cardio exercises (running, cycling, swimming, etc.) could not automatically collect distance, pace, heart rate, and calories in real-time.

## Solution

### Architecture: Single WorkoutManager + Mode Branch

`WorkoutMode` enum (Domain layer) distinguishes strength vs cardio:

```swift
enum WorkoutMode: Sendable, Codable {
    case strength
    case cardio(activityType: WorkoutActivityType, isOutdoor: Bool)
}
```

**Rationale**: HK session management, delegate, recovery code is identical. A separate CardioWorkoutManager would duplicate all session orchestration.

### HKWorkoutConfiguration

Cardio sessions configure `HKWorkoutConfiguration` with the correct `activityType` and `locationType` so `HKLiveWorkoutBuilder` automatically collects distance data:

```swift
let config = HKWorkoutConfiguration()
config.activityType = activityType.hkWorkoutActivityType  // e.g. .running
config.locationType = isOutdoor ? .outdoor : .indoor
```

### Distance Collection (Delegate)

The `HKLiveWorkoutBuilderDelegate` fires `didCollectDataOf` with distance quantity types. Statistics are extracted on the delegate thread (nonisolated), then primitive values dispatched to @MainActor to avoid cross-actor access of non-Sendable `HKLiveWorkoutBuilder`.

### Exercise -> Activity Type Resolution

3-step fallback in `WorkoutActivityType.resolveDistanceBased(from:name:)`:
1. Direct `rawValue` match (e.g., "running" -> `.running`)
2. Stem extraction (e.g., "running-treadmill" -> stem "running" -> `.running`)
3. Name-based inference via keyword matching (e.g., "Outdoor Running" -> `.running`)

### View Architecture

- `SessionPagingView` branches: `CardioMetricsView` (cardio) vs `MetricsView` (strength)
- `WorkoutPreviewView` branches: Outdoor/Indoor buttons (cardio) vs exercise list (strength)
- `ControlsView` hides "Skip Exercise" for cardio
- `SessionSummaryView` shows Distance/Pace (cardio) vs Volume/Sets (strength)

## Key Decisions

1. **`iconName` in shared Presentation**: SF Symbol name mapping extracted to `WorkoutActivityType+Icon.swift` (pure Foundation, no SwiftUI import) and shared with Watch via `project.yml`. The `+View.swift` file has SwiftUI+DS dependencies that can't be shared with Watch.

2. **`WorkoutMode` in Domain**: Placed in `Domain/Models/WorkoutMode.swift` and shared with Watch via `project.yml` — it references `WorkoutActivityType` which is already in Domain.

3. **Delegate race condition fix**: Extract `HKStatistics` values on the nonisolated delegate thread, then dispatch only primitive `Double` values to `@MainActor`.

4. **Pause-aware pace**: `updatePace()` skips recalculation when `isPaused` to avoid inflating pace with paused time.

5. **Error message security**: Generic error messages (`String(localized:)`) instead of exposing `error.localizedDescription` which may contain internal system details.

## Prevention

- When adding new HK quantity types to delegate collection, always extract stats before the actor hop.
- When adding new `WorkoutActivityType` cases, exhaustive switches in `iconName` and `isDistanceBased` will produce compiler errors — no `default:` catch-all.
- Recovery state (`restoreDistanceFromBuilder`) must cover all distance quantity types that `requestAuthorization` registers.
- `startCardioSession` must restore previous state on failure to prevent inconsistent `workoutMode`.

## Files Changed

| File | Change |
|------|--------|
| `Domain/Models/WorkoutMode.swift` | **New** — WorkoutMode enum |
| `Domain/Models/WorkoutActivityType.swift` | Added `iconName`, `resolveDistanceBased` |
| `Presentation/Shared/Extensions/WorkoutActivityType+View.swift` | Removed `iconName` (moved to +Icon.swift) |
| `Presentation/Shared/Extensions/WorkoutActivityType+Icon.swift` | **New** — Shared `iconName` for iOS+Watch |
| `project.yml` | Share WorkoutMode.swift + WorkoutActivityType+HealthKit.swift with Watch |
| `DUNEWatch/Managers/WorkoutManager.swift` | Cardio mode, distance/pace, delegate fix |
| `DUNEWatch/Views/CardioMetricsView.swift` | **New** — Real-time cardio metrics |
| `DUNEWatch/Views/WorkoutPreviewView.swift` | Outdoor/Indoor selection for cardio |
| `DUNEWatch/Views/SessionPagingView.swift` | Cardio/strength view branching |
| `DUNEWatch/Views/ControlsView.swift` | Hide Skip for cardio |
| `DUNEWatch/Views/SessionSummaryView.swift` | Distance/Pace stats for cardio |
| `DUNETests/CardioWorkoutModeTests.swift` | **New** — Unit tests |
