---
topic: vision-pro-phase2-volumetric
date: 2026-03-07
status: implemented
confidence: medium
related_solutions:
  - docs/solutions/architecture/visionos-multi-target-setup.md
related_brainstorms:
  - docs/brainstorms/2026-03-05-vision-pro-features.md
---

# Implementation Plan: Vision Pro Phase 2 Volumetric

## Context

Vision Pro Phase 1은 Shared Space 대시보드와 Chart3D 창까지 구현되었지만, Phase 2 TODO(`todos/018-done-p2-vision-pro-phase2-realitykit-volumetric.md`)의 핵심인 volumetric 3D 경험은 비어 있었다. 이번 변경은 HealthKit 기반 실데이터를 이용해 Vision Pro 전용 volumetric 창을 추가하고, Heart Rate Orb, Training Volume Blocks, Body Heatmap 모델을 한 창 안에서 탐색 가능하게 만들었다.

## Requirements

### Functional

- Vision Pro 앱에서 volumetric window를 열 수 있어야 한다.
- volumetric window 안에서 Heart Rate Orb, Training Volume Blocks, Body Heatmap 3개 장면을 전환할 수 있어야 한다.
- Heart Rate Orb는 최신 심박수와 baseline RHR 차이를 반영해야 한다.
- Training Volume Blocks와 Body Heatmap은 최근 운동 데이터를 근육 그룹별 load/fatigue로 요약해 반영해야 한다.
- HealthKit 데이터를 읽지 못하는 경우 empty/error 상태를 명시적으로 보여야 한다.

### Non-functional

- 기존 Domain fatigue/weekly volume 계산 로직을 최대한 재사용한다.
- visionOS 전용 UI는 `DUNEVision/` 하위에 격리하고, 순수 계산 로직은 테스트 가능한 shared code로 둔다.
- `project.yml`을 source of truth로 유지하고 필요 시 xcodegen 재생성으로 반영한다.
- 테스트는 Swift Testing으로 추가한다.

## Approach

