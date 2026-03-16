---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNEWatch WorkoutPreviewView

- Target: `DUNEWatch`
- Source: `DUNEWatch/Views/WorkoutPreviewView.swift`
- Entry: quick-start exercise selection
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: seeded strength preview는 PR smoke에서 닫고, cardio indoor/outdoor split은 selector inventory까지만 고정했다.

## Entry Route / Target Lane

- Root route: `watch-quickstart-exercise-{exerciseID}` 선택
- Target lane anchor:
  - `watch-workout-preview-screen`
  - `watch-workout-preview-strength-list` 또는 `watch-workout-preview-cardio`

## AXID / Selector Inventory

- Stable root/state selectors:
  - `watch-workout-preview-screen`
  - `watch-workout-preview-strength-list`
  - `watch-workout-preview-cardio`
  - `watch-workout-preview-starting`
- Stable CTA selectors:
  - `watch-workout-start-button`
  - `watch-workout-cardio-indoor-button`
  - `watch-workout-cardio-outdoor-button`

## State / Assertion Scope

- seeded single strength fixture에서는 strength list + start button 존재를 핵심 surface로 assert 한다.
- cardio preview는 `watch-workout-preview-cardio`와 indoor/outdoor button 존재까지만 이번 범위에 포함한다.
- actual workout authorization error alert copy와 cardio activity split correctness는 후속 lane으로 남긴다.

## PR Gate / Nightly Lane

- PR smoke:
  - `DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.testStrengthWorkoutCanStartFromQuickStartList`
  - `DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.testStrengthWorkoutShowsInputAndMetricsSurfaces`
- Nightly / deferred:
  - cardio fixture 추가 후 indoor/outdoor split smoke
