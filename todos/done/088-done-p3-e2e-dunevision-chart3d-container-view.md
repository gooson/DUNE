---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p3
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNEVision Chart3DContainerView

- Target: `DUNEVision`
- Source: `DUNEVision/Presentation/Chart3D/Chart3DContainerView.swift`
- Entry: visionOS 3D Charts window
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] deferred lane 진입 조건을 확정한다.

## Entry Route / Target Lane

- Launch target: `DUNEVision`
- Window: `WindowGroup(id: "chart3d")` — opened via `openWindow(id: "chart3d")`
- Root anchor: `vision-chart3d-root`
- Default lane: Condition scatter chart (`vision-chart3d-condition`)
- Chart type switching via segmented picker (`vision-chart3d-picker`)

## AXID / Selector Inventory

- Stable root AXID:
  - `vision-chart3d-root`
- Stable element AXIDs:
  - `vision-chart3d-picker` — chart type segmented picker
  - `vision-chart3d-condition` — ConditionScatter3DView content
  - `vision-chart3d-training` — TrainingVolume3DView content
- Selector helper: `VisionSurfaceAccessibility.chart3D*`
- Stability test: `VisionSurfaceAccessibilityTests.chart3DIdentifiers()`

## State / Assertion Scope

- Window open 후 기본 선택은 `conditionScatter`이며, `vision-chart3d-condition` 노출을 기준으로 assert 한다.
- Picker를 `trainingVolume`로 전환하면 `vision-chart3d-training` 노출로 assert 한다.
- 각 차트 뷰는 데이터가 없으면 empty placeholder를 렌더한다. Empty placeholder assertion은 content AXID 존재 여부로 판단한다.
- `selectedPeriod` / `weekRange` picker는 차트 내부 상태이므로 root surface assertion 범위에서 제외한다.
- `.simulatorAdvancedMockDataDidChange` notification으로 데이터 갱신 가능. 테스트 시 mock data seeding 후 notification 발행으로 차트 리프레시 검증 가능.

## Deferred Lane

- visionOS XCUITest harness가 생기기 전까지 chart type switching + content 존재 여부까지만 Phase 0 범위로 고정한다.
- 3D Chart 렌더링 검증 (spatial rendering, point/rect mark 정확도)은 snapshot/visual regression strategy 수립 시 처리한다.
- Chart3D API의 accessibility tree 지원이 확인되기 전까지 chart 내부 data point selection/interaction assertion은 보류한다.
- Notes: spatial chart rendering needs a separate smoke/snapshot strategy
