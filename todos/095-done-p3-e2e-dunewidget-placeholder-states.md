---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p3
status: done
created: 2026-03-08
updated: 2026-03-16
---

# E2E Surface: DUNEWidget PlaceholderStates

- Target: `DUNEWidget`
- Source: `DUNEWidget/Views/WidgetPlaceholderView.swift`
- Entry: widget no-data states across families
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] deferred lane 진입 조건을 확정한다.

## Entry Route / Target Lane

- Launch target: `DUNEWidget`
- Widget kind: `WellnessDashboardWidget`
- Family routes:
  - `systemSmall`
  - `systemMedium`
  - `systemLarge`
- Family placeholder lanes:
  - `widget-small-placeholder-lane`
  - `widget-medium-placeholder-lane`
  - `widget-large-placeholder-lane`

## AXID / Selector Inventory

- Family root anchors:
  - `widget-small-root`
  - `widget-medium-root`
  - `widget-large-root`
- Family placeholder lane anchors:
  - `widget-small-placeholder-lane`
  - `widget-medium-placeholder-lane`
  - `widget-large-placeholder-lane`
- Family placeholder element anchors:
  - `widget-small-placeholder-brand`
  - `widget-small-placeholder-icon`
  - `widget-small-placeholder-message`
  - `widget-medium-placeholder-brand`
  - `widget-medium-placeholder-icon`
  - `widget-medium-placeholder-message`
  - `widget-large-placeholder-brand`
  - `widget-large-placeholder-icon`
  - `widget-large-placeholder-message`

## State / Assertion Scope

- shared payload가 아예 없거나 모든 score가 nil인 경우, 각 family는 해당 root + placeholder lane + brand/icon/message anchor 존재를 기준으로 assert 한다.
- placeholder matrix는 copy 값보다 anchor 존재 여부를 source of truth로 삼는다. 즉, locale별 번역 차이와 icon font 차이는 assert 범위에서 제외한다.
- current implementation에서는 placeholder와 stale-data가 같은 visual lane으로 수렴하므로, phase 0에서는 `placeholder lane present`까지만 고정한다.

## Deferred Lane

- stale-data를 placeholder와 분리하는 freshness UX, widget host snapshot golden image, system placeholder rendering 차이는 별도 widget regression lane으로 넘긴다.
- provider가 no-data / stale-data / scored를 3-way로 구분하기 전까지 placeholder matrix는 family별 empty-state contract만 유지한다.
