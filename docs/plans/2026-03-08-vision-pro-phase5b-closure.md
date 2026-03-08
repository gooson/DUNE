---
topic: visionOS Phase 5B closure
date: 2026-03-08
status: approved
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-08-visionos-volumetric-ux-polish.md
  - docs/solutions/architecture/2026-03-07-vision-pro-multi-window-dashboard.md
  - docs/solutions/architecture/2026-03-07-visionos-mirror-sync-gating-and-spatial-fallback.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-vision-pro-production-roadmap.md
---

# Implementation Plan: visionOS Phase 5B closure

## Context

`todos/022-in-progress-p2-vision-ux-polish.md`의 남은 범위는 `defaultWindowPlacement`, DUNEVision 전반의 잔여 `.caption` 제거, 그리고 window placement 검증이다.
이미 dashboard 단순화, volumetric ornament 분리, empty state 통일은 반영되어 있으므로 이번 배치는 5B를 닫는 마무리 변경에 집중한다.

Apple의 visionOS window placement 가이드(WWDC24 "Work with windows in SwiftUI", "Use SwiftUI with RealityKit") 기준으로, 추가 window는 메인 window 또는 기존 window를 기준으로 상대 배치해야 겹침을 줄일 수 있다.

## Requirements

### Functional

- dashboard condition/activity/sleep/body window와 `chart3d` window에 기본 상대 배치를 지정한다.
- sleep/body window는 condition/activity window가 이미 열려 있으면 해당 window 아래로 배치한다.
- 메인 window 또는 기준 window를 찾지 못하면 안전한 fallback placement를 사용한다.
- DUNEVision에 남아 있는 `.caption` 사용을 `.callout` 이상으로 정리해 5B typography 규칙을 만족시킨다.
- `todos/022`를 완료 상태로 반영하고, 후속 TODO 문맥이 어긋나지 않도록 관련 Vision Pro TODO 메모를 갱신한다.

### Non-functional

- window placement 의사결정은 순수 로직으로 분리해 unit test로 고정한다.
- App/Scene wiring 변경은 기존 multi-window 구조를 유지하고, DUNEVisionApp 내부에서만 실제 `WindowPlacement` 타입으로 매핑한다.
- 변경 범위는 visionOS Phase 5B closure에 필요한 파일로 한정한다.

## Approach

window placement를 직접 Scene closure 안에 하드코딩하지 않고, shared Presentation layer에 배치 플래너를 둔다. 플래너는 열려 있는 window ID 집합을 입력받아 "어느 window의 leading/trailing/above/below에 둘지"만 결정한다. DUNEVisionApp은 이 결과를 `WindowPlacementContext.windows`의 `WindowProxy`와 연결해 실제 `WindowPlacement`를 만든다.

이 방식은 두 가지 장점이 있다.

