---
source: manual
priority: p2
status: done
created: 2026-03-09
updated: 2026-03-16
---

# visionOS window placement runtime validation

## 설명

`VisionWindowPlacementPlanner`와 `defaultWindowPlacement` wiring은 main에 반영됐지만, 실제 simulator/device spatial arrangement를 반복 가능하게 재현하는 경로가 없어서 별도 TODO로 남아 있었다.

이번 배치에서 `VisionWindowPlacementSmokeConfiguration`, `VisionContentView` launch hook, `scripts/vision-window-placement-smoke.sh`를 추가해 simulator에서 condition/activity/sleep/body/chart3d window를 자동으로 열고 screenshot artifact를 남길 수 있게 했다.

## 구현 범위

- `scripts/vision-window-placement-smoke.sh`로 visionOS simulator를 boot/install/launch하고 screenshot artifact를 남긴다.
- condition/activity/sleep/body window가 기본 배치에서 서로 겹치지 않는지 확인한다.
- `chart3d` window가 메인 window 위쪽 anchor 의도대로 열리는지 확인한다.
- 자동화로 재현하기 어려운 no-anchor fallback은 별도 residual TODO로 분리한다.

## 검증 기준

- [x] condition/activity/sleep/body 4개 window를 같은 세션에서 열었을 때 겹침이 없다.
- [x] `chart3d` window가 메인 window 위쪽 relative placement 의도와 어긋나지 않는다.
- [x] 결과를 TODO 또는 docs/solutions/ 문서에 남긴다.
- [x] no-anchor fallback은 `todos/141-ready-p3-vision-window-placement-no-anchor-fallback.md`로 분리했다.

## 검증 결과

- 실행 명령: `scripts/vision-window-placement-smoke.sh`
- artifact: `.tmp/vision-window-placement-smoke/window-placement-20260316-015645.png`
- note: `.tmp/vision-window-placement-smoke/window-placement-20260316-015645.txt`
- 스크린샷에서 메인 dashboard 중앙, activity/body 우측, condition/sleep 좌측, chart3d 상단 배치가 서로 가려지지 않는 것을 확인했다.

## 참고

- `todos/022-done-p2-vision-ux-polish.md`
- `DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift`
- `DUNEVision/App/DUNEVisionApp.swift`
- `DUNEVision/App/VisionContentView.swift`
- `DUNETests/VisionWindowPlacementPlannerTests.swift`
- `docs/solutions/architecture/2026-03-08-visionos-window-placement-planner.md`
- `docs/solutions/testing/2026-03-16-vision-window-placement-smoke.md`
