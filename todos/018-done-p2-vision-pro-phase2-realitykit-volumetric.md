---
source: brainstorm/vision-pro-features
priority: p2
status: done
created: 2026-03-05
updated: 2026-03-07
---

# Vision Pro Phase 2: RealityKit Volumetric 모델

## 완료 메모

- `DUNEVisionApp`에 volumetric `WindowGroup(id: "spatial-volume")`를 추가했다.
- Heart Rate Orb, Training Volume Blocks, Body Heatmap 3개 RealityKit 장면을 구현했다.
- 운동 데이터는 `SpatialTrainingAnalyzer`가 HealthKit workout summary를 pseudo load + fatigue summary로 변환해 공급한다.
- 3D body heatmap은 외부 USDZ 자산 대신 procedural RealityKit body rig로 구현해 target 의존성을 줄였다.
- `SpatialTrainingAnalyzerTests`와 Swift 6 동시성 테스트 헬퍼 보강으로 테스트 게이트를 복구했다.

## 목표
RealityKit을 활용한 3D 오브젝트 뷰 구현.

## 범위

### Heart Rate Orb (B3)
- 실시간 심박수를 반영하는 맥동 3D 오브
- BPM에 따라 크기/색상/맥동 속도 변화
- Volumetric 윈도우에 상시 표시

### Training Volume Blocks (B4)
- 근육그룹별 훈련 볼륨을 3D 블록으로 시각화
- 주간 진행 상황을 물리적 "건물"처럼 표현

### 3D Body Composition Model (B1)
- USDZ 인체 모델 위에 근육그룹별 훈련 히트맵
- 360도 회전 가능
- 기존 SVG body diagram의 3D 업그레이드

## 기술 요구사항
- RealityKit / RealityView
- USDZ 모델 소싱 (Apple 제공 or 커스텀)
- ShaderGraph 커스텀 (히트맵 색상 매핑)
- Model3D for simple objects

## 참고
- `docs/brainstorms/2026-03-05-vision-pro-features.md` Category B
