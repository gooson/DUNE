---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p3
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNEVision VisionVolumetricExperienceView

- Target: `DUNEVision`
- Source: `DUNEVision/Presentation/Volumetric/VisionVolumetricExperienceView.swift`
- Entry: visionOS spatial volume window
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] deferred lane 진입 조건을 확정한다.

## Entry Route / Target Lane

- Launch target: `DUNEVision`
- Parent lane: `vision-content-screen-today` + `vision-dashboard-root`
- Entry action: dashboard toolbar `vision-dashboard-toolbar-volumetric`
- Window route: `WindowGroup(id: "spatial-volume")`
- Root anchor: `vision-volumetric-root`
- Default selected scene: `heartRateOrb` → `vision-volumetric-scene-heartRateOrb`

## AXID / Selector Inventory

- Shared helper: `VisionSurfaceAccessibility.volumetric*`
- Stable root/state selectors:
  - `vision-volumetric-root`
  - `vision-volumetric-loading-state`
  - `vision-volumetric-message-state`
  - `vision-volumetric-retry-button`
- Stable ornament/stage selectors:
  - `vision-volumetric-picker-ornament`
  - `vision-volumetric-scene-picker`
  - `vision-volumetric-trailing-ornament`
  - `vision-volumetric-scene-stage`
  - `vision-volumetric-metric-strip`
  - `vision-volumetric-muscle-strip`
- Stable scene selectors:
  - `vision-volumetric-scene-heartRateOrb`
  - `vision-volumetric-scene-trainingBlocks`
  - `vision-volumetric-scene-bodyHeatmap`

## State / Assertion Scope

- Window open 후 `vision-volumetric-root`와 `vision-volumetric-scene-picker`가 보이면 기본 lane 진입 성공으로 간주한다.
- ready 상태 핵심 회귀 범위는 `scene-stage` + 선택된 scene selector 존재 여부다.
- trailing ornament는 ready 상태에서만 노출되므로 optional이 아니라 ready-state assertion 범위로 본다.
- `vision-volumetric-muscle-strip`는 `trainingBlocks` 또는 `bodyHeatmap` + featured muscle data가 있을 때만 노출되므로 optional lane으로 취급한다.
- 실제 3D geometry 내용, 회전/확대 gesture, scene 내부 selection은 Phase 0 범위에서 제외한다.

## Deferred Lane

- toolbar 버튼 탭 이후 실제 volumetric window open/close automation은 visionOS harness 지원 전까지 deferred로 유지한다.
- scene 전환 후 RealityKit 렌더링 품질과 gesture interaction 회귀는 별도 smoke/snapshot 전략이 생길 때 처리한다.
- muscle button 단위 selector와 deep interaction assertion은 후속 TODO로 남긴다.