- 배치 규칙을 `DUNETests`에서 pure unit test로 검증할 수 있다.
- SwiftUI window API에 직접 의존하는 코드는 app target에만 남겨, layout policy와 Scene wiring을 분리할 수 있다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `DUNEVisionApp`의 `.defaultWindowPlacement` closure에 모든 규칙 직접 작성 | 파일 수가 적다 | 테스트 불가, 분기 증가 시 읽기 어렵다 | 기각 |
| 모든 추가 window를 `.utilityPanel`로만 배치 | 구현이 단순하다 | 2x2 dashboard intent를 충족하지 못하고 겹침 회피가 약하다 | 기각 |
| window placement helper를 DUNEVision target 전용 파일로 분리 | app wiring과 가깝다 | `DUNETests`에서 직접 회귀 테스트하기 어렵다 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-08-vision-pro-phase5b-closure.md` | add | 이번 배치 계획서 |
| `DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift` | add | window placement 순수 규칙 정의 |
| `DUNETests/VisionWindowPlacementPlannerTests.swift` | add | placement 규칙 회귀 테스트 |
| `DUNEVision/App/DUNEVisionApp.swift` | modify | planner 결과를 `defaultWindowPlacement`에 연결 |
| `DUNEVision/Presentation/Activity/VisionExerciseMuscleMapView.swift` | modify | 잔여 `.caption` 정리 |
| `DUNEVision/Presentation/Activity/VisionExerciseFormGuideView.swift` | modify | 잔여 `.caption` 정리 |
| `DUNEVision/Presentation/Chart3D/ConditionScatter3DView.swift` | modify | 잔여 `.caption` 정리 |
| `DUNEVision/Presentation/Immersive/VisionImmersiveExperienceView.swift` | modify | 잔여 `.caption` 정리 |
| `todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md` | modify | 5B 완료 및 5C 후속 관계 메모 정리 |
| `todos/022-in-progress-p2-vision-ux-polish.md` | move/modify | 완료 상태로 전환 |
| `todos/023-in-progress-p2-vision-phase4-remaining.md` | modify | 5B 종료 후 다음 phase 문맥 정리 |

## Implementation Steps

### Step 1: Add a testable window placement planner

- **Files**: `DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift`, `DUNETests/VisionWindowPlacementPlannerTests.swift`
- **Changes**:
  - dashboard windows + `chart3d`에 대한 placement target enum을 정의한다.
  - 열린 window ID 목록을 기준으로 상대 배치 규칙을 계산하는 pure helper를 추가한다.
  - sleep/body의 secondary anchor fallback, main window fallback, unknown window fallback을 테스트로 고정한다.
- **Verification**:
  - Swift Testing으로 condition/activity/sleep/body/chart3d 배치 규칙 검증
  - condition/activity 미오픈 상태에서 sleep/body fallback 검증

### Step 2: Wire planner into DUNEVisionApp

- **Files**: `DUNEVision/App/DUNEVisionApp.swift`
- **Changes**:
  - planner 결과를 `WindowPlacementContext.windows`의 `WindowProxy`와 매핑하는 helper를 추가한다.
  - 4개 dashboard window와 `chart3d` window에 `.defaultWindowPlacement`를 연결한다.
  - relative window를 찾지 못하면 `.utilityPanel` 또는 main-window-relative fallback을 사용한다.
- **Verification**:
  - DUNEVision build가 통과한다.
  - `rg "defaultWindowPlacement" DUNEVision/App/DUNEVisionApp.swift`로 각 대상 window 연결 확인

### Step 3: Remove remaining `.caption` usage in DUNEVision

- **Files**: `VisionExerciseMuscleMapView.swift`, `VisionExerciseFormGuideView.swift`, `ConditionScatter3DView.swift`, `VisionImmersiveExperienceView.swift`
- **Changes**:
  - visionOS readable minimum을 맞추도록 `.caption` 기반 레이블을 `.callout` 또는 `.callout.weight(...)`로 상향한다.
  - 범례/패널 보조 텍스트는 tone은 유지하되 size만 상향한다.
- **Verification**:
  - `rg "\.font\(\.caption" DUNEVision` 결과 0건

### Step 4: Close the Phase 5B TODO state

- **Files**: `todos/020...`, `todos/022...`, `todos/023...`
- **Changes**:
  - `022`를 `done` 상태와 파일명으로 전환하고 완료 근거(placement + typography + verification)를 남긴다.
  - `020` umbrella TODO에 5B 종료와 5C 후속 관계를 반영한다.
  - `023`의 진행 메모를 다음 실행 대상 기준으로 정리한다.
- **Verification**:
  - TODO 파일명/status 규칙 일치
  - Vision Pro backlog 문맥이 `022 done -> 023 ready` 흐름으로 정리됨

## Edge Cases

| Case | Handling |
|------|----------|
| main window proxy가 아직 context에 없음 | `.utilityPanel` fallback 사용 |
| sleep/body window를 condition/activity 없이 먼저 열었음 | main window 아래 placement로 fallback |
| SwiftUI가 같은 ID window proxy를 아직 보고하지 않음 | planner는 ID 기반 intent만 반환하고 app layer가 fallback 처리 |
| typography 상향으로 레이아웃이 좁아짐 | 기존 frame/padding을 유지하고 size만 상향 |

## Testing Strategy

- Unit tests: `VisionWindowPlacementPlannerTests`로 placement intent 규칙 고정
- Build verification: `scripts/build-ios.sh`
- Targeted tests: `scripts/test-unit.sh --filter VisionWindowPlacementPlannerTests`가 지원되지 않으면 `swift test` 또는 `xcodebuild test` 대체
- Manual verification: visionOS simulator에서 dashboard 4개 window + chart3d open 시 기본 배치가 겹치지 않는지 확인
- Static verification: `rg "\.font\(\.caption" DUNEVision` 결과 0건 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `WindowPlacementContext.windows`에 기대한 proxy가 없어서 상대 배치가 적용되지 않음 | Medium | Medium | planner를 ID intent로 분리하고 app layer fallback을 둔다 |
| visionOS simulator와 실기기 배치 동작이 다름 | Medium | Medium | relative placement를 보수적으로 적용하고 결과를 TODO 메모에 simulator 기준으로 기록 |
| pure planner가 실제 Scene wiring과 어긋남 | Low | Medium | app layer mapping helper를 단순하게 유지하고 build + manual open으로 교차 검증 |
| TODO 정리까지 묶으면서 변경 범위가 커짐 | Low | Low | 관련 Vision Pro TODO 3개만 업데이트하고 다른 backlog는 건드리지 않는다 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 남은 작업 범위가 명확하고, SwiftUI window API 시그니처를 SDK에서 직접 확인했다. 핵심 불확실성은 runtime placement behavior뿐인데, 이는 fallback + simulator verification으로 관리 가능하다.
