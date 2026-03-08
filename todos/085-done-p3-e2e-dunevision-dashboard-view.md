---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p3
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNEVision VisionDashboardView

- Target: `DUNEVision`
- Source: `DUNEVision/Presentation/Dashboard/VisionDashboardView.swift`
- Entry: visionOS Today root
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] deferred lane 진입 조건을 확정한다.

## Entry Route / Target Lane

- Launch target: `DUNEVision`
- Root route: launch app → default `Today` lane 진입
- Parent lane anchor: `vision-content-screen-today`
- Dashboard root anchor: `vision-dashboard-root`

## AXID / Selector Inventory

- Stable section anchors:
  - `vision-dashboard-root`
  - `vision-dashboard-condition-section`
  - `vision-dashboard-quick-actions-section`
  - `vision-dashboard-health-metrics-section`
  - `vision-dashboard-mock-data-section` (simulator mock mode available 환경에서만 노출)
- Stable quick action selectors:
  - `vision-dashboard-quick-action-condition`
  - `vision-dashboard-quick-action-activity`
  - `vision-dashboard-quick-action-sleep`
  - `vision-dashboard-quick-action-body`
- Stable toolbar selectors:
  - `vision-dashboard-toolbar-settings`
  - `vision-dashboard-toolbar-immersive`
  - `vision-dashboard-toolbar-volumetric`
  - `vision-dashboard-toolbar-chart3d`
  - `vision-dashboard-toolbar-mock-data` (simulator mock mode available 환경에서만 노출)
- Stable health metric selectors:
  - `vision-dashboard-metric-hrv`
  - `vision-dashboard-metric-rhr`
  - `vision-dashboard-metric-sleep`

## State / Assertion Scope

- `vision-content-screen-today`와 `vision-dashboard-root`가 함께 보이면 dashboard lane 진입 성공으로 간주한다.
- 핵심 회귀 surface는 condition, quick action grid, health metric section 존재 여부로 assert 한다.
- quick action과 toolbar 버튼은 selector 존재까지만 이번 범위에 포함한다.
- metric 값은 실데이터/빈 상태에 따라 달라질 수 있으므로 카드 container identifier만 assert 한다.
- simulator mock 관련 section/button은 simulator availability에 따라 optional lane으로 취급한다.

## Deferred Lane

- quick action이 여는 dedicated window scene 검증은 `todos/087-done-p3-e2e-dunevision-dashboard-window-scene.md`에서 처리했다.
- toolbar `3D Charts` handoff는 `todos/088-ready-p3-e2e-dunevision-chart3d-container-view.md`에서 처리한다.
- toolbar `Spatial Volume` handoff는 `todos/089-done-p3-e2e-dunevision-volumetric-experience-view.md`에서 처리했다.
- toolbar `Immersive Space` open/close verification은 `todos/090-done-p3-e2e-dunevision-immersive-experience-view.md`에서 처리했다.
