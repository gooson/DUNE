---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p3
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNEVision VisionDashboardWindowScene

- Target: `DUNEVision`
- Source: `DUNEVision/Presentation/Dashboard/VisionDashboardWindowScene.swift`
- Entry: `VisionDashboardView` quick action windows
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] deferred lane 진입 조건을 확정한다.

## Entry Route / Target Lane

- Launch target: `DUNEVision`
- Parent lane: `vision-content-screen-today` + `vision-dashboard-root`
- Entry actions:
  - `vision-dashboard-quick-action-condition` → `WindowGroup(id: "dashboard-condition")`
  - `vision-dashboard-quick-action-activity` → `WindowGroup(id: "dashboard-activity")`
  - `vision-dashboard-quick-action-sleep` → `WindowGroup(id: "dashboard-sleep")`
  - `vision-dashboard-quick-action-body` → `WindowGroup(id: "dashboard-body")`
- Per-window root anchors:
  - `vision-dashboard-window-condition-root`
  - `vision-dashboard-window-activity-root`
  - `vision-dashboard-window-sleep-root`
  - `vision-dashboard-window-body-root`

## AXID / Selector Inventory

- Shared helper: `VisionSurfaceAccessibility.dashboardWindow*`
- Stable per-kind selectors:
  - `vision-dashboard-window-{kind}-root`
  - `vision-dashboard-window-{kind}-refresh-button`
  - `vision-dashboard-window-{kind}-hero-card`
  - `vision-dashboard-window-{kind}-detail-section`
  - `vision-dashboard-window-{kind}-loading-state`
  - `vision-dashboard-window-{kind}-unavailable-state`
  - `vision-dashboard-window-{kind}-message-card`
- Activity-only selector:
  - `vision-dashboard-window-activity-recent-sessions`

## State / Assertion Scope

- Window open 성공 기준은 해당 kind의 `root` selector 존재로 판단한다.
- ready 상태에서는 `hero-card` + `detail-section` 존재를 핵심 assert로 사용한다.
- activity window는 ready 상태일 때만 `vision-dashboard-window-activity-recent-sessions`를 추가 assert 할 수 있다.
- `message-card`는 데이터 소스의 보조 메시지가 있는 경우에만 optional lane으로 취급한다.
- metric 값과 recent workout row 텍스트는 실데이터에 따라 달라지므로 container selector까지만 Phase 0 범위에 포함한다.

## Deferred Lane

- 실제 `openWindow(id:)` 호출 성공 여부와 새 window lifecycle 자동화는 visionOS harness 지원 전까지 deferred로 유지한다.
- multi-window placement 충돌 여부는 `todos/107-ready-p2-vision-window-placement-runtime-validation.md`의 수동 시각 검증 범위로 남긴다.
- recent session row 단위 selector, row ordering, deep content assertion은 후속 automation TODO로 분리한다.
