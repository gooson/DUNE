---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p3
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNEVision VisionImmersiveExperienceView

- Target: `DUNEVision`
- Source: `DUNEVision/Presentation/Immersive/VisionImmersiveExperienceView.swift`
- Entry: visionOS immersive space open
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] deferred lane 진입 조건을 확정한다.

## Entry Route / Target Lane

- Launch target: `DUNEVision`
- Parent lane: `vision-content-screen-today` + `vision-dashboard-root`
- Entry action: dashboard toolbar `vision-dashboard-toolbar-immersive`
- Space route: `openImmersiveSpace(id: "immersive-recovery")`
- Root anchors:
  - `vision-immersive-root`
  - `vision-immersive-scene`
  - `vision-immersive-header`
  - `vision-immersive-control-panel`

## AXID / Selector Inventory

- Shared helper: `VisionSurfaceAccessibility.immersive*`
- Stable header/action selectors:
  - `vision-immersive-root`
  - `vision-immersive-scene`
  - `vision-immersive-header`
  - `vision-immersive-refresh-button`
  - `vision-immersive-close-button`
  - `vision-immersive-control-panel`
  - `vision-immersive-mode-picker`
- Stable state/action selectors:
  - `vision-immersive-loading-state`
  - `vision-immersive-failed-state`
  - `vision-immersive-ready-panel`
  - `vision-immersive-info-card`
  - `vision-immersive-recovery-action`

## State / Assertion Scope

- immersive lane 진입 성공 기준은 `vision-immersive-root` + `vision-immersive-header` + `vision-immersive-control-panel` 존재다.
- `vision-immersive-loading-state`와 `vision-immersive-failed-state`는 control panel 내부 state assertion anchor로 사용한다.
- ready 상태에서는 `vision-immersive-ready-panel` 존재를 핵심 assert로 사용한다.
- `vision-immersive-recovery-action`은 `Recovery Session` mode에서만 노출되므로 mode-specific optional lane으로 취급한다.
- 실제 surroundings effect, animation timeline, immersive scene visual fidelity는 selector 기반 Phase 0 범위에서 제외한다.

## Deferred Lane

- `openImmersiveSpace` 성공/실패, dismiss lifecycle, foreground/background 전환 automation은 harness 지원 전까지 deferred다.
- segmented picker의 mode 전환 이후 visual/animation regression은 snapshot 또는 manual immersive smoke 전략으로 별도 처리한다.
- recovery session 저장 결과와 mindful minutes persistence 검증은 `VisionImmersiveExperienceViewModel` 테스트 범위로 유지하고, surface TODO에서는 button/container 존재만 다룬다.
