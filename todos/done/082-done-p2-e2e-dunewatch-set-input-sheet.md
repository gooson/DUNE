---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNEWatch SetInputSheet

- Target: `DUNEWatch`
- Source: `DUNEWatch/Views/SetInputSheet.swift`
- Entry: `MetricsView` set input flow
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: initial sheet dismiss lane은 PR smoke에 포함했고, previous set history push lane은 nightly로 남겼다.

## Entry Route / Target Lane

- Root route:
  - `MetricsView` 첫 진입 시 auto-present
  - rest timer skip 후 handoff 재진입
- Target lane anchor:
  - `watch-set-input-screen`
  - `watch-set-input-previous-sets-screen`

## AXID / Selector Inventory

- Stable sheet selectors:
  - `watch-set-input-screen`
  - `watch-set-input-done`
  - `watch-set-input-previous-sets-button`
  - `watch-set-input-previous-sets-screen`
  - `watch-set-input-previous-sets-back`
  - `watch-set-input-weight-decrement`
  - `watch-set-input-weight-increment`
  - `watch-set-input-reps-decrement`
  - `watch-set-input-reps-increment`
  - `watch-set-input-rpe`
- Dynamic history row selector:
  - `watch-set-input-previous-set-{setNumber}`

## State / Assertion Scope

- PR smoke는 initial auto-present sheet가 열리고 `watch-set-input-rpe` + `watch-set-input-done`이 함께 보이는 lane만 확인한다.
- previous set history button/screen은 completed set가 누적된 뒤에만 의미가 있으므로 selector inventory까지만 고정한다.
- weight/reps clamp semantics는 UI surface 범위 밖이며 policy/unit test lane이 담당한다.

## PR Gate / Nightly Lane

- PR smoke:
  - `DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.testStrengthWorkoutShowsInputAndMetricsSurfaces`
- Nightly / deferred:
  - previous set history push lane
  - weight/reps stepper interaction lane
