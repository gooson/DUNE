---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNEWatch RestTimerView

- Target: `DUNEWatch`
- Source: `DUNEWatch/Views/RestTimerView.swift`
- Entry: active session rest timer flow
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: PR gate는 rest root와 skip CTA까지만 assert 하고, countdown 값/auto-complete/end path는 nightly로 남겼다.

## Entry Route / Target Lane

- Root route: `MetricsView`에서 non-final set completion
- Target lane anchor:
  - `watch-rest-timer-screen`

## AXID / Selector Inventory

- Stable rest selectors:
  - `watch-rest-timer-screen`
  - `watch-rest-timer-countdown`
  - `watch-rest-timer-add-time`
  - `watch-rest-timer-skip`
  - `watch-rest-timer-end`

## State / Assertion Scope

- seeded smoke는 first set completion 뒤 `watch-rest-timer-screen`과 `watch-rest-timer-skip` 존재를 기준으로 lane을 닫는다.
- countdown 텍스트 값과 `+30s` increment effect, end action 후 confirmation path는 후속 범위다.
- return-to-session behavior는 skip handoff까지만 간접 검증한다.

## PR Gate / Nightly Lane

- PR smoke:
  - `DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.testRestTimerAppearsAfterCompletingFirstSet`
- Nightly / deferred:
  - countdown progression
  - `+30s`/`End` interaction lane
