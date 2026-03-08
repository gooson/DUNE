---
tags: [visionos, realitykit, usdz, 3d-model, muscle-map, performance]
date: 2026-03-09
category: solution
status: implemented
---

# visionOS USDZ 공유 모델 마이그레이션

## Problem

visionOS volumetric body heatmap (`BodyHeatmapSceneView`)이 geometric primitives(`VisionBodyRig` — box, sphere, cylinder 조합)로 근육을 표현하여 iOS의 USDZ 3D 모델과 시각적 일관성이 없었음. 동일한 `muscle_body.usdz`를 공유해야 했음.

## Solution

### 핵심 전략: MuscleMap3DScene 재사용 + 외부 material 적용

1. **USDZ 번들 포함**: `project.yml`의 DUNEVision target sources에 `Resources/Models/muscle_body.usdz` 추가
2. **Public accessor 추가**: `MuscleMap3DScene`에 3개 read-only accessor 추가 (`muscleModelEntities(for:)`, `muscleEntity(for:)`, `shellModelEntities`)
3. **BodyHeatmapSceneView 리라이트**: `MuscleMap3DScene`을 사용하여 USDZ 로드, 자체 material 적용
4. **VisionBodyRig 삭제**: ~330 lines 제거 (VisionBodyRig enum + VisionBodyPartBlueprint struct)

### 데이터 타입 분리가 중요한 이유

- iOS `MuscleMap3DScene.updateVisuals()`: `MuscleFatigueState` (recovery/volume 모드 지원)
- visionOS `BodyHeatmapSceneView.applyMuscleMaterials()`: `SpatialTrainingSummary.MuscleLoad` (normalizedFatigue 0-1 단순 fatigue)

데이터 타입이 다르므로 `updateVisuals()`를 직접 호출하지 않고, public accessor를 통해 entity에 접근하여 별도 material을 적용함. 이는 의도된 설계.

### RealityView update 분리 패턴 (리뷰에서 발견/수정)

```swift
// BAD: update closure에서 매 프레임 material 재생성
} update: { _ in
    applyHeatmapVisuals()  // drag 중 60fps 호출 → material 할당 폭주
    scene.applyInteractionTransform(yaw: yaw, pitch: pitch, zoomScale: 1)
}

// GOOD: update는 transform만, material은 onChange에서
} update: { _ in
    guard scene.isReady else { return }
    scene.applyInteractionTransform(yaw: yaw, pitch: pitch, zoomScale: 1)
}
.onChange(of: muscleLoads.count) { _, _ in applyMuscleMaterials() }
.onChange(of: selectedMuscle) { _, _ in applyMuscleMaterials() }
```

RealityView의 `update` closure는 ANY `@State` 변경에 반응함. drag 중 `yaw`/`pitch` 변경이 매 프레임 발생하므로, material 적용을 `update`에 넣으면 N_muscles × 60fps material allocation이 발생.

### muscleLookup 캐싱 패턴

```swift
// BAD: computed property → body 재평가마다 Dictionary 생성
private var muscleLookup: [MuscleGroup: MuscleLoad] {
    Dictionary(muscleLoads.map { ... })
}

// GOOD: @State 캐싱 + onChange 무효화
@State private var muscleLookup: [MuscleGroup: MuscleLoad] = [:]
.onChange(of: muscleLoads.count) { _, _ in
    muscleLookup = buildMuscleLookup()
}
```

### 공유 상수 사용 원칙

`MuscleMap3DState`에 정의된 상수를 반드시 사용:
- `defaultYaw`, `defaultPitch` — 초기 카메라 각도
- `rotationSensitivity`, `pitchSensitivity` — 드래그 감도
- `clampedPitch()` — pitch 범위 제한
- `selectedScale` — 선택된 근육 확대 비율

하드코딩 값은 뷰 간 시각적 불일치를 유발함.

## Prevention

- visionOS scene에서 RealityKit entity material을 적용할 때, `RealityView.update` closure가 아닌 `onChange`에서 적용
- 드래그/제스처로 인한 `@State` 변경과 데이터 변경을 분리
- `MuscleMap3DState` 상수를 모든 3D scene 뷰에서 일관되게 사용
- muscleLookup 같은 Dictionary 생성은 computed property가 아닌 cached `@State`로 관리
