---
tags: [watch, cardio, machine-cardio, inactivity, stair-climber, active-calories, floors-climbed]
category: general
date: 2026-03-11
severity: important
related_files:
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNEWatchTests/CardioInactivitySignalTests.swift
  - DUNE/DUNE.xcodeproj/project.pbxproj
related_solutions:
  - docs/solutions/healthkit/flights-climbed-tracking.md
  - docs/solutions/healthkit/2026-03-05-watch-cardio-step-count-collection.md
  - docs/solutions/general/2026-03-10-watch-stair-climber-mixed-cardio-fallback.md
---

# Solution: Watch Machine Cardio Inactivity Signal

## Problem

Apple Watch cardio inactivity detection treated only `distance` and `steps` growth as proof of continued movement.
That caused false `No movement detected` prompts during stair climber and other machine-cardio sessions when the user kept exercising with a relatively fixed wrist posture.

### Symptoms

- Stair climber sessions could show inactivity prompts even while the workout was ongoing.
- Machine cardio sessions that advanced `activeCalories` or `floorsClimbed` without obvious wrist-driven step updates were treated as idle.
- The watch inactivity UX felt unreliable for machine-cardio users.

### Root Cause

`WorkoutManager.evaluateCardioInactivity(at:)` used a narrow detector:

- progress = `distance > lastObservedDistance || steps > lastObservedSteps`

This ignored already-available machine-cardio metrics:

- stair workouts expose `floorsClimbed`
- machine-cardio configurations expose `supportsMachineLevel`
- live calorie accumulation (`activeCalories`) continues even when step-style motion is weak

## Solution

Expand the inactivity detector to track an activity-aware baseline and count machine-cardio-specific progress signals.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/Managers/WorkoutManager.swift` | Added observed baselines for floors and calories, plus a pure activity-signal evaluator | Let machine-cardio sessions prove activity without changing UX thresholds |
| `DUNEWatchTests/CardioInactivitySignalTests.swift` | Added regression tests for stair floors fallback, machine-cardio calorie fallback, and unchanged distance-cardio behavior | Prevent future regressions in detector semantics |
| `DUNE/DUNE.xcodeproj/project.pbxproj` | Synced regenerated test target source entries | Ensure the new watch unit test is included in the project |

### Key Code

```swift
if CardioInactivityActivitySignal.hasProgress(
    workoutMode: workoutMode,
    supportsMachineLevel: supportsMachineLevel,
    previous: previousMetrics,
    current: currentMetrics
) {
    lastMotionDate = now
    updateObservedCardioMetricsBaseline()
    clearInactivityPrompt()
    return
}
```

The helper keeps the rule explicit:

- all cardio: `distance` or `steps`
- stair cardio: `floorsClimbed`
- machine cardio: `activeCalories` fallback when `supportsMachineLevel == true`

## Prevention

Future inactivity or auto-end work should treat cardio detection as an activity-type-aware problem, not a single universal motion heuristic.

### Checklist Addition

- [ ] Inactivity detectors check all live metrics relevant to the current cardio secondary unit, not only distance/steps.
- [ ] Machine-cardio changes add regression tests for both positive and negative activity-signal cases.
- [ ] Regenerated `project.pbxproj` changes are reviewed and committed when new watch tests are added.

### Rule Addition (if applicable)

No new `.claude/rules/` entry was added in this change.
The pattern is localized enough to preserve as a solution doc first.

## Lessons Learned

- Watch workout inactivity logic should follow the metrics already emphasized by that workout mode.
- `supportsMachineLevel` is a useful proxy for machine-cardio fallback behavior because it captures `floors` and `timeOnly` secondary-unit sessions.
- `scripts/test-unit.sh` can fail before watch tests run when the iOS suite has unrelated existing failures, so watch-only verification is still necessary when validating new `DUNEWatchTests`.
