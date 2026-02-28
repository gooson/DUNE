---
tags: [workout, intensity, scoring, domain-service, percentile, signals]
date: 2026-02-28
category: solution
status: implemented
---

# Auto Workout Intensity Scoring Patterns

## Problem

운동 완료 후 세션 강도를 자동 산출해야 함. 운동 유형별(근력, 맨몸, 유산소, 유연성, HIIT)
강도 지표가 다르며, 히스토리 부족 시 graceful fallback 필요.

## Solution

### Multi-Signal Weighted Combination

| Signal | Weight | Source |
|--------|--------|--------|
| Primary (1RM%, pace percentile, etc.) | 60% | Exercise-type specific |
| Volume/Duration | 30% | Relative to history average |
| RPE | 10% | User input (optional) |

Missing signals redistribute weight proportionally via `combineSignals()`.

### Exercise-Type Dispatch

| Type | Primary Signal | Volume Signal | Method |
|------|---------------|---------------|--------|
| setsRepsWeight | avg(weight / 1RM) | sessionVolume / avgVolume | `.oneRMBased` |
| setsReps | reps percentile | totalReps / avgReps | `.repsPercentile` |
| durationDistance | 1 - pacePercentile | duration / avgDuration | `.pacePercentile` |
| durationIntensity | avgManualIntensity / 10 | duration / avgDuration | `.manualIntensity` |
| roundsBased | rounds percentile | duration / avgDuration | `.roundsPercentile` |

### Fallback Chain

```
Primary signal available? → combine(primary, volume, rpe)
Volume signal available?  → combine(nil, volume, rpe)
RPE available?           → rpeFallback (rpe/10)
Nothing available?       → nil (no badge shown)
```

### Key Design Decisions

1. **Percentile minimum count = 2**: Single-item history always returns 0.0 percentile,
   misclassifying PR sessions as "very light". `guard valid.count >= 2` returns nil instead.

2. **Duration volume signal extracted (DRY)**: Cardio, flexibility, HIIT share identical
   `durationVolumeSignal()` helper instead of 3x inline closure.

3. **Write-site validation**: `autoIntensityRaw` is guarded with `isFinite + (0...1).contains()`
   before persisting to CloudKit.

4. **Data→Domain boundary**: `ExerciseRecord` stores raw `Double?` only. Level classification
   (`WorkoutIntensityLevel(rawScore:)`) happens in Presentation layer.

## Prevention

- Percentile-based scoring always needs minimum sample count
- CloudKit-persisted numeric fields need range validation at write site
- `@Model` classes should not reference Domain enum types
- Duration-based volume is a shared pattern across 3+ exercise types — extract immediately
