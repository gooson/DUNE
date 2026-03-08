---
tags: [visionos, usdz, realitykit, muscle-map, 3d, volumetric]
date: 2026-03-09
category: plan
status: draft
---

# visionOS 동일 USDZ 모델 공유

## TODO 참조

- `todos/098-pending-p2-muscle-map-visionos-shared-model.md`

## Problem Statement

visionOS의 `BodyHeatmapSceneView` (volumetric scene)가 `VisionBodyRig`의 geometric primitives (box/sphere/cylinder)를 사용하여 인체 근육 모델을 렌더링하고 있다. iOS는 이미 USDZ 기반 `MuscleMap3DScene`을 사용하므로, visionOS도 동일한 USDZ 모델을 사용하여 시각적 일관성을 확보해야 한다.

## 현재 상태

| 구분 | iOS | visionOS Flat View | visionOS Volumetric |
|------|-----|-------------------|---------------------|
| Scene | `MuscleMap3DScene` (USDZ) | `MuscleMap3DScene` (USDZ) | `VisionBodyRig` (primitives) |
| 파일 | `MuscleMap3DView.swift` | `VisionMuscleMapExperienceView.swift` | `BodyHeatmapSceneView.swift` |
| 데이터 | `MuscleFatigueState` | `MuscleFatigueState` | `SpatialTrainingSummary.MuscleLoad` |
| 색상 | `MuscleMap3DScene.resolvedColor` | `MuscleMap3DScene.resolvedColor` | `VisionSpatialPalette.fatigueColor` |

## 영향 파일

| 파일 | 변경 내용 | 위험도 |
|------|----------|--------|
| `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift` | public accessor 추가 (muscleModelEntities, bodyRoot) | Low |
| `DUNEVision/Presentation/Volumetric/BodyHeatmapSceneView.swift` | VisionBodyRig → MuscleMap3DScene 교체 | Medium |
| `DUNEVision/Presentation/Volumetric/VisionSpatialSceneSupport.swift` | VisionBodyRig + VisionBodyPartBlueprint 제거 | Low |
| `DUNE/project.yml` | DUNEVision에 muscle_body.usdz 리소스 추가 | Low |

## Implementation Steps

### Step 1: project.yml에 USDZ 리소스 추가

DUNEVision 타겟 sources에 muscle_body.usdz 경로 추가:
```yaml
- path: Resources/Models/muscle_body.usdz
```

**Verification**: `scripts/lib/regen-project.sh` 실행 후 DUNEVision 타겟에 리소스가 포함되는지 확인

### Step 2: MuscleMap3DScene에 public accessor 추가

`BodyHeatmapSceneView`가 entity에 직접 material을 적용할 수 있도록 accessor 추가:

```swift
// 특정 근육의 ModelEntity 배열 반환
func muscleModelEntities(for muscle: MuscleGroup) -> [ModelEntity] {
    muscleModels[muscle] ?? []
}

// 특정 근육의 root Entity 반환
func muscleEntity(for muscle: MuscleGroup) -> Entity? {
    muscleRoots[muscle]
}

// shell ModelEntity 배열 반환
var shellModelEntities: [ModelEntity] { shellModels }
```

**Verification**: 기존 iOS/visionOS flat view에 영향 없음 확인 (read-only accessor)

### Step 3: BodyHeatmapSceneView 재작성

`VisionBodyRig` 대신 `MuscleMap3DScene`을 사용하도록 변경:

- `@State private var scene = MuscleMap3DScene()` 추가
- `RealityView` make closure: `content.add(scene.anchor)` + `await scene.prepareIfNeeded()`
- `RealityView` update closure: 새 accessor를 사용하여 `VisionSpatialPalette.fatigueColor` 기반 material 적용
- rotation은 `scene.applyInteractionTransform(yaw:pitch:zoomScale:)` 활용 (zoomScale=1)

**데이터 타입 브릿지**: `SpatialTrainingSummary.MuscleLoad.normalizedFatigue`는 0-1 범위 double이므로 `VisionSpatialPalette.fatigueColor`에 직접 전달 가능. 기존 로직과 동일.

**Verification**: visionOS volumetric scene에서 USDZ 모델이 렌더링되는지 확인

### Step 4: VisionBodyRig + VisionBodyPartBlueprint 제거

`VisionSpatialSceneSupport.swift`에서:
- `VisionBodyRig` enum 전체 제거 (~330줄)
- `VisionBodyPartBlueprint` struct 제거 (~13줄)
- `VisionSpatialPalette` 유지 (다른 곳에서 사용)
- `SpatialTrainingSummary.MuscleLoad` extension 유지

**Verification**: 빌드 성공 + VisionBodyRig 참조 0건

## 테스트 전략

### 자동 테스트
- `MuscleMap3DScene` accessor 추가는 기존 동작 불변 → 기존 테스트 통과 확인
- 빌드 성공 확인 (iOS + visionOS)

### 수동 검증
- visionOS 시뮬레이터에서 volumetric body heatmap 표시 확인
- 근육 색상이 fatigue 수준에 따라 변하는지 확인
- 드래그 회전이 동작하는지 확인

## 리스크 & Edge Cases

1. **USDZ 번들 포함 누락**: project.yml에 리소스를 추가하지 않으면 visionOS에서 파일 로드 실패 → Step 1에서 해결
2. **entity naming 불일치**: VisionBodyRig는 `muscle.{rawValue}` 사용, USDZ는 `muscle_{rawValue}` → MuscleMap3DScene이 이미 올바른 naming 처리
3. **bodyRoot position 차이**: MuscleMap3DScene의 `[0, -0.05, -1.25]` vs VisionBodyRig의 `[0, -0.05, -1.05]` → volumetric에서 z 오프셋이 다를 수 있음. scene의 bodyRoot position을 조정하거나, BodyHeatmapSceneView에서 anchor position을 오버라이드
4. **shell 색상 차이**: MuscleMap3DScene은 colorScheme 기반, VisionBodyRig는 고정 0.07 alpha white → visionOS volumetric은 항상 dark이므로 MuscleMap3DScene의 dark 경로 (white 0.05 alpha) 사용됨. 약간 다르지만 허용 범위

## 대안 비교

| 접근법 | 장점 | 단점 |
|--------|------|------|
| **A. MuscleMap3DScene 재사용 + accessor** (선택) | 코드 재사용 극대화, 단일 USDZ 로딩 | accessor 추가 필요 |
| B. 별도 VisionMuscleMap3DScene 생성 | 독립적 커스터마이징 | USDZ 로딩 로직 중복 |
| C. VisionBodyRig에 USDZ 로딩 추가 | 기존 구조 유지 | 두 개의 scene class 유지 비용 |

접근법 A 선택 근거: `VisionMuscleMapExperienceView`가 이미 `MuscleMap3DScene`을 성공적으로 사용 중이므로 동일 패턴 적용이 가장 안전.
