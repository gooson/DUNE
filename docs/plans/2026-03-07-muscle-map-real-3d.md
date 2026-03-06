---
topic: muscle-map-real-3d
date: 2026-03-07
status: approved
confidence: medium
related_solutions:
  - architecture/2026-02-27-muscle-map-volume-mode-integration.md
  - architecture/2026-02-27-muscle-map-detail-view-integration.md
related_brainstorms:
  - 2026-03-07-muscle-map-real-3d.md
---

# Implementation Plan: Muscle Map Real 3D

## Context

현재 `MuscleMap3DView`는 front/back SVG를 `rotation3DEffect`로 회전시키는 pseudo-3D다. 사용자는 실제 3D 공간감, 회전/줌/탭 가능한 근육 탐색, 고숙련자 기준의 더 강한 몰입감을 원한다. 외부 USDZ 자산이 없는 현재 repo 조건에서는, 우선 **RealityKit procedural 3D rig**로 실제 3D 전환을 구현하고, 이후 anatomical USDZ asset으로 교체 가능한 구조를 만드는 것이 가장 현실적이다.

## Requirements

### Functional

- 실제 3D body/muscle viewer를 제공한다
- 회전, 줌, 근육 탭 선택, reset을 지원한다
- Recovery / Volume 모드를 3D에서도 전환할 수 있다
- 선택한 근육을 강조하고 현재 상태를 텍스트로 보여준다
- 데이터가 없는 근육은 회색 처리한다
- 기존 `MuscleMapDetailView` 진입 플로우를 유지한다

### Non-functional

- iPhone / iPad에서 동작해야 한다
- deprecated SceneKit 대신 RealityKit 기반으로 구현한다
- 렌더링 로직을 별도 파일로 분리해 향후 USDZ asset으로 교체 가능해야 한다
- 순수 로직(모드/선택/줌 범위/part mapping)은 유닛 테스트 가능해야 한다

## Approach

`ARView(cameraMode: .nonAR)`를 `UIViewRepresentable`로 감싼 3D viewer를 도입한다. 인체는 capsule / sphere / box 기반의 stylized procedural rig로 구성하고, 각 primitive를 `MuscleGroup`에 매핑한다. SwiftUI 바깥의 3D 엔진 의존성은 래퍼 파일에 가두고, 색상/선택/줌/회전 상태는 순수 Swift helper로 분리한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| RealityKit + procedural rig | 실제 3D, iOS 26 적합, asset 없이 즉시 구현 가능 | anatomical fidelity 제한 | 채택 |
| RealityKit + segmented USDZ | 최종 목표에 가장 근접 | 외부 자산/파이프라인 부재로 이번 턴 구현 불가 | 후속 |
| SceneKit + procedural rig | 구현 난이도 낮음 | iOS 26 deprecated, 신규 핵심 기능에 부적합 | 기각 |
| 기존 pseudo-3D 유지 | 변경량 적음 | 사용자 요구 불충족 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-07-muscle-map-real-3d.md` | new | 구현 계획 문서 |
| `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift` | modify | pseudo-3D 화면을 실제 3D viewer 컨테이너로 교체 |
| `DUNE/Presentation/Activity/MuscleMap/Components/MuscleMap3DViewer.swift` | new | `UIViewRepresentable` 기반 RealityKit viewer |
| `DUNE/Presentation/Activity/MuscleMap/Components/MuscleMap3DScene.swift` | new | procedural body part spec, entity 생성, material 갱신 |
| `DUNE/Presentation/Activity/MuscleMap/Components/MuscleMap3DState.swift` | new | mode / selection / rotation / zoom 순수 로직 |
| `DUNETests/MuscleMap3DStateTests.swift` | new | 새 3D 상태/매핑 로직 테스트 |
| `DUNE/Resources/Localizable.xcstrings` | modify | 새 사용자 대면 문자열 추가 시 번역 반영 |

## Implementation Steps

### Step 1: 3D 상태/레이아웃 로직 분리

- **Files**: `MuscleMap3DState.swift`, `DUNETests/MuscleMap3DStateTests.swift`
- **Changes**:
  - Recovery / Volume / no-data / selected 상태를 해석하는 순수 helper 추가
  - zoom clamp, rotation normalization, muscle-to-part mapping 규칙 정의
  - procedural rig spec가 모든 `MuscleGroup`을 포함하는지 검증하는 테스트 추가
- **Verification**: Swift Testing unit tests가 통과하고, 13개 muscle group 전부 커버됨

### Step 2: RealityKit procedural viewer 구현

- **Files**: `MuscleMap3DViewer.swift`, `MuscleMap3DScene.swift`
- **Changes**:
  - `ARView(cameraMode: .nonAR)` wrapper 구현
  - neutral body shell + muscle primitive entities 생성
  - tap/pan/pinch gesture를 coordinator에서 처리
  - mode/selection 변화 시 material 재적용
- **Verification**: 코드 상에서 3D entity tree가 생성되고 selection callback이 SwiftUI까지 전달됨

### Step 3: 3D 화면 UI 통합

- **Files**: `MuscleMap3DView.swift`, 필요 시 `Localizable.xcstrings`
- **Changes**:
  - 기존 pseudo-3D rotation UI 제거
  - 실제 3D viewer + segmented picker + selected muscle summary + reset control 구성
  - 기존 `highlightedMuscle` 초기 선택을 유지
- **Verification**: `MuscleMapDetailView`에서 3D 화면 진입 시 기존 플로우가 깨지지 않음

### Step 4: 품질 검증 및 문서화

- **Files**: 테스트/솔루션 문서
- **Changes**:
  - unit test / build 실행
  - review 관점별 점검 후 발견사항 수정
  - solution 문서 작성
- **Verification**: 테스트 통과, P1 0건, worktree 정리 완료

## Edge Cases

| Case | Handling |
|------|----------|
| 데이터 없는 근육 | 중립 회색 material 적용 |
| 작은 근육 탭 어려움 | muscle별 collider를 실제 mesh보다 약간 크게 구성 |
| 과도한 확대/축소 | zoom scale clamp 적용 |
| 선택 근육이 없는 상태 | neutral summary 표시 |
| 3D 초기화 실패 | 기존 SwiftUI placeholder/empty summary 유지 가능하도록 wrapper에서 방어 |

## Testing Strategy

- Unit tests: `MuscleMap3DStateTests`에서 rotation normalization, zoom clamp, mode mapping, muscle coverage 검증
- Integration tests: `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2' -only-testing DUNETests`
- Manual verification:
  - Activity → Muscle Map → 3D 화면 진입
  - 회전 / 줌 / 탭 / Reset 동작
  - Recovery / Volume 전환 시 색상 반영
  - no-data 근육 회색 처리 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| RealityKit nonAR gesture 구현 이슈 | Medium | High | gesture는 coordinator에서 직접 처리하고 상태 로직은 순수 helper로 분리 |
| procedural rig가 해부학적으로 투박해 보임 | High | Medium | stylized athletic silhouette + lighting + grouped muscle shapes로 보완 |
| 새 문자열 localization 누락 | Medium | Medium | 문자열 최소화 + xcstrings 동시 갱신 |
| simulator에서 3D 품질 차이 | Medium | Low | build/test는 unit 중심, 수동 검증 포인트 명시 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 pseudo-3D를 실제 3D 엔진 기반으로 교체하는 방향은 명확하다. 다만 외부 3D asset 없이 procedural rig로 구현해야 하므로 anatomical fidelity보다 interaction/architecture 완성도에 초점을 맞춰야 한다.
