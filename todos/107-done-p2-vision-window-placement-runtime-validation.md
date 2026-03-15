---
source: manual
priority: p2
status: ready
created: 2026-03-09
updated: 2026-03-09
---

# visionOS window placement runtime validation

## 설명

`VisionWindowPlacementPlanner`와 `defaultWindowPlacement` wiring은 main에 반영됐지만, 실제 simulator/device spatial arrangement를 눈으로 확인하는 runtime 검증은 아직 별도 TODO로 남아 있다.

현재 저장소에는 전용 visionOS UI harness가 없고, 기존 DUNEVision surface TODO들도 `openWindow(id:)`와 window lifecycle automation을 deferred로 유지하고 있다. 따라서 multi-window placement의 최종 visual QA는 구현 TODO(`022`)와 분리해 추적한다.

## 구현 범위

- visionOS simulator 또는 Apple Vision Pro 실기기에서 dashboard quick action 4개 window를 순서대로 연다.
- condition/activity/sleep/body window가 기본 배치에서 서로 겹치지 않는지 확인한다.
- `chart3d` window가 메인 window 위쪽 anchor 의도대로 열리는지 확인한다.
- main anchor가 없는 fallback 상황에서 `.utilityPanel` 동작이 과도하게 겹치지 않는지 관찰한다.
- 가능하면 screenshot 또는 짧은 verification note를 남긴다.

## 검증 기준

- [ ] condition/activity/sleep/body 4개 window를 같은 세션에서 열었을 때 겹침이 없다.
- [ ] `chart3d` window가 메인 window 위쪽 relative placement 의도와 어긋나지 않는다.
- [ ] fallback case에서도 window가 완전히 가려지거나 접근 불가 상태가 되지 않는다.
- [ ] 결과를 TODO 또는 docs/solutions/ 문서에 남긴다.

## 참고

- `todos/022-done-p2-vision-ux-polish.md`
- `DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift`
- `DUNEVision/App/DUNEVisionApp.swift`
- `DUNETests/VisionWindowPlacementPlannerTests.swift`
- `docs/solutions/architecture/2026-03-08-visionos-window-placement-planner.md`
