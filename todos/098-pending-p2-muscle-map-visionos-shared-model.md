---
source: brainstorm/muscle-map-3d-upgrade
priority: p2
status: pending
created: 2026-03-08
updated: 2026-03-08
---

# visionOS 동일 USDZ 모델 공유

## 설명

현재 visionOS는 geometric primitives(VisionBodyRig)를 사용 중.
iOS와 동일한 USDZ 모델을 RealityView에서 로드하여 통합.

## 선행 조건

- USDZ 메시 교체 완료 (MVP)
- visionOS RealityView에서 USDZ Entity 로드 검증

## 영향 파일

- DUNEVision/Presentation/Volumetric/VisionSpatialSceneSupport.swift
- DUNEVision/Presentation/Activity/VisionMuscleMapExperienceView.swift

## 참고

- docs/brainstorms/2026-03-08-muscle-map-3d-upgrade.md
