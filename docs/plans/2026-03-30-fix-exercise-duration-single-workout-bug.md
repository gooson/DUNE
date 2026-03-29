---
tags: [exercise, duration, bug-fix, dashboard, healthkit]
date: 2026-03-30
category: plan
status: draft
---

# Fix: Exercise Duration Shows Only Single Workout Duration

## Problem

Exercise metric on the Dashboard and MetricDetailView shows "5 min" when the user exercised for 100+ minutes.
The hero value only reflects the **latest single workout's duration** instead of summing all workouts from that day.

### Root Cause

`DashboardViewModel.fetchExerciseData()` line 976:
```swift
} else if let latest = recentWorkouts.first {
    let totalMinutes = latest.duration / 60.0  // BUG: only 1 workout
```

When today has no workouts, the fallback path takes only the first (latest) workout's duration.
The `minutesByDay` dictionary already contains the correctly aggregated daily totals, but is not used in this branch.

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | Fix fallback branch to sum all workouts for the latest day |
| `DUNE/DUNETests/` (new test file) | Add unit test for the fix |

## Implementation Steps

### Step 1: Fix `fetchExerciseData()` fallback branch

In `DashboardViewModel.swift`, replace the `else if let latest = recentWorkouts.first` branch (lines 975-989):

**Before:**
```swift
} else if let latest = recentWorkouts.first {
    let totalMinutes = latest.duration / 60.0
```

**After:**
```swift
} else if let latest = recentWorkouts.first {
    let latestDay = calendar.startOfDay(for: latest.date)
    let totalMinutes = minutesByDay[latestDay] ?? (latest.duration / 60.0)
```

This uses the already-computed `minutesByDay` dictionary which correctly sums all workouts per day.

### Step 2: Add unit test

Create a test that verifies when multiple workouts exist for a day, the exercise metric value equals the sum of all durations, not just the latest one.

## Test Strategy

- Unit test: Multiple workouts on same day → metric.value == sum of all durations
- Manual: Check Exercise detail view shows correct total after fix

## Risks & Edge Cases

- `minutesByDay` key is `startOfDay(for: workout.date)` — matches correctly
- If no entry in `minutesByDay`, falls back to single workout (defensive)
- The chart data in MetricDetailViewModel already uses `groupWorkoutsByDay` which sums correctly — no change needed there
