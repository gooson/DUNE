---
topic: muscle-map-real-3d
date: 2026-03-07
status: approved
confidence: medium
related_solutions:
  - architecture/2026-03-07-muscle-map-real-3d-procedural-rig.md
  - architecture/visionos-multi-target-setup.md
related_brainstorms:
  - 2026-03-07-muscle-map-real-3d.md
---

# Implementation Plan: SVG 기반 Muscle Map 3D 자산 고도화

## Context

현재 iOS의 `MuscleMap3DView`는 RealityKit를 쓰지만 실제 geometry는 capsule/sphere/box 조합의 procedural rig다. 반면 `MuscleMapData.swift`에는 front/back SVG muscle path가 이미 고해상도로 정리돼 있다. 이번 구현은 이 SVG를 3D path extrusion source로 사용해 **실제 근육 형태에 가까운 volumetric mesh**를 생성하고, 같은 scene core를 iOS와 visionOS에서 재사용하는 데 초점을 둔다.

사용자 결정 사항:

- Vision Pro 우선순위: `비전프로`, `운동 이해도`
- 주요 사용자: `파워유저`
- 자산 전략: `현재 SVG 자동 생성 우선`, 고품질 오픈소스 anatomical source는 후속 확장용으로 검토
- 범위: 좌우/레이어/고급 spatial interaction까지 고려
- Vision Pro 목표: 단순 asset 재사용이 아니라 **spatial interaction 포함**

## Requirements

### Functional

- SVG front/back muscle path를 기반으로 3D mesh를 자동 생성한다
- iOS `MuscleMap3DView`가 새 SVG-derived volumetric mesh를 사용한다
- Recovery / Volume 모드를 유지한다
- 회전, 줌, 탭 선택, reset을 지원한다
- visionOS Train 영역에 같은 3D geometry core를 사용하는 spatial viewer를 추가한다
- visionOS에서 spatial tap / drag / magnify interaction을 제공한다

### Non-functional

- geometry generation 로직은 iOS + visionOS 공용으로 유지한다
- shared 3D core는 UIKit primitive rig에 묶이지 않는다
- 기존 `MuscleGroup` 13개 contract를 유지한다
- 순수 로직(모드, 선택, geometry manifest)은 테스트 가능해야 한다

## Approach

