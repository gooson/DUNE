---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p3
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNEVision VisionTrainView

- Target: `DUNEVision`
- Source: `DUNEVision/Presentation/Activity/VisionTrainView.swift`
- Entry: visionOS Activity root
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] deferred lane 진입 조건을 확정한다.

## Entry Route / Target Lane

- Launch target: `DUNEVision`
- Root route: launch app → left rail/tab에서 `Activity` 선택
- Parent lane anchor: `vision-content-screen-train`
- Train root anchor: `vision-train-root`
- Hero card anchor: `vision-train-hero-card`

## AXID / Selector Inventory

- Stable root / hero selectors:
  - `vision-train-root`
  - `vision-train-hero-card`
  - `vision-train-open-chart3d-button`
- Stable ready-state card selectors:
  - `vision-train-shareplay-card`
  - `vision-train-voice-entry-card`
  - `vision-train-exercise-guide-card`
  - `vision-train-muscle-map-card`
- Stable state container selectors:
  - `vision-train-loading-state`
  - `vision-train-unavailable-state`
  - `vision-train-failed-state`
- Selector helper: `VisionSurfaceAccessibility.train*`
- Stability test: `VisionSurfaceAccessibilityTests.trainIdentifiers()`

## State / Assertion Scope

- `vision-content-screen-train`와 `vision-train-root`가 함께 보이면 Train lane 진입 성공으로 간주한다.
- 기본 회귀 surface는 hero card + ready 상태의 4개 카드 존재 여부로 assert 한다.
- hero card의 `Open 3D Charts` 버튼은 selector 존재까지만 이번 범위에 포함한다.
- `loading`, `unavailable`, `failed` 상태는 각각 전용 container AXID 존재 여부로 구분한다.
- SharePlay, Voice, Form Guide, Muscle Map 카드 내부의 text field / picker / 3D interaction은 이번 root surface 범위에서 제외한다.

## Deferred Lane

- hero card의 `Open 3D Charts` handoff 검증은 `todos/088-done-p3-e2e-dunevision-chart3d-container-view.md`와 후속 window open harness 전략에서 이어서 다룬다.
- `VisionVoiceWorkoutEntryCard`의 transcript/edit/save interaction assertion은 voice-entry 전용 automation 전략에서 처리한다.
- `VisionExerciseFormGuideView`의 search/guide selection interaction은 guide surface 전용 TODO로 분리한다.
- `VisionMuscleMapExperienceView`의 picker, spatial gesture, entity selection 검증은 3D/snapshot strategy와 함께 별도 surface TODO에서 처리한다.
