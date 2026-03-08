---
tags: [realitykit, realityview, arview, warning, muscle-map, ios, simulator]
date: 2026-03-09
category: general
status: implemented
severity: important
related_files:
  - DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift
  - DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift
  - DUNE/Presentation/Activity/Components/MuscleRecoveryMapView.swift
  - DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-08-usdz-muscle-map-3d-migration.md
  - docs/solutions/testing/2026-03-09-e2e-musclemap-3d-simulator-safe-testing.md
---

# Solution: Muscle Map 3D ARView Warning Fix

## Problem

iOS 근육맵 3D 화면 진입 시 콘솔에 아래 RealityKit/AR 내부 warning이 반복 출력됐다.

### Symptoms

- `asset string 'engine:throttleGhosted.rematerial' parse failed`
- `Video texture allocator is not initialized.`
- `Could not resolve material name 'engine:BuiltinRenderGraphResources/AR/...'`
- `TBB Global TLS count is not == 1`

### Root Cause

`MuscleMap3DView`는 pure virtual 3D scene임에도 `ARView(cameraMode: .nonAR)`를 사용하고 있었다. `.nonAR`라도 iOS의 `ARView` 경로는 내부적으로 AR render graph/resource lookup을 일부 깨울 수 있고, 현재 로그는 그 엔진 내부 자원 해석 실패/초기화 warning으로 나타났다.

이 화면은 iOS 앱에서 유일한 `ARView` 사용처였고, 같은 shared `MuscleMap3DScene`은 visionOS에서 이미 `RealityView`로 동작하고 있었다. 따라서 warning을 억지로 숨기기보다 renderer 경로 자체를 `RealityView`로 바꾸는 것이 맞았다.

## Solution

iOS 3D viewer를 `UIViewRepresentable + ARView`에서 SwiftUI `RealityView` 기반 구현으로 교체했다. shared scene, yaw/pitch/zoom state, tap selection, reset 동작은 유지하고, `ARView` 전용 install helper는 제거했다. 동시에 coordinate tap에 의존하던 UI smoke는 muscle button AXID를 사용하도록 안정화했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift` | iOS 3D viewer를 `RealityView` 기반 SwiftUI view로 교체 | `ARView` renderer path 제거로 warning root path 차단 |
| `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift` | `ARView` 전용 install helper 삭제 | shared scene를 `RealityView` add path로 단순화 |
| `DUNE/Presentation/Activity/Components/MuscleRecoveryMapView.swift` | muscle part button에 stable AXID 추가 | 좌표 기반 UI test flake 제거 |
| `DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift` | detail body map coordinate tap 대신 `musclemap-body-front-chest` 탭 사용 | device-size variance 없이 3D 진입 검증 |

### Key Code

```swift
RealityView { content in
    if scene.anchor.parent == nil {
        content.add(scene.anchor)
    }

    await scene.prepareIfNeeded()
    hasLoadedScene = true
    refreshScene()
} update: { _ in
    refreshScene()
}
```

## Prevention

### Checklist Addition

- [ ] pure virtual RealityKit 화면이면 `ARView`보다 `RealityView`를 먼저 검토했는가
- [ ] body-map/diagram 같은 tappable surface에 stable AXID를 제공했는가
- [ ] device-size에 민감한 UI test에서 coordinate tap 대신 semantic selector를 우선 사용했는가

### Rule Addition (if applicable)

새 rule 파일까지는 필요 없지만, native 3D surface 검증 시 "renderer choice"와 "test selector stability"를 함께 보는 습관이 필요하다.

## Lessons Learned

`ARView(.nonAR)`는 겉으로는 pure 3D처럼 보여도 내부 경로까지 완전히 non-AR이라는 보장은 없다. warning이 엔진 내부 자원 이름/AR render graph를 가리키면 개별 로그를 suppress하려 하지 말고, 해당 화면이 실제로 AR renderer를 써야 하는지부터 다시 보는 편이 빠르다.
