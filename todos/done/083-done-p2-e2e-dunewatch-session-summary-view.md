---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNEWatch SessionSummaryView

- Target: `DUNEWatch`
- Source: `DUNEWatch/Views/SessionSummaryView.swift`
- Entry: workout end summary
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: summary root/stats/effort/done selector를 고정했고, post-save reset lane은 nightly로 남겼다.

## Entry Route / Target Lane

- Root route: last set completion 후 `Finish Exercise`
- Target lane anchor:
  - `watch-session-summary-screen`

## AXID / Selector Inventory

- Stable summary selectors:
  - `watch-session-summary-screen`
  - `watch-session-summary-stats`
  - `watch-summary-effort-button`
  - `watch-session-summary-done`
  - `watch-session-summary-breakdown`
  - `watch-session-summary-effort-sheet`
  - `watch-session-summary-effort-done`

## State / Assertion Scope

- seeded single-exercise smoke는 summary root + effort button + done button 존재를 기준으로 lane을 닫는다.
- strength summary에서는 stats grid와 breakdown container가 공존하지만, 값 자체는 seed/HealthKit finalize timing에 따라 달라질 수 있어 selector 존재까지만 본다.
- done tap 후 reset/home 복귀, cardio summary stat variants, effort sheet 조작 depth는 후속 범위다.

## PR Gate / Nightly Lane

- PR smoke:
  - `DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.testSingleExerciseWorkoutCanReachSummarySurface`
- Nightly / deferred:
  - done action 후 dismiss/reset lane
  - cardio summary stat lane
