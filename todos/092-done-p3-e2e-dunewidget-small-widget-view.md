---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p3
status: done
created: 2026-03-08
updated: 2026-03-16
---

# E2E Surface: DUNEWidget SmallWidgetView

- Target: `DUNEWidget`
- Source: `DUNEWidget/Views/SmallWidgetView.swift`
- Entry: `systemSmall` widget family
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] deferred lane 진입 조건을 확정한다.

## Entry Route / Target Lane

- Launch target: `DUNEWidget`
- Widget kind: `WellnessDashboardWidget`
- Family route: `systemSmall`
- Root anchor: `widget-small-root`
- Default scored lane: `widget-small-scored-lane`
- Placeholder lane: `widget-small-placeholder-lane`

## AXID / Selector Inventory

- Stable root AXID:
  - `widget-small-root`
- Stable scored state anchors:
  - `widget-small-scored-lane`
  - `widget-small-metric-condition`
  - `widget-small-metric-readiness`
  - `widget-small-metric-wellness`
  - `widget-small-summary`
  - `widget-small-footer`
  - `widget-small-updated-at`
- Stable placeholder anchors:
  - `widget-small-placeholder-lane`
  - `widget-small-placeholder-brand`
  - `widget-small-placeholder-icon`
  - `widget-small-placeholder-message`

## State / Assertion Scope

- `entry.hasAnyScore == true`일 때는 `widget-small-root` + `widget-small-scored-lane` + 3개 metric anchor 존재를 기준으로 assert 한다.
- footer summary는 `widget-small-summary`, timestamp/Today fallback은 `widget-small-updated-at` 하나로 고정해 copy 변경 없이 selector만 안정화한다.
- shared payload가 비었거나 모든 score가 nil이면 `widget-small-root` + `widget-small-placeholder-lane` + placeholder brand/icon/message anchor까지만 assert 한다.

## Deferred Lane

- Widget host snapshot, 실제 홈 화면 렌더링, locale/timezone에 따라 달라지는 `Text(updatedAt, style: .time)` 값 자체는 phase 0 범위에서 제외한다.
- stale-data 전용 visual state는 현재 small widget에 별도 lane이 없으므로 후속 preview/snapshot regression lane에서 처리한다.
