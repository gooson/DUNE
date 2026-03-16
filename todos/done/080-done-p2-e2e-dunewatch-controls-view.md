---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNEWatch ControlsView

- Target: `DUNEWatch`
- Source: `DUNEWatch/Views/ControlsView.swift`
- Entry: active session controls page
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: single-exercise seeded smoke는 end/pause surface를 닫고, skip lane은 multi-exercise/nightly 범위로 남긴다.

## Entry Route / Target Lane

- Root route: `SessionPagingView`에서 controls page로 swipe
- Target lane anchor:
  - `watch-session-controls-screen`

## AXID / Selector Inventory

- Stable control selectors:
  - `watch-session-controls-screen`
  - `watch-session-end-button`
  - `watch-session-pause-resume-button`
  - `watch-session-skip-button`

## State / Assertion Scope

- seeded single-exercise flow에서는 end/pause-resume button 존재까지만 PR gate에 포함한다.
- `watch-session-skip-button`은 non-cardio multi-exercise일 때만 노출되므로 optional lane으로 취급한다.
- end confirmation dialog 내부 버튼 동작과 paused/resumed side effect는 이번 surface 범위 밖이다.

## PR Gate / Nightly Lane

- PR smoke:
  - `DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.testControlsSurfaceIsReachableDuringStrengthWorkout`
- Nightly / deferred:
  - multi-exercise skip lane
  - pause/resume state transition and end-confirmation action lane
