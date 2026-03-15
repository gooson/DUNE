---
source: manual
priority: p3
status: ready
created: 2026-03-16
updated: 2026-03-16
---

# visionOS window placement no-anchor fallback verification

## 설명

`todos/107-done-p2-vision-window-placement-runtime-validation.md`에서 primary placement smoke는 자동화로 닫았지만, main anchor가 없는 상태에서 `VisionWindowPlacementPlanner`가 `.utilityPanel` fallback을 실제 공간에서 어떻게 보이게 하는지는 별도 확인이 남아 있다.

현재 smoke script는 main window가 살아 있는 기본 launch 경로만 재현한다. no-anchor fallback은 main window를 닫거나 settings/secondary surface만 남긴 뒤 다른 window를 다시 여는 절차가 필요하고, simulator보다 실기기에서 더 의미 있는 관찰이 가능하다.

## 구현 범위

- Apple Vision Pro 실기기 또는 visionOS simulator에서 main window를 닫은 상태를 만든다.
- settings 또는 secondary utility surface에서 dashboard/chart3d window를 다시 열어 `.utilityPanel` fallback을 관찰한다.
- window가 완전히 가려지거나 접근 불가 상태가 되지 않는지 확인한다.
- 결과를 TODO 또는 docs/solutions/ 문서에 남긴다.

## 검증 기준

- [ ] main anchor가 없는 상태에서도 fallback window가 접근 가능하다.
- [ ] `.utilityPanel` fallback이 과도한 겹침 없이 동작한다.
- [ ] verification note 또는 screenshot artifact가 남아 있다.

## 참고

- `todos/107-done-p2-vision-window-placement-runtime-validation.md`
- `DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift`
- `scripts/vision-window-placement-smoke.sh`
