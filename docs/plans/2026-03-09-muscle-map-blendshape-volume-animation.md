---
tags: [muscle-map, 3d, volume, animation, realitykit, blendshape]
date: 2026-03-09
category: plan
status: draft
---

# Plan: BlendShape 볼륨 애니메이션

## 요약

볼륨 데이터(주간 세트 수)에 따라 근육 메시가 팽창/수축하는 애니메이션 구현.
현재 USDZ가 USD primitives(capsule/sphere/cylinder)로 구성되어 있어 진짜 BlendShape(morph target)은 불가.
대신 **Entity scale 기반 애니메이션**으로 동일한 시각 효과를 구현.
향후 해부학적 polygon mesh로 교체 시 `BlendShapeWeightsComponent`로 전환 가능.

## 영향 파일

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift` | volume scale 매핑 + 애니메이션 로직 추가 |
| `DUNETests/MuscleMapDetailViewModelTests.swift` | volumeScale 매핑 테스트 추가 |

## 선행 조건 확인

- [x] USDZ 메시 교체 완료 (MVP) — `muscle_body.usdz` 존재
- [ ] Blender 근육군별 BlendShape key — 현재 USD primitives로 진짜 BlendShape 불가 → scale 기반 대체

## 구현 단계

### Step 1: Volume Scale 매핑 함수 추가

`MuscleMap3DState`에 volume intensity → scale factor 매핑 추가.

```swift
static func volumeScale(for intensity: MuscleMap3DVolumeIntensity) -> SIMD3<Float> {
    switch intensity {
    case .none:     SIMD3<Float>(1.0, 1.0, 1.0)
    case .light:    SIMD3<Float>(1.02, 1.01, 1.02)
    case .moderate: SIMD3<Float>(1.05, 1.02, 1.05)
    case .high:     SIMD3<Float>(1.09, 1.03, 1.09)
    case .veryHigh: SIMD3<Float>(1.14, 1.04, 1.14)
    }
}
```

비율 설계:
- X/Z (좌우/전후) 방향이 Y (상하) 보다 더 팽창 → "벌크" 시각 효과
- `.none` = 기본 크기 (1.0)
- `.veryHigh` = 14% 팽창 (미묘하지만 인지 가능)
- 선택된 근육의 기존 `selectedScale` (1.045)과 곱연산

### Step 2: `updateVisuals()`에 volume scale 적용

`MuscleMap3DScene.updateVisuals()` 내 근육 루프에서:
1. `.volume` 모드일 때 intensity에 따른 scale 적용
2. `.recovery` 모드일 때는 기본 scale (1.0)
3. 선택 scale과 volume scale 곱연산
4. `Entity.move(to:relativeTo:duration:)` 로 0.35초 spring 애니메이션

```swift
let volumeScale: SIMD3<Float>
if mode == .volume {
    volumeScale = MuscleMap3DState.volumeScale(for: volumeIntensity)
} else {
    volumeScale = SIMD3<Float>(repeating: 1.0)
}

let selectionScale: Float = isSelected ? MuscleMap3DState.selectedScale : 1.0
let finalScale = volumeScale * selectionScale

// Animate scale change
let targetTransform = Transform(
    scale: finalScale,
    rotation: muscleRoots[muscle]?.orientation ?? simd_quatf(),
    translation: muscleRoots[muscle]?.position ?? .zero
)
muscleRoots[muscle]?.move(to: targetTransform, relativeTo: muscleRoots[muscle]?.parent, duration: 0.35)
```

### Step 3: Cache guard 업데이트

기존 cache guard에 mode 변경이 이미 포함되어 있어 추가 무효화 조건 불필요.
- `lastMuscleMode`가 volume↔recovery 전환을 잡음
- `lastFatigueHash`가 weeklyVolume 변경을 잡음 (이미 hash에 포함)

### Step 4: 테스트

`DUNETests/MuscleMapDetailViewModelTests.swift`에 추가:
- `volumeScale(for:)` 각 intensity → 기대 scale 매핑 검증
- `.none`은 (1,1,1), `.veryHigh`는 X/Z > Y > 1.0 검증
- Selection + volume 복합 scale이 곱셈인지 검증

## 테스트 전략

- 유닛 테스트: `volumeScale(for:)` 매핑의 정확성
- 시각 검증: 시뮬레이터에서 volume 모드 전환 시 근육 팽창 확인

## 리스크 / 엣지 케이스

| 리스크 | 대응 |
|--------|------|
| visionOS `MuscleMap3DScene` 공유 — API 변경 시 호환성 | `updateVisuals()` 기존 시그니처 보존, scale 로직은 내부 |
| `Entity.move()` duration 중 mode 전환 시 애니메이션 중첩 | RealityKit이 새 move()를 이전 것을 덮어씀 — 자연스러운 전환 |
| scale > 1.0 시 인접 근육 메시 겹침 | 최대 14% 팽창이므로 primitive 간격에서 충분 |
| `.recovery` 모드에서 volume scale 잔류 | 모드 전환 시 (1,1,1) 리셋 포함 |

## 대안 비교

| 접근법 | 장점 | 단점 | 선택 |
|--------|------|------|------|
| Entity scale 애니메이션 | 간단, 현재 USDZ 호환 | 균일 팽창 (해부학적X) | **선택** |
| USDZ polygon mesh + BlendShape | 해부학적 변형 | 대규모 스크립트 재작성 필요 | 향후 |
| 색상만 (현재 상태) | 이미 구현됨 | 시각적 임팩트 부족 | 보완 대상 |
