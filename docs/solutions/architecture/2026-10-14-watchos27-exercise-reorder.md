---
tags: [watchos27, swiftui, reorderable, workout, parallel-arrays]
category: architecture
date: 2026-10-14
severity: important
related_files:
  - DUNEWatch/Views/WatchExerciseReorderView.swift
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNEWatchTests/WorkoutManagerReorderTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-15-watch-exercise-reorder.md
  - docs/solutions/architecture/2026-03-30-template-exercise-transition-skip.md
---

# Solution: watchOS 27 exercise drag reorder with fixed completed entries

## Problem

The Watch session screen had only up/down controls. Native drag reorder must keep a completed exercise in its existing slot and preserve workout data stored by exercise index.

### Symptoms

- Dragging only `templateSnapshot.entries` would associate completed sets and extra set counts with different exercises.
- Giving a completed row `.reorderable()` would advertise a move the model must reject.

### Root Cause

`WorkoutManager` stores entries in one array while completed sets, extra sets, skipped flags, and current selection use positional indices.

## Solution

Pending rows are split into contiguous groups separated by completed rows. Each pending `ForEach` uses `.reorderable(collectionID:)`; the outer List uses `.reorderContainer(for:in:move:)`. The manager accepts entry UUIDs, validates the resulting permutation against fixed completed slots, and reconstructs all index-based state using old ID-to-index mapping before publishing the snapshot.

### Changes Made

| File | Change | Reason |
|---|---|---|
| `WatchExerciseReorderView.swift` | Native drag groups, with up/down controls retained | Direct and accessible interaction |
| `WorkoutManager.swift` | ID-based move validation and companion-state remapping | Data integrity |
| `WorkoutManagerReorderTests.swift` | Multi-source, completed boundary, invalid IDs, associated state | Regression coverage |

### Key Code

```swift
let oldIndexByID = Dictionary(uniqueKeysWithValues: originalIDs.enumerated().map { ($0.element, $0.offset) })
completedSetsData = orderedIDs.compactMap { id in oldIndexByID[id].map { completed[$0] } }
```

The mapping is reused for extra set counts, skipped indices, and current exercise identity. The existing button path continues to use `moveExercise(at:direction:)`.

## Prevention

When a Watch drag move changes exercise order, validate the full resulting order before mutating state. Every index-keyed companion collection must be remapped by stable entry ID, including skipped flags and current selection.

### Checklist Addition

- [ ] Check completed items are not drag sources and never change indices.
- [ ] Check `ReorderDifference` `.end` resolves to the end of its pending group.
- [ ] Run Watch build, focused tests, simulator gesture/accessibility checks, and fresh design-map capture before shipping.

## Lessons Learned

The watchOS 27 SDK exposes `ReorderDifference.sources` and a destination of `.before(ID)` or `.end`. Multiple reorderable groups require a collection ID. Apple WWDC26 session 271 demonstrates separating fixed and reorderable `ForEach` content.
