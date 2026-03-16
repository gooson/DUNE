---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p3
status: done
created: 2026-03-08
updated: 2026-03-16
---

# E2E Surface: DUNEWidget LargeWidgetView

- Target: `DUNEWidget`
- Source: `DUNEWidget/Views/LargeWidgetView.swift`
- Entry: `systemLarge` widget family
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] deferred lane 진입 조건을 확정한다.

## Entry Route / Target Lane

- Launch target: `DUNEWidget`
- Widget kind: `WellnessDashboardWidget`
- Family route: `systemLarge`
- Root anchor: `widget-large-root`
- Default scored lane: `widget-large-scored-lane`
- Placeholder lane: `widget-large-placeholder-lane`

## AXID / Selector Inventory

- Stable root AXID:
  - `widget-large-root`
- Stable scored state anchors:
  - `widget-large-scored-lane`
  - `widget-large-metric-condition`
  - `widget-large-metric-readiness`
  - `widget-large-metric-wellness`
  - `widget-large-summary`
  - `widget-large-footer`
  - `widget-large-updated-at`
- Stable placeholder anchors:
  - `widget-large-placeholder-lane`
  - `widget-large-placeholder-brand`
  - `widget-large-placeholder-icon`
  - `widget-large-placeholder-message`

## State / Assertion Scope

- `entry.hasAnyScore == true`일 때는 `widget-large-root` + `widget-large-scored-lane` + 3개 row metric anchor + footer anchors(`summary`, `updated-at`)를 기준으로 large family scored state를 assert 한다.
- footer는 `widget-large-footer`로 고정하고, lowest metric summary는 `widget-large-summary`, timestamp fallback/실시간 시간은 `widget-large-updated-at`으로 분리해 회귀 범위를 명확히 한다.
- no-data / all-nil payload는 placeholder lane과 placeholder subview anchors까지만 assert 하며, 상세 메시지 copy나 row height 계산값은 범위 밖으로 둔다.

## Deferred Lane

- row height 계산, host snapshot density, locale/timezone 영향을 받는 시간 문자열 자체는 preview/snapshot lane으로 미룬다.
- stale-data와 recent-update freshness badge는 현재 large widget에 전용 visual state가 없으므로 후속 widget regression TODO에서 다룬다.
