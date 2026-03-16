---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p3
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNEVision PlaceholderSurfaces

- Target: `DUNEVision`
- Source: `DUNEVision/App/VisionContentView.swift`
- Entry: visionOS wellness / life placeholder tabs
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] deferred lane 진입 조건을 확정한다.

## Entry Route / Target Lane

- Root route: launch `DUNEVision` → select `Wellness` or `Life` tab from `VisionContentView`
- Wellness lane: `vision-content-screen-wellness`
- Life lane: `vision-content-screen-life`

## AXID / Selector Inventory

- Wellness surface:
  - `vision-content-screen-wellness`
  - `vision-wellness-sleep-section`
  - `vision-wellness-sleep-empty-state`
  - `vision-wellness-body-section`
  - `vision-wellness-body-placeholder`
- Life surface:
  - `vision-content-screen-life`
  - `vision-life-placeholder`

## State / Assertion Scope

- Wellness:
  - 공통 section 존재 여부는 `vision-wellness-sleep-section`, `vision-wellness-body-section`으로 assert 한다.
  - Sleep 데이터가 없을 때는 `vision-wellness-sleep-empty-state`와 copy 존재 여부를 assert 한다.
  - Body 영역은 현재 placeholder surface이므로 `vision-wellness-body-placeholder`와 설명 copy를 회귀 기준으로 삼는다.
- Life:
  - `vision-life-placeholder` 존재 여부와 iPhone handoff copy를 회귀 기준으로 삼는다.

## Deferred Lane

- HealthKit seeded/mock 조합에 따른 Wellness 데이터 분기 전수 검증은 visionOS harness 구축 후 확장한다.
- placeholder surface가 실데이터 기반 편집/상세 화면으로 대체되면 현재 inventory를 축소하고 새 surface TODO로 분리한다.
