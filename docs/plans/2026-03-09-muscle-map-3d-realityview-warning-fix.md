---
topic: muscle-map-3d-realityview-warning-fix
date: 2026-03-09
status: approved
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-08-usdz-muscle-map-3d-migration.md
  - docs/solutions/testing/2026-03-09-e2e-musclemap-3d-simulator-safe-testing.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-muscle-map-3d-upgrade.md
---

# Implementation Plan: Muscle Map 3D RealityView Warning Fix

## Context

iOS 근육맵 3D 화면은 `ARView(cameraMode: .nonAR)`를 사용해 순수 가상 씬을 렌더링하고 있다. 그러나 실제 실행 시 RealityKit/AR 내부 render graph가 함께 초기화되면서 `engine:throttleGhosted.rematerial`, `BuiltinRenderGraphResources/AR/*`, `Video texture allocator is not initialized` 같은 콘솔 워닝이 반복 출력된다.

현재 코드베이스에서 iOS 앱 쪽 `ARView` 사용처는 이 화면이 유일하다. 반면 같은 `MuscleMap3DScene`을 visionOS에서는 `RealityView`로 안정적으로 사용하고 있다. 따라서 iOS도 `RealityView` 기반 virtual renderer로 정리하는 것이 가장 직접적인 근본 원인 수정 경로다.

## Requirements

### Functional

- Muscle Map 3D 화면이 기존과 동일하게 로드되어야 한다.
- 근육 선택, 회전, 확대/축소, reset 동작이 유지되어야 한다.
- 기존 accessibility identifier와 UI test contract는 유지되어야 한다.

### Non-functional

- RealityKit/AR internal warning 발생 경로를 제거해야 한다.
- iOS 전용 구현은 기존 shared `MuscleMap3DScene`를 최대한 재사용해야 한다.
- 변경은 근육맵 3D surface로 제한하고 다른 RealityKit 화면에는 영향을 주지 않아야 한다.

## Approach

iOS `MuscleMap3DViewer`를 `UIViewRepresentable + ARView`에서 SwiftUI `RealityView` 기반 구현으로 교체한다. 기존 `MuscleMap3DScene`의 anchor, 색상 업데이트, interaction transform 로직은 유지하고, 화면 상태와 gesture는 SwiftUI 쪽에서 직접 관리한다.

핵심은 AR session-like renderer를 깨우는 `ARView`를 제거하는 것이다. `RealityView`는 virtual content path를 직접 사용할 수 있어, 현재 보이는 AR render graph resource warning을 생성할 가능성이 더 낮다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `ARView` 유지 + 추가 설정 조정 | 코드 변경이 작을 수 있음 | 어떤 설정이 warning을 실제로 멈추는지 근거가 약함. 내부 엔진 로그를 앱 레벨에서 완전히 제어하기 어려움 | Rejected |
| iOS도 `RealityView`로 전환 | warning root path 자체를 제거, shared scene 재사용 가능 | gesture/entity targeting API 차이 확인 필요 | Selected |
| 3D surface를 정적/저기능 뷰로 축소 | warning 제거는 쉬울 수 있음 | 3D interaction regression 발생 | Rejected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift` | modify | `MuscleMap3DViewer`를 `RealityView` 기반 iOS renderer로 교체 |
| `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift` | modify | ARView 전용 설치 helper 정리 또는 RealityView 공용 경로에 맞게 정돈 |
| `DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift` | verify / optional modify | 기존 AXID contract가 유지되는지 확인. 필요 시 surface assertion 보강 |
| `docs/plans/2026-03-09-muscle-map-3d-realityview-warning-fix.md` | add | 이번 변경 계획 문서 |
| `docs/solutions/general/2026-03-09-muscle-map-3d-arview-warning-fix.md` | add | root cause와 해결 패턴 문서화 |

## Implementation Steps

### Step 1: iOS renderer를 RealityView로 치환

- **Files**: `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift`
- **Changes**:
  - `UIViewRepresentable` 기반 `MuscleMap3DViewer`를 SwiftUI `View`로 바꾼다.
  - `RealityView`에 shared scene anchor를 add하고, existing yaw/pitch/zoom state를 유지한다.
  - 기존 `musclemap-3d-viewer` accessibility identifier를 유지한다.
- **Verification**: 빌드가 통과하고, 기존 화면 레이아웃/AXID가 유지된다.

### Step 2: shared scene의 ARView 잔여 의존성 정리

- **Files**: `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift`
- **Changes**:
  - 더 이상 필요 없는 `ARView` 전용 설치 API/import를 정리한다.
  - `RealityView` content add와 공존하는 anchor lifecycle을 유지한다.
- **Verification**: scene compile이 깨지지 않고, visionOS shared usage에 영향이 없다.

### Step 3: surface contract와 warning fix 검증

- **Files**: `DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift` (필요 시), build/test scripts 실행
- **Changes**:
  - 기존 UI test surface가 여전히 유효한지 확인한다.
  - 필요 시 native renderer container 존재 assertion을 그대로 유지하거나 표현을 일반화한다.
- **Verification**:
  - `scripts/build-ios.sh`
  - focused unit/UI test run
  - 수동 재현 경로 기준 warning 재발 여부 확인

## Edge Cases

| Case | Handling |
|------|----------|
| iOS `RealityView` gesture targeting API가 `ARView`와 다름 | build 실패 시 gesture wiring만 최소 범위로 조정하고 renderer 전환은 유지 |
| `RealityView`가 기본 카메라 위치를 다르게 잡음 | 기존 `MuscleMap3DState` yaw/pitch/zoom 값을 그대로 적용해 surface parity 확보 |
| entity tap selection이 일부 환경에서 약함 | 기존 하단 muscle strip selection이 fallback interaction으로 계속 동작하도록 유지 |
| scene anchor 중복 add 가능성 | `parent == nil` guard로 content 중복 추가 방지 |

## Testing Strategy

- Unit tests: 기존 `MuscleMap3DState`/bundle 관련 테스트 회귀 여부 확인
- UI tests: `ActivityMuscleMapRegressionTests`의 3D surface smoke 재실행
- Manual verification: 실제 warning이 발생하던 3D 진입 경로에서 콘솔 warning 재발 여부 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| iOS `RealityView` API 차이로 첫 빌드 실패 | Medium | Medium | build 에러 기준으로 gesture/camera syntax를 조정 |
| selection/tap interaction parity 저하 | Medium | Medium | muscle strip fallback 유지, focused UI smoke로 surface 검증 |
| detached HEAD 상태로 ship 단계 제약 | High | Low | Work Setup 단계에서 `codex/` prefix feature branch 생성 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: root cause는 `ARView` 경로로 충분히 좁혀졌고 shared `RealityView` precedent도 있다. 다만 iOS `RealityView` gesture API 상세는 build로 최종 확인이 필요하다.
