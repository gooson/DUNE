---
tags: [ios27, wwdc26, activitykit, widgetkit, dynamic-island, watch-smart-stack]
category: general
date: 2026-10-14
severity: minor
related_files:
  - DUNEWidget/WorkoutRestLiveActivity.swift
  - docs/plans/2026-10-14-rest-live-activity.md
related_solutions: []
---

# Solution: Adaptive rest timer Live Activity layouts

## Problem

The rest timer's compact trailing Dynamic Island view always used the standard countdown style and width. The Lock Screen presentation was also reused on every destination, so it could not be adapted to the smaller Apple Watch Smart Stack activity family.

### Symptoms

- A landscape Dynamic Island may provide limited width to compact content.
- A Lock Screen sized layout is too dense for the Watch Smart Stack's small activity family.

### Root Cause

The widget did not read `isDynamicIslandLimitedInWidth` or `activityFamily`, and it did not declare supplemental support for `.small`.

## Solution

The widget now reads the limited-width environment in a dedicated compact countdown view. It uses smaller, single-line typography and a 48-point maximum width when constrained, while retaining the same countdown interval. The ActivityConfiguration opts into `.small`; its content view switches between the existing Lock Screen layout and a compact exercise/set/countdown presentation. Both presentations use one countdown helper.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWidget/WorkoutRestLiveActivity.swift` | Added constrained countdown and `.small` family layout | Fit iOS 27 landscape Dynamic Island and Watch Smart Stack |
| `docs/design/live-activity-captures/README.md` | Added pending capture matrix | Keep device-specific visual/accessibility evidence explicit |
| `docs/plans/2026-10-14-rest-live-activity.md` | Recorded scope and validation plan | Preserve implementation and runtime validation contract |

### Key Code

```swift
@Environment(\.isDynamicIslandLimitedInWidth) private var isDynamicIslandLimitedInWidth

var body: some View {
    restCountdown(state)
        .font(isDynamicIslandLimitedInWidth ? .caption2 : .body)
        .lineLimit(1)
        .minimumScaleFactor(isDynamicIslandLimitedInWidth ? 0.75 : 1)
        .frame(maxWidth: isDynamicIslandLimitedInWidth ? 48 : 56)
}
```

## Prevention

### Checklist Addition

- [ ] For a Live Activity shared across destinations, check `activityFamily` and declare each supplemental family the content supports.
- [ ] Use `isDynamicIslandLimitedInWidth` for text-bearing compact/minimal presentations; verify icon-only presentations remain legible without unnecessary branches.
- [ ] Keep system-host captures and accessibility verification pending until they are actually performed.

### Rule Addition

No shared rule is needed for this single Live Activity; keep the destination-specific behavior with its widget.

## Validation

- `swiftc -frontend -parse DUNEWidget/WorkoutRestLiveActivity.swift`: passed.
- `git diff --check`: passed.
- `python3 scripts/plan-ui-tests.py --base ff1fd112`: planned full iOS and Watch UI suites and widget target inspection.
- Xcode build and iOS/Watch UI execution: not run because the parent explicitly reserved the shared host/simulator until released.
- iPhone portrait, iPhone landscape limited-width, and Watch Smart Stack captures: pending; see `docs/design/live-activity-captures/README.md`.
- The required integrated phone actual design map is not present in this worktree, so no map screenshot was claimed.

## Lessons Learned

One shared timer renderer prevents the Lock Screen, Watch small family, and Dynamic Island countdowns from drifting to different timing semantics. System presentations still need device-specific evidence; source inspection alone cannot confirm their final layout or VoiceOver output.
