---
source: manual
priority: p3
status: done
created: 2026-03-16
updated: 2026-03-22
---

# visionOS window placement no-anchor fallback verification

## 설명

`todos/107-done-p2-vision-window-placement-runtime-validation.md`에서 primary placement smoke는 자동화로 닫았지만, main anchor가 없는 상태에서 `VisionWindowPlacementPlanner`가 `.utilityPanel` fallback을 실제 공간에서 어떻게 보이게 하는지는 별도 확인이 남아 있다.

기존 smoke script는 main window가 살아 있는 기본 launch 경로만 재현했다. 이번 배치에서 `--vision-window-placement-no-anchor-smoke` 모드를 추가해 settings utility panel을 먼저 열고, main window를 닫은 뒤 fallback 대상 window를 다시 여는 경로를 simulator에서도 반복 가능하게 만들었다.

## 구현 범위

- Apple Vision Pro 실기기 또는 visionOS simulator에서 main window를 닫은 상태를 만든다.
- settings 또는 secondary utility surface에서 dashboard/chart3d window를 다시 열어 `.utilityPanel` fallback을 관찰한다.
- window가 완전히 가려지거나 접근 불가 상태가 되지 않는지 확인한다.
- 결과를 TODO 또는 docs/solutions/ 문서에 남긴다.

## 검증 기준

- [x] main anchor가 없는 상태에서도 fallback window가 접근 가능하다.
- [x] `.utilityPanel` fallback이 과도한 겹침 없이 동작한다.
- [x] verification note 또는 screenshot artifact가 남아 있다.

## 검증 결과

- 실행 명령:
  - `scripts/vision-window-placement-smoke.sh --no-anchor`
  - `scripts/vision-window-placement-smoke.sh --no-anchor --wait-seconds 2.8`
- launch args: `--seed-mock --vision-window-placement-no-anchor-smoke`
- dashboard-focused artifact: `.tmp/vision-window-placement-smoke/window-placement-no-anchor-20260322-022352.png`
- dashboard-focused note: `.tmp/vision-window-placement-smoke/window-placement-no-anchor-20260322-022352.txt`
- chart/settings-focused artifact: `.tmp/vision-window-placement-smoke/window-placement-no-anchor-20260322-022438.png`
- chart/settings-focused note: `.tmp/vision-window-placement-smoke/window-placement-no-anchor-20260322-022438.txt`
- no-anchor smoke가 기존 secondary windows를 먼저 닫고 settings utility panel을 연 뒤 main window를 dismiss하도록 고정돼, simulator 재실행 간 window restoration 영향 없이 fallback lane을 반복 재현할 수 있음을 확인했다.
- 두 smoke artifact를 합쳐 보면 main window가 없는 상태에서도 settings utility surface, `condition` dashboard fallback, `chart3d` fallback progression이 모두 접근 가능한 위치에서 재현되며, 완전한 overlap 때문에 접근 불가 상태로 가는 패턴은 보이지 않았다.

## 참고

- `todos/107-done-p2-vision-window-placement-runtime-validation.md`
- `DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift`
- `scripts/vision-window-placement-smoke.sh`
