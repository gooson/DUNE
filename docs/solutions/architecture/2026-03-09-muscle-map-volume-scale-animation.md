---
tags: [muscle-map, 3d, volume, animation, realitykit, entity-scale]
date: 2026-03-09
category: solution
status: implemented
---

# Entity Scale 기반 근육 볼륨 애니메이션

## Problem

근육 맵 3D 뷰에서 주간 트레이닝 볼륨(세트 수)에 따라 근육이 시각적으로 팽창/수축하는 효과가 필요했다. 이상적으로는 BlendShape(morph target)를 사용하지만, 현재 USDZ가 USD primitives(capsule/sphere/cylinder)로 구성되어 있어 BlendShape target을 베이킹할 수 없었다.

## Solution

`Entity.move(to:relativeTo:duration:)` API로 비균일(non-uniform) scale 애니메이션을 적용.

### 핵심 설계

1. **비균일 scale**: X/Z(좌우/전후)가 Y(상하)보다 더 팽창하여 "벌크" 시각 효과 구현
2. **5단계 매핑**: `MuscleMap3DVolumeIntensity` enum의 5개 level → scale factor 매핑
3. **곱셈 합성**: volume scale × selection scale → 최종 scale
4. **Spring 애니메이션**: 0.35초 duration으로 자연스러운 전환

### Scale 매핑 테이블

| Intensity | X/Z | Y |
|-----------|-----|---|
| none | 1.00 | 1.00 |
| light | 1.02 | 1.01 |
| moderate | 1.05 | 1.02 |
| high | 1.09 | 1.03 |
| veryHigh | 1.14 | 1.04 |

### 코드 패턴

```swift
// Static mapping function
static func volumeScale(for intensity: MuscleMap3DVolumeIntensity) -> SIMD3<Float> {
    switch intensity {
    case .none:     SIMD3<Float>(1.0, 1.0, 1.0)
    case .veryHigh: SIMD3<Float>(1.14, 1.04, 1.14)
    // ...
    }
}

// Animated application
let target = Transform(scale: finalScale, rotation: root.orientation, translation: root.position)
root.move(to: target, relativeTo: root.parent, duration: 0.35)
```

## Prevention

- **USD primitives ≠ polygon mesh**: BlendShape(`BlendShapeWeightsComponent`)는 polygon mesh에 baked morph target이 필요. Capsule/Sphere/Cylinder에는 적용 불가.
- **Entity.move() 중첩**: RealityKit이 새 `move()`를 이전 것에 덮어씌우므로 모드 전환 시 자연스러운 전환이 가능.
- **향후 polygon mesh USDZ 도입 시**: `volumeScale()` → `BlendShapeWeightsComponent` 기반 구현으로 전환. Entity scale 방식은 균일 팽창이므로 해부학적 변형이 필요하면 교체 필요.

## Affected Files

| 파일 | 변경 |
|------|------|
| `MuscleMap3DScene.swift` | `volumeScale(for:)` + `updateVisuals()` animated scale |
| `MuscleMap3DStateTests.swift` | 매핑 정확성, 단조성, 곱셈 합성 테스트 |
