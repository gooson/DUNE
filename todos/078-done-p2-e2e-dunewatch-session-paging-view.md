---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNEWatch SessionPagingView

- Target: `DUNEWatch`
- Source: `DUNEWatch/Views/SessionPagingView.swift`
- Entry: `WorkoutPreviewView` start action
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: strength paging의 metrics ↔ controls lane은 smoke helper로 고정했고, cardio horizontal tab order는 deferred lane으로 남겼다.

## Entry Route / Target Lane

- Root route: `WorkoutPreviewView`의 start action 성공
- Target lane anchor:
  - `watch-session-paging-root`
  - `watch-session-paging-strength` 또는 `watch-session-paging-cardio`

## AXID / Selector Inventory

- Stable paging selectors:
  - `watch-session-paging-root`
  - `watch-session-paging-strength`
  - `watch-session-paging-cardio`
- Child page selectors reused from subviews:
  - `watch-session-metrics-screen`
  - `watch-session-controls-screen`

## State / Assertion Scope

- seeded strength session은 `watch-session-paging-root` + `watch-session-paging-strength` 존재를 기본 진입 조건으로 삼는다.
- controls lane 이동은 `watch-session-controls-screen` 도달로 판정한다.
- cardio mainMetrics/hrZone/secondary/nowPlaying 개별 page assert는 이번 범위에서 제외한다.

## PR Gate / Nightly Lane

- PR smoke:
  - `DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.testStrengthWorkoutShowsInputAndMetricsSurfaces`
  - `DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.testControlsSurfaceIsReachableDuringStrengthWorkout`
- Nightly / deferred:
  - cardio horizontal paging lane와 inactivity alert lane
