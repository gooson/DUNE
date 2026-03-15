---
tags: [watchos, quick-start, workout-procedure, watch-connectivity, progressive-overload]
category: architecture
date: 2026-03-15
severity: important
related_files:
  - DUNE/Data/WatchConnectivity/WatchExerciseLibraryPayloadBuilder.swift
  - DUNE/Domain/Models/WatchConnectivityModels.swift
  - DUNEWatch/Helpers/WatchExerciseHelpers.swift
  - DUNEWatch/Managers/RecentExerciseTracker.swift
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNEWatch/Views/MetricsView.swift
  - DUNEWatch/Views/SessionSummaryView.swift
related_solutions: []
---

# Solution: Watch Quick Start Procedure Memory With Progression Overlay

## Problem

Watch Quick Start remembered only the last completed set's weight and reps. It could not restore the full prior procedure for the next run of the same exercise.

### Symptoms

- Quick Start reopened with only the last set's weight and reps instead of set-by-set values.
- Total set count always fell back to `exercise.defaultSets` even when the last completed session used a different count.
- iPhone-side progression behavior was not reflected when the watch restored a previous strength session.
- Exact exercise variants needed separate replay data, but existing recent-set fallback was canonicalized.

### Root Cause

The watch payload model and local tracker only stored canonical usage metadata plus a single latest set snapshot. There was no compact representation for a completed procedure, no sync field for exact-ID procedure replay, and no runtime path that mapped restored set plans into Metrics prefill.

## Solution

Persist the latest completed procedure as compact per-set snapshots, sync it through `WatchExerciseInfo`, and resolve the watch runtime defaults from that procedure before falling back to latest-set/default values. Apply the existing progression increment as a read-time overlay on the first restored set so replay and overload stay composed instead of competing.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Models/WatchConnectivityModels.swift` | Added `WatchProcedureSetSnapshot` and new `WatchExerciseInfo` fields for procedure sets, update timestamp, and progression increment | Extend the sync contract without breaking older payloads |
| `DUNE/Data/WatchConnectivity/WatchExerciseLibraryPayloadBuilder.swift` | Built exact-ID procedure metadata from latest completed `ExerciseRecord` and attached progression increment metadata | Make iPhone history available to the watch as replay data |
| `DUNEWatch/Managers/RecentExerciseTracker.swift` | Added exact-ID local procedure persistence | Preserve watch-completed sessions immediately, even before the next sync |
| `DUNEWatch/Helpers/WatchExerciseHelpers.swift` | Resolved defaults and total sets from procedure snapshots, preferring the newer of local vs synced data | Centralize replay logic in one place used by list UI and navigation |
| `DUNEWatch/Managers/WorkoutManager.swift` | Added planned-set lookup on the active template snapshot | Let runtime set entry restore set 1/2/3 individually |
| `DUNEWatch/Views/MetricsView.swift` | Prefilled from planned set before within-session fallback | Ensure each restored set opens with the intended weight/reps |
| `DUNEWatch/Views/SessionSummaryView.swift` | Recorded the completed watch procedure on finish | Save replay data only for completed sessions |
| `DUNETests/*`, `DUNEWatchTests/*` | Added payload, compatibility, helper, and tracker coverage | Lock the replay/progression behavior in tests |

### Key Code

```swift
func resolvedProcedureSets(for exercise: WatchExerciseInfo) -> [WatchProcedureSetSnapshot]? {
    let local = RecentExerciseTracker.latestProcedure(exerciseID: exercise.id)
    let syncedUpdatedAt = exercise.procedureUpdatedAt?.timeIntervalSince1970 ?? .leastNormalMagnitude

    let baseSets: [WatchProcedureSetSnapshot]?
    if let local, local.updatedAt >= syncedUpdatedAt {
        baseSets = local.sets
    } else {
        baseSets = exercise.procedureSets
    }

    guard let baseSets, !baseSets.isEmpty else { return nil }
    return applyingProgressionOverlay(to: baseSets, incrementKg: exercise.progressionIncrementKg)
}
```

This keeps source-of-truth selection and progression composition in one helper, so list subtitles, preview snapshots, and live set entry all restore the same plan.

## Prevention

When a watch feature needs "resume/replay last workout" behavior, do not persist only the last scalar default. Model the replay unit explicitly and keep sync metadata separate from runtime resolution rules.

### Checklist Addition

- [ ] If watch UI must replay prior workout structure, store a compact per-step snapshot instead of only the last set/value.
- [ ] If iPhone and watch can both author the same replay data, include a comparable freshness signal and resolve it in one helper.
- [ ] Apply progression/level-up as a read-time overlay so raw history and recommendation logic remain independently testable.

### Rule Addition (if applicable)

No new project rule was required. Existing layer boundaries were sufficient once replay resolution stayed in helpers/trackers instead of views.

## Lessons Learned

- Full workout replay is a different problem from "latest default" recovery; the model needs set-by-set data.
- Exact-ID replay and canonical popularity/defaults can coexist if they are stored in separate channels.
- Applying progression at resolution time avoids mutating persisted history and keeps sync semantics simpler.
