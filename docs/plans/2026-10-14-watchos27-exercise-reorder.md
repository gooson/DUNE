---
topic: watchOS 27 exercise reorder
date: 2026-10-14
status: implemented
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-15-watch-exercise-reorder.md
  - docs/solutions/architecture/2026-03-30-template-exercise-transition-skip.md
related_brainstorms:
  - docs/brainstorms/2026-03-15-watch-template-exercise-reorder.md
---

# Implementation Plan: watchOS 27 exercise reorder

## Context

The Watch session reorder sheet only has up/down buttons. watchOS 27 adds native drag reordering to SwiftUI containers.

## Requirements

- Drag pending exercises within a contiguous pending group while completed entries retain their positions.
- Preserve completed sets, extra set counts, skipped flags, and current exercise identity when moving entries.
- Keep explicit accessible up/down controls.

## Approach

Split rows at completed entries and apply `.reorderable(collectionID:)` only to pending `ForEach` content. Scope groups with `.reorderContainer(for:in:move:)`. Translate the SDK's `ReorderDifference` source IDs and before/end destination to a manager operation. Rebuild index-based state by stable entry UUID.

### Alternative Approaches Considered

| Approach | Benefit | Risk | Decision |
|---|---|---|---|
| Make every row reorderable and reject invalid drops | Small diff | Completed items appear draggable | Rejected |
| Apply repeated adjacent swaps | Reuses existing function | Intermediate state and repeated persistence | Rejected |
| Rebuild by stable IDs | Atomic state change | Needs permutation validation | Selected |

## Affected Files

| File | Change |
|---|---|
| `DUNEWatch/Views/WatchExerciseReorderView.swift` | Native drag groups, retain buttons |
| `DUNEWatch/Managers/WorkoutManager.swift` | Validated ID move and companion-state remap |
| `DUNEWatchTests/WorkoutManagerReorderTests.swift` | Boundaries, invalid inputs, associated data |

## Implementation Steps

1. Confirm SDK declarations and Apple's [WWDC26 SwiftUI guide](https://developer.apple.com/wwdc26/guides/swiftui/) and [session 271](https://developer.apple.com/videos/play/wwdc2026/271/). SDK has watchOS 27 `.reorderable(collectionID:)` and `ReorderDifference` with sources plus before/end destination.
2. Add pending-only drag groups and map destination to an entry ID.
3. Add manager permutation validation, rebuild every index-keyed value, then publish snapshot and persist once.
4. Add focused tests, inspect diff, then run Watch tests and fresh screen capture when shared host build/simulator access is available.

## Edge Cases

| Case | Handling |
|---|---|
| Completed source or shifted completed slot | Reject |
| Invalid/duplicate source or unknown destination | Reject |
| Destination at end of an earlier pending group | Insert before next completed entry |
| Current exercise moved | Follow original entry UUID |
| Same-order drop | No-op |

## Testing Strategy

Focused `DUNEWatchTests/WorkoutManagerReorderTests.swift` plus Watch simulator drag/accessibility verification and a fresh design-map capture. Build, simulator and capture are pending shared-host availability.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| watchOS drag semantics differ from SDK declaration | Medium | Medium | Run focused Watch UI verification |
| Group boundary drops behave unexpectedly | Medium | Medium | Validate completed fixed positions in manager |

## Confidence Assessment

Medium until the Watch build and simulator gate runs.