HealthKit `WorkoutSummary`와 `VitalSample`을 spatial-friendly 요약 모델로 변환하는 shared Domain analyzer를 추가하고, `DUNEVision`에서는 그 결과만 받아 RealityKit 기반 volumetric scene을 렌더링한다. 운동 기록은 manual `ExerciseRecord`를 아직 visionOS에 직접 공유하지 않으므로, HealthKit workout의 category/duration/distance를 deterministic pseudo-volume으로 변환해 근육별 weekly load와 fatigue를 계산한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| iOS용 `MuscleMap3DView`를 그대로 visionOS target에 공유 | 기존 3D 바디 리그 재사용 | UIKit `UIViewRepresentable` 의존, visionOS volumetric UX와 맞지 않음 | 기각 |
| Vision target 안에 매핑/계산 로직을 모두 로컬 구현 | 구현이 빠름 | 테스트 어려움, Domain 규칙 위반 가능성 | 기각 |
| shared analyzer + visionOS 전용 RealityKit scene | 테스트 가능, 레이어 분리 유지, volumetric UX 최적화 | pseudo-volume 설계 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-07-vision-pro-phase2-volumetric.md` | new | Phase 2 구현 계획 문서 |
| `DUNE/project.yml` | modify | DUNEVision target에서 fatigue/shared protocol 파일을 포함하도록 조정 |
| `DUNE/Domain/UseCases/SpatialTrainingAnalyzer.swift` | new | WorkoutSummary -> spatial summary/fatigue state 변환 |
| `DUNE/DUNEVision/App/DUNEVisionApp.swift` | modify | volumetric window scene 추가 |
| `DUNE/DUNEVision/App/VisionContentView.swift` | modify | volumetric 창 열기 action 연결 |
| `DUNE/DUNEVision/Presentation/Dashboard/VisionDashboardView.swift` | modify | volumetric quick action 추가 |
| `DUNE/DUNEVision/Presentation/Volumetric/VisionSpatialViewModel.swift` | new | HealthKit fetch + analyzer orchestration |
| `DUNE/DUNEVision/Presentation/Volumetric/VisionVolumetricExperienceView.swift` | new | volumetric picker/container |
| `DUNE/DUNEVision/Presentation/Volumetric/HeartRateOrbSceneView.swift` | new | 최신 심박수 orb scene |
| `DUNE/DUNEVision/Presentation/Volumetric/TrainingVolumeBlocksSceneView.swift` | new | 근육별 block scene |
| `DUNE/DUNEVision/Presentation/Volumetric/BodyHeatmapSceneView.swift` | new | 근육별 body heatmap scene |
| `DUNETests/SpatialTrainingAnalyzerTests.swift` | new | pseudo-volume/fatigue summary unit tests |
| `todos/018-done-p2-vision-pro-phase2-realitykit-volumetric.md` | modify | TODO 상태 갱신 |
| `docs/solutions/architecture/2026-03-07-vision-pro-volumetric-phase2.md` | new | 구현 후 해결책 문서 |

## Implementation Steps

### Step 1: Shared analyzer 추가

- **Files**: `DUNE/Domain/UseCases/SpatialTrainingAnalyzer.swift`, `DUNETests/SpatialTrainingAnalyzerTests.swift`
- **Changes**:
  - `WorkoutSummary`를 `ExerciseRecordSnapshot`으로 매핑하는 로직 추가
  - workout category/duration/distance 기반 pseudo-volume 계산
  - latest heart rate + baseline RHR + fatigue states를 묶는 summary 모델 정의
- **Verification**:
  - unit tests로 pseudo-volume, secondary muscle weighting, empty state, featured muscle ordering 검증

### Step 2: visionOS volumetric window와 view model 구현

- **Files**: `DUNE/DUNEVision/App/DUNEVisionApp.swift`, `DUNE/DUNEVision/Presentation/Volumetric/VisionSpatialViewModel.swift`, `DUNE/project.yml`
- **Changes**:
  - volumetric `WindowGroup(id:)` 추가
  - `HeartRateQueryService`, `WorkoutQueryService`, `SharedHealthDataService`를 병렬 호출하는 view model 구현
  - 필요한 shared Domain files가 DUNEVision target에 포함되도록 `project.yml` 조정
- **Verification**:
  - project regeneration 후 DUNEVision target compile 가능 여부 확인
  - empty/error/loading state가 모두 렌더링되는지 확인

### Step 3: RealityKit scene 3종 구현

- **Files**: `DUNE/DUNEVision/Presentation/Volumetric/HeartRateOrbSceneView.swift`, `DUNE/DUNEVision/Presentation/Volumetric/TrainingVolumeBlocksSceneView.swift`, `DUNE/DUNEVision/Presentation/Volumetric/BodyHeatmapSceneView.swift`, `DUNE/DUNEVision/Presentation/Volumetric/VisionVolumetricExperienceView.swift`
- **Changes**:
  - Heart Rate Orb: BPM 기반 pulse/scale/color
  - Training Volume Blocks: 근육별 block height/color
  - Body Heatmap: 단순 인체 리그 + 근육별 highlight
  - scene picker 및 muscle detail overlay 추가
- **Verification**:
  - SwiftUI preview 수준의 compile sanity
  - scene 전환 시 상태 유지/selection 반영 확인

### Step 4: App entry/dashboard 연결 및 문서화

- **Files**: `DUNE/DUNEVision/App/VisionContentView.swift`, `DUNE/DUNEVision/Presentation/Dashboard/VisionDashboardView.swift`, `todos/018-done-p2-vision-pro-phase2-realitykit-volumetric.md`
- **Changes**:
  - dashboard quick action + toolbar에서 volumetric 창 오픈
  - TODO 상태 `done` 갱신
- **Verification**:
  - `openWindow(id:)` 경로가 chart3d와 충돌 없이 동작하는지 확인

## Edge Cases

| Case | Handling |
|------|----------|
| HeartKit/HealthKit unavailable on simulator | empty snapshot + explanatory fallback copy 표시 |
| 최신 heart rate가 없고 RHR만 있는 경우 | orb는 baseline 기반 정적 상태로 렌더링 |
| recent workouts가 strength metadata 없이 broad category인 경우 | duration/distance 기반 pseudo-volume으로 최소 1 load unit 보장 |
| 근육 데이터가 전혀 없는 경우 | body heatmap과 blocks는 placeholder 상태/설명 카드 표시 |
| visionOS target에 shared file 추가 후 compile conflict 발생 | `project.yml`의 exclude 범위를 좁히고 vision-specific wrapper로 분리 |

## Testing Strategy

- Unit tests: `SpatialTrainingAnalyzerTests`에서 pseudo-volume, fatigue aggregation, heart rate normalization 검증
- Integration tests: `scripts/build-ios.sh`로 xcodegen + iOS compile sanity, `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests ...` 실행
- Manual verification: volumetric window scene open path, picker 전환, empty/loading/error state 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| volumetric window modifiers가 현재 Xcode/SDK 문법과 다를 수 있음 | medium | high | Apple visionOS docs 기준으로 scene API 확인 후 적용 |
| HealthKit-only workout를 volume로 환산하는 방식이 과도하게 추정적일 수 있음 | high | medium | UI copy와 solution doc에 "HealthKit-derived load units"로 명시 |
| RealityKit scene update가 과도하게 복잡해질 수 있음 | medium | medium | 장면별 파일 분리, primitive entity 중심 구성 |
| DUNEVision target source 확장으로 compile 범위가 커질 수 있음 | medium | medium | Domain-only 파일만 추가 공유, UIKit/SwiftData 의존은 제외 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: shared analyzer 분리, volumetric window 연결, RealityKit scene 3종, 로컬라이제이션, Vision/iOS 빌드, 스모크 테스트까지 검증을 완료했다. 남은 리스크는 xcodegen 중복 그룹 경고처럼 구조적 정리 성격의 경고다.
