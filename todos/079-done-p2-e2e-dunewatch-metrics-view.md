---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNEWatch MetricsView

- Target: `DUNEWatch`
- Source: `DUNEWatch/Views/MetricsView.swift`
- Entry: active session metrics page
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: initial set input handoff, complete-set CTA, last-set finish action을 selector로 고정했다.

## Entry Route / Target Lane

- Root route: active strength session의 default metrics page
- Target lane anchor:
  - `watch-session-metrics-screen`
  - `watch-session-input-card`

## AXID / Selector Inventory

- Stable metrics selectors:
  - `watch-session-metrics-screen`
  - `watch-session-input-card`
  - `watch-session-complete-set-button`
  - `watch-session-next-exercise`
  - `watch-session-last-set-add-set`
  - `watch-session-last-set-finish`

## State / Assertion Scope

- seeded strength smoke는 input sheet dismiss 후 `watch-session-metrics-screen`와 `watch-session-complete-set-button` 존재를 assert 한다.
- non-final set completion 이후 rest timer handoff는 `todos/081` lane으로 분리한다.
- multi-exercise snapshot에서만 보이는 `watch-session-next-exercise` state는 selector inventory까지만 고정했다.

## PR Gate / Nightly Lane

- PR smoke:
  - `DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.testStrengthWorkoutShowsInputAndMetricsSurfaces`
  - `DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.testRestTimerAppearsAfterCompletingFirstSet`
  - `DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.testSingleExerciseWorkoutCanReachSummarySurface`
- Nightly / deferred:
  - multi-exercise transition card와 `+1 Set` 확장 lane