`MeshResource(extruding:)` 기반 SVG path extrusion pipeline을 도입한다. `MuscleMapData.svgFrontParts` / `svgBackParts`의 cached `Path`를 body-scale 좌표계로 정규화한 뒤, front/back plane별 depth와 z-offset을 적용한 volumetric muscle mesh로 변환한다. 렌더링과 selection은 공용 `MuscleMap3DScene`이 담당하고, iOS는 `ARView(.nonAR)` wrapper, visionOS는 `RealityView` wrapper로 분기한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| **SVG path extrusion + shared RealityKit scene** | 현재 자산 재사용, 구현 즉시 가능, iOS/visionOS 공유 가능 | 완전한 anatomical topology는 아님 | 채택 |
| Procedural primitive rig 유지 | 구현량 적음 | 파워유저/visionOS 기대치 부족 | 기각 |
| 외부 USDZ anatomical model 즉시 도입 | 최종 품질이 높음 | 자산 제작/라이선스/파이프라인 준비가 안 됨 | 후속 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-07-muscle-map-real-3d.md` | modify | SVG extrusion + visionOS spatial scope 반영 |
| `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift` | new | 공용 scene core, SVG descriptor, mesh cache |
| `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift` | modify | iOS viewer를 shared SVG scene 기반으로 교체 |
| `DUNE/DUNEVision/Presentation/Activity/VisionTrainView.swift` | new | visionOS Train surface |
| `DUNE/DUNEVision/Presentation/Activity/VisionMuscleMapExperienceView.swift` | new | RealityView 기반 spatial muscle viewer |
| `DUNE/DUNEVision/App/VisionContentView.swift` | modify | Train tab placeholder 제거, visionOS train view 연결 |
| `DUNE/project.yml` | modify | visionOS target에 shared muscle-map files 포함 |
| `DUNETests/MuscleMapDetailViewModelTests.swift` | modify | 3D state/geometry manifest 테스트 갱신 |
| `docs/solutions/architecture/2026-03-07-muscle-map-svg-extrusion-pipeline.md` | new | 해결책 문서 |

## Implementation Steps

### Step 1: Shared SVG 3D core 추출

- **Files**: `MuscleMap3DScene.swift`
- **Changes**:
  - `MuscleMap3DMode`, `MuscleMap3DDisplayState`, `MuscleMap3DState`를 shared core로 이동
  - `MuscleMapData` front/back SVG part를 공용 descriptor로 변환
  - `MeshResource(extruding:)` 기반 async mesh cache 구현
  - front/back plane z-offset, depth, selection scale, focus yaw 정책 정의
- **Verification**: descriptor set이 13 muscle groups를 모두 덮고, geometry manifest가 테스트 가능

### Step 2: iOS Muscle Map 3D 교체

- **Files**: `MuscleMap3DView.swift`
- **Changes**:
  - 기존 primitive rig 의존 제거
  - shared scene를 `ARView(.nonAR)` wrapper에서 사용
  - 기존 summary card / mode toggle / selection strip 유지
- **Verification**: iOS 상세화면에서 기존 플로우 유지 + SVG-derived mesh 표시

### Step 3: visionOS spatial viewer 추가

- **Files**: `VisionTrainView.swift`, `VisionMuscleMapExperienceView.swift`, `VisionContentView.swift`, `project.yml`
- **Changes**:
  - Train tab placeholder를 spatial muscle viewer로 교체
  - `RealityView` + `SpatialTapGesture` + `DragGesture` + `MagnifyGesture` 적용
  - 현재 target 구조상 실제 training data sync 부재이므로, demo fatigue distribution으로 spatial prototype 연결
  - shared files를 DUNEVision target sources에 포함
- **Verification**: visionOS target typecheck/build 통과, Train tab에 viewer가 노출

### Step 4: Tests / Build / Review

- **Files**: `DUNETests/MuscleMapDetailViewModelTests.swift`, solution doc
- **Changes**:
  - `MuscleMap3DState` 테스트를 shared core 기준으로 갱신
  - geometry manifest coverage 테스트 추가
  - build/test 실행, 리뷰 결과 반영, solution 문서 작성
- **Verification**: DUNETests 통과, iOS/visionOS build 통과 또는 실패 원인 명확화

## Edge Cases

| Case | Handling |
|------|----------|
| 데이터 없는 근육 | neutral gray material |
| front/back에만 존재하는 path | 동일 muscle root 아래 plane별 entity로 조합 |
| 작은 근육 hit-test | entity collision 생성 + selection scale |
| mesh extrusion 지연 | async cache + initial loading state |
| visionOS live training data 부재 | demo fatigue distribution fallback |

## Testing Strategy

- Unit tests:
  - default selection / zoom clamp / yaw logic
  - geometry manifest covers all muscle groups
  - known SVG parts map to expected plane/muscle
- Build:
  - `scripts/build-ios.sh`
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2' -only-testing DUNETests`
  - `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNEVision -destination 'generic/platform=visionOS'`

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| SVG extrusion mesh가 과도하게 평면적으로 보임 | Medium | Medium | front/back depth, shell, chamfer, lighting으로 보완 |
| visionOS gesture API와 iOS wrapper 구조 차이 | Medium | Medium | shared scene + platform wrapper 분리 |
| DUNEVision target source 누락 | Medium | High | `project.yml` 명시 추가 후 build 검증 |
| live data integration 미완 | High | Low | demo fallback을 명시하고 scene/asset reuse를 우선 완성 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: Apple의 `MeshResource(extruding:)` 덕분에 현재 SVG를 활용한 실제 3D 전환은 가능하다. 다만 full anatomical mesh 수준은 아니므로, 이번 구현은 "고품질 자동 생성 기반 + spatial-ready architecture"를 완성하고 외부 anatomical asset 도입을 후속 단계로 남긴다.
