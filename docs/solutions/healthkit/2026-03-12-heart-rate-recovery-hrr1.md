---
tags: [healthkit, heart-rate, recovery, hrr1, workout-detail]
date: 2026-03-12
category: solution
status: implemented
---

# Heart Rate Recovery (HRR₁) Analysis

## Problem

Workout detail view showed basic HR stats (avg/max/min) but lacked clinically meaningful recovery analysis. HRR₁ (heart rate drop in first 60s post-workout) is a validated cardiovascular fitness indicator.

## Solution

On-the-fly computation from HealthKit HR samples — no schema migration needed.

### Algorithm

1. **Peak HR**: Max BPM in `[workoutEnd - 60s, workoutEnd]`
2. **Recovery HR**: Average BPM in `[workoutEnd + 45s, workoutEnd + 75s]` (60s ± 15s window)
3. **HRR₁** = Peak - Recovery
4. **Rating**: < 12 bpm = Low, 12-20 = Normal, > 20 = Good

### Key Decisions

- **No schema migration**: Computed at display time from existing HealthKit samples, avoiding V12→V13 migration
- **Static `computeRecovery()`**: Extracted for unit testability without HealthKit dependency
- **Guard `peakHR > recoveryHR`**: Returns nil for invalid data rather than producing negative HRR₁
- **View-level guard `hrr1 > 0`**: Defense-in-depth against direct struct construction with invalid values
- **`displayName` on Rating enum**: Domain layer owns localized label via `String(localized:)`
- **`color` in +View extension**: Presentation layer owns Color mapping per layer boundary rules

### Files

| File | Role |
|------|------|
| `Domain/Models/HealthMetric.swift` | `HeartRateRecovery` model + `Rating` enum with `displayName` |
| `Data/HealthKit/HeartRateQueryService.swift` | `fetchHeartRateRecovery` + static `computeRecovery` |
| `Presentation/Exercise/HealthKitWorkoutDetailView.swift` | Recovery row display |
| `Presentation/Exercise/HealthKitWorkoutDetailViewModel.swift` | Parallel fetch via `async let` |
| `Presentation/Shared/Extensions/HeartRateRecovery+View.swift` | Rating → Color mapping |

### Test Coverage

14 tests in 2 suites:
- Model: HRR₁ computation, all 3 ratings, boundary values (11, 12, 20, 21)
- Compute: Normal case, no peak, no recovery, peak < recovery, empty samples, window boundaries

## Prevention

- When extending a protocol (e.g., `HeartRateQuerying`), update ALL mock implementations in test files
- Domain model structs with computed properties from stored values should have view-level guards against invalid construction
- Mock data should be deterministic (fixed offsets, not `Double.random`) for reproducible simulator testing
