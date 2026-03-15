---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p3
status: done
created: 2026-03-08
updated: 2026-03-16
---

# E2E Surface: DUNEWidget MediumWidgetView

- Target: `DUNEWidget`
- Source: `DUNEWidget/Views/MediumWidgetView.swift`
- Entry: `systemMedium` widget family
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] deferred lane 진입 조건을 확정한다.

## Entry Route / Target Lane

- Launch target: `DUNEWidget`
- Widget kind: `WellnessDashboardWidget`
- Family route: `systemMedium`
- Root anchor: `widget-medium-root`
- Default scored lane: `widget-medium-scored-lane`
- Placeholder lane: `widget-medium-placeholder-lane`

## AXID / Selector Inventory

- Stable root AXID:
  - `widget-medium-root`
- Stable scored state anchors:
  - `widget-medium-scored-lane`
  - `widget-medium-metric-condition`
  - `widget-medium-metric-readiness`
  - `widget-medium-metric-wellness`
- Stable placeholder anchors:
  - `widget-medium-placeholder-lane`
  - `widget-medium-placeholder-brand`
  - `widget-medium-placeholder-icon`
  - `widget-medium-placeholder-message`

## State / Assertion Scope

- `entry.hasAnyScore == true`일 때는 `widget-medium-root` + `widget-medium-scored-lane` + 3개 tile metric anchor를 기준으로 medium family scored state를 assert 한다.
- medium family는 footer/timestamp lane이 없으므로 state 구분을 metric tile anchor presence로만 고정한다.
- shared payload가 비었거나 모든 score가 nil이면 placeholder lane과 3개 placeholder subview anchor만 assert 하고, 표시 copy나 tile spacing 값 자체는 assert 하지 않는다.

## Deferred Lane

- medium tile spacing, Dynamic Type, host preview clipping은 snapshot/preview lane으로 넘긴다.
- stale-data 분기와 timeline refresh cadence는 provider-level regression 범위로 남기고 phase 0 surface contract에는 포함하지 않는다.
