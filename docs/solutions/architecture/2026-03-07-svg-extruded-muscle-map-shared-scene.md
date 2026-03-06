---
tags: [swiftui, realitykit, visionos, svg, muscle-map, shared-scene]
category: architecture
date: 2026-03-07
severity: important
related_files:
  - DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift
  - DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift
  - DUNE/DUNEVision/Presentation/Activity/VisionMuscleMapExperienceView.swift
  - DUNE/DUNEVision/Presentation/Activity/VisionTrainView.swift
  - DUNE/project.yml
related_solutions: []
---

# Solution: SVG-Extruded Muscle Map Shared Across iOS and visionOS

## Problem

기존 3D 근육맵은 primitive 조합 기반 procedural rig라서 2D SVG 근육맵이 이미 가진 실제 경계 정보를 충분히 활용하지 못했다. iPhone에서는 데모 수준으로 보일 수 있었지만, visionOS 공간 인터랙션까지 확장하기에는 근육 형태 정확도와 자산 재사용성이 모두 부족했다.

### Symptoms

- 3D 근육맵이 실제 근육 경계보다 단순한 capsule/box 덩어리로 표현됐다.
- iOS와 visionOS가 공유할 수 있는 실제 3D 근육 자산 파이프라인이 없었다.
- visionOS Train 탭은 공간형 muscle map 대신 placeholder 상태였다.

### Root Cause

문제의 근본 원인은 고품질 근육 경계가 이미 `MuscleMapData.swift`의 SVG 데이터에 있는데도, 3D 표현이 별도의 저해상 procedural rig로 분리되어 있었다는 점이다. 2D atlas와 3D scene이 다른 진실 소스를 쓰면서 fidelity와 유지보수성이 동시에 낮아졌다.

## Solution

2D SVG를 버리지 않고, muscle segmentation atlas로 사용해 RealityKit의 `MeshResource(extruding:)`로 볼륨 메쉬를 생성하도록 구조를 바꿨다. 동시에 iOS `ARView(.nonAR)`와 visionOS `RealityView`가 같은 `MuscleMap3DScene`을 공유하도록 정리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift` | SVG part descriptor, extrusion cache, shared scene, front/back plane handling 추가 | 2D muscle atlas를 실제 3D geometry로 승격하고 플랫폼 간 공유 |
| `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift` | 기존 procedural rig 제거, shared scene 래퍼로 교체 | iOS와 visionOS가 같은 geometry/rendering 로직 사용 |
| `DUNE/DUNEVision/Presentation/Activity/VisionMuscleMapExperienceView.swift` | RealityView 기반 spatial muscle map 추가 | spatial tap, orbit, zoom 포함 Vision Pro용 인터랙션 제공 |
| `DUNE/DUNEVision/Presentation/Activity/VisionTrainView.swift` | Train 탭 placeholder를 muscle map experience로 교체 | visionOS에서 실제 3D 근육맵 진입점 제공 |
| `DUNE/project.yml` | visionOS target에 shared muscle map sources 추가 | shared scene/geometry를 visionOS 빌드에 포함 |
| `DUNETests/MuscleMapDetailViewModelTests.swift` | procedural rig 테스트를 SVG geometry coverage 테스트로 교체 | 새 자산 파이프라인의 coverage와 front/back mapping 검증 |
| `DUNETests/Helpers/URLProtocolStub.swift` 외 2개 테스트 | Swift 6 동시성 안전한 테스트 헬퍼로 정리 | 전체 `DUNETests` 빌드 회복 |

### Key Code

```swift
let mesh = try await MeshResource(
    extruding: MuscleMap3DGeometry.normalizedPath(for: part),
    extrusionOptions: options
)
```

```swift
for entry in groupedEntries[muscle] ?? [] {
    guard let entity = await makeModelEntity(
        for: entry.part,
        descriptor: entry.descriptor
    ) else { continue }
    root.addChild(entity)
}
```

## Prevention

앞으로 근육맵 고도화는 primitive를 손으로 더 쌓는 방식이 아니라, `SVG atlas -> descriptor -> extrusion -> shared scene` 흐름 안에서만 확장하는 편이 안전하다.

### Checklist Addition

- [ ] 근육 형태를 추가/수정할 때 2D SVG와 3D asset truth source가 분리되지 않았는지 확인한다.
- [ ] visionOS 전용 UI에서 helper가 반환하는 `String`이 locale 누락 없이 `String(localized:)` 또는 `LocalizedStringKey`를 사용하는지 확인한다.
- [ ] Swift 6 테스트 스텁에서 공유 mutable state를 캡처할 때 lock/recorder 등 명시적 synchronization을 사용한다.

### Rule Addition (if applicable)

기존 `.claude/rules/localization.md`와 `testing-required.md`로 충분해서 새 규칙 추가는 필요하지 않았다.

## Lessons Learned

2D SVG 근육맵은 버려야 할 레거시가 아니라 3D 근육 자산의 가장 좋은 segmentation source였다. RealityKit extrusion을 사용하면 외부 3D 자산이 없어도 품질을 한 단계 끌어올릴 수 있고, shared scene 구조를 먼저 잡아두면 iOS와 visionOS의 인터랙션 차이만 얇게 분리하면 된다.
