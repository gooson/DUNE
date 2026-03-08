---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p3
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNEVision VisionContentView

- Target: `DUNEVision`
- Source: `DUNEVision/App/VisionContentView.swift`
- Entry: visionOS app root
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] deferred lane 진입 조건을 확정한다.

## Entry Route / Target Lane

- Launch target: `DUNEVision`
- Root anchor: `vision-content-root`
- Default lane: `vision-content-screen-today`
- Section lanes:
  - Today: `vision-content-screen-today`
  - Activity: `vision-content-screen-train`
  - Wellness: `vision-content-screen-wellness`
  - Life: `vision-content-screen-life`

## AXID / Selector Inventory

- Stable root AXID:
  - `vision-content-root`
- Stable assertion anchors:
  - `vision-content-screen-today`
  - `vision-content-screen-train`
  - `vision-content-screen-wellness`
  - `vision-content-screen-life`
- Stable tab selectors:
  - `Today`
  - `Activity`
  - `Wellness`
  - `Life`

## State / Assertion Scope

- App launch 후 기본 선택 lane은 `Today`이며 `vision-content-screen-today` 노출을 기준으로 assert 한다.
- `Activity`, `Wellness`, `Life` 탭은 고정 영어 tab label로 전환하고, 각 lane screen ID로 active state를 assert 한다.
- window open, immersive open, volumetric handoff 자체는 root surface 범위에서 assert 하지 않는다. 이들은 전용 deferred surface TODO로 분리한다.

## Deferred Lane

- visionOS XCUITest harness가 생기기 전까지 tab switching + root lane 존재 여부까지만 Phase 0 범위로 고정한다.
- multi-window open verification은 `todos/087-done-p3-e2e-dunevision-dashboard-window-scene.md`에서 처리했다.
- volumetric / immersive verification은 `todos/089-done-p3-e2e-dunevision-volumetric-experience-view.md`, `todos/090-done-p3-e2e-dunevision-immersive-experience-view.md`에서 처리했다.
