---
source: brainstorm/muscle-map-3d-upgrade
priority: p3
status: done
created: 2026-03-08
updated: 2026-03-09
---

# 해부학 레이어 토글

## 설명

현재 번들된 `muscle_body.usdz` 자산을 기준으로 3D 근육맵에 해부학 레이어 토글을 추가했다.
이번 shipped scope는 `Skin / Muscles / Focus` 3단계이며, `Focus`는 선택 근육만 강하게 읽히도록
비선택 근육을 dim 처리한다.
`xcodebuild test-without-building`로 `DUNETests/MuscleMapDetailViewModelTests`는
`iPhone 17 (iOS 26.3.1)`에서 통과했고, 이후 pre-commit 훅에서 `scripts/build-ios.sh`
전체 빌드도 성공했다. 따라서 TODO를 완료 상태로 전환한다.

## 선행 조건

- USDZ 메시 교체 완료 (MVP)
- 실제 뼈대(스켈레톤) 메시 export는 future asset task로 분리

## 참고

- docs/brainstorms/2026-03-08-muscle-map-3d-upgrade.md
- docs/plans/2026-03-09-muscle-map-anatomy-layer-toggle.md
