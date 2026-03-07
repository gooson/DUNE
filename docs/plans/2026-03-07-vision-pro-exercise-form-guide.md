---
topic: vision-pro-exercise-form-guide
date: 2026-03-07
status: draft
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-07-svg-extruded-muscle-map-shared-scene.md
  - docs/solutions/architecture/2026-03-07-vision-pro-multi-window-dashboard.md
related_brainstorms:
  - docs/brainstorms/2026-03-05-vision-pro-features.md
---

# Implementation Plan: Vision Pro Exercise Form Guide

## Context

`todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md`에서 Vision Pro 후속 범위는 `G1 Shared Workout Space`, `F3 Voice-First Workout Entry`, `C5 Exercise Form Guide`가 남아 있다. 이 중 `G1`은 GroupActivities/SharedWorldAnchors capability와 세션 동기화가 필요하고, `F3`는 speech permission과 실제 workout entry 저장 경로까지 붙이려면 DUNEVision target에 아직 없는 SwiftData exercise stack 확장이 필요하다.

반면 `C5`는 이미 존재하는 `ExerciseLibraryService`, `ExerciseDescriptions`, `MuscleMapData`를 활용하면 Vision Pro에서 바로 사용자 가치가 있는 spatial guide surface를 만들 수 있다. 이번 변경은 브레인스토밍의 "3D avatar + 자세 비교" 전체 범위를 한 번에 끝내는 것이 아니라, **exercise metadata search + form cue panel + target muscle visualization**까지를 첫 shippable slice로 정의한다.

## Requirements

### Functional

- Vision Pro `Activity` 탭에서 운동별 form guide를 검색/선택할 수 있어야 한다.
- 선택한 운동의 localized name, English name, difficulty, equipment, input type을 표시해야 한다.
- 선택한 운동의 form cue와 description을 Vision Pro용 panel에 노출해야 한다.
- 선택한 운동의 primary/secondary muscles를 visionOS에서도 시각적으로 확인할 수 있어야 한다.
- guide 데이터 로딩/검색 상태는 shared ViewModel로 분리해 unit test 가능해야 한다.
- DUNEVision target이 exercise library JSON과 guide metadata source를 정상적으로 포함해야 한다.

### Non-functional

- visionOS UI는 `DUNEVision/` 하위에 유지하고, 데이터 로직은 `DUNE/Presentation/Vision/` shared source에 둔다.
- 새 사용자 대면 문자열은 `Shared/Resources/Localizable.xcstrings`에 en/ko/ja로 등록한다.
- 기존 `VisionTrainView`와 시각 언어를 크게 깨지 않으면서 glass/material 중심 레이아웃을 유지한다.
- 새 로직에는 Swift Testing 기반 unit test를 추가한다.

## Approach

공용 Presentation layer에 `VisionExerciseFormGuideViewModel`을 추가하고, exercise library에서 guide에 필요한 metadata를 정규화한 뒤 DUNEVision의 `Activity` 탭에서 이를 렌더링한다. UI는 크게 세 부분으로 나눈다.

1. 상단 hero/summary
2. 검색 + 추천 exercise rail
3. 선택 exercise의 cue/details + 전용 target muscle map

muscle visualization은 iOS `ExerciseMuscleMapView`의 아이디어를 재사용하되, DUNEVision target이 현재 포함하지 않는 DS token 의존을 피하기 위해 visionOS 전용 lightweight body map view로 구현한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| F3 Voice-First Entry 먼저 구현 | roadmap 순서상 자연스럽고 novelty 높음 | speech/mic permission + 저장 경로 부재로 scope 급증 | 기각 |
| C5 full avatar/body-tracking 버전 | 브레인스토밍 최종 비전에 가장 가까움 | 3D asset/body tracking/API maturity가 현재 범위를 넘음 | 기각 |
| C5 foundation: shared guide VM + spatial guide panel + target muscle map | 기존 asset/data 재사용, 테스트 가능, 이번 턴 ship 가능 | full avatar 대비 표현력 제한 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-07-vision-pro-exercise-form-guide.md` | new | 이번 구현 계획서 |
| `DUNE/Presentation/Vision/VisionExerciseFormGuideViewModel.swift` | new | shared guide state/search/filter logic |
| `DUNETests/VisionExerciseFormGuideViewModelTests.swift` | new | guide filtering/selection/fallback 검증 |
| `DUNEVision/Presentation/Activity/VisionExerciseFormGuideView.swift` | new | visionOS form guide surface |
| `DUNEVision/Presentation/Activity/VisionExerciseMuscleMapView.swift` | new | visionOS lightweight target muscle visualization |
| `DUNEVision/Presentation/Activity/VisionTrainView.swift` | modify | Activity 탭을 form guide 중심으로 재구성 |
| `DUNE/project.yml` | modify | DUNEVision target에 exercise guide 관련 shared source/resource 포함 |
| `Shared/Resources/Localizable.xcstrings` | modify | Vision Pro guide copy 추가 |
| `todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md` | modify | C5 진행 현황 반영 |

## Implementation Steps

### Step 1: shared guide data/view model 구성

- **Files**: `DUNE/Presentation/Vision/VisionExerciseFormGuideViewModel.swift`, `DUNETests/VisionExerciseFormGuideViewModelTests.swift`
- **Changes**:
  - guide에 필요한 요약 모델과 load state 정의
  - `ExerciseLibraryQuerying` 기반 추천/검색/선택 로직 구현
  - description/form cues fallback을 `ExerciseDescriptions`와 결합
  - 추천 exercise 세트와 query filtering 규칙을 테스트로 고정
- **Verification**:
  - `VisionExerciseFormGuideViewModelTests` 통과
  - 빈 검색어/검색 결과 없음/guide cue 없음/selection fallback 케이스 검증

### Step 2: visionOS form guide UI 추가

- **Files**: `DUNEVision/Presentation/Activity/VisionExerciseFormGuideView.swift`, `DUNEVision/Presentation/Activity/VisionExerciseMuscleMapView.swift`, `DUNEVision/Presentation/Activity/VisionTrainView.swift`
- **Changes**:
  - Activity 탭의 hero section 아래에 guide browser 구성
  - searchable UI + 추천 card/chip + detail panel 추가
  - primary/secondary muscles를 front/back body map으로 표시
  - difficulty/equipment/category/input metadata 노출
- **Verification**:
  - visionOS build 통과
  - guide가 없는 exercise 선택 시 fallback copy가 자연스럽게 보임

### Step 3: target/resource wiring 및 localization 정리

- **Files**: `DUNE/project.yml`, `Shared/Resources/Localizable.xcstrings`, `todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md`
- **Changes**:
  - DUNEVision target에 `ExerciseLibraryService`, `ExerciseDescriptions`, `ExerciseLibraryQuerying`, `exercises.json`, 필요한 shared extensions/source 추가
  - 새 guide 문구를 en/ko/ja에 등록
  - TODO에 C5 foundation 완료 범위와 남은 full-avatar/body-tracking 후속 scope 명시
- **Verification**:
  - `scripts/lib/regen-project.sh` 후 project generation 정상
  - string catalog 누락 없이 build 통과

## Edge Cases

| Case | Handling |
|------|----------|
| 검색 결과가 없음 | empty-state card + 추천 exercise fallback 유지 |
| exercise에 description/form cues가 없음 | generic guidance copy + target muscle 정보만 표시 |
| primary/secondary muscles가 비어 있음 | muscle map 대신 unavailable card 표시 |
| canonical variant 검색 | exercise library canonical search 결과를 그대로 사용 |
| visionOS bundle에 exercises.json 누락 | target resource wiring을 build 단계에서 검증 |

## Testing Strategy

- Unit tests: `VisionExerciseFormGuideViewModelTests`로 추천 목록, query filtering, selection fallback, metadata fallback 검증
- Integration tests: 없음 (UI는 build + 수동 확인으로 검증)
- Manual verification:
  - `scripts/lib/regen-project.sh`
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2' -only-testing DUNETests/VisionExerciseFormGuideViewModelTests`
  - `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNEVision -destination 'generic/platform=visionOS'`

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| DUNEVision target에 shared source/resource 추가 시 build wiring 누락 | medium | high | `project.yml` 수정 후 regen-project + visionOS build 즉시 실행 |
| 기존 iOS 전용 helper/DS 의존이 visionOS compile을 깨뜨림 | medium | medium | visionOS 전용 map view를 새로 만들고 shared logic만 재사용 |
| 새 copy localization 누락 | medium | medium | `Shared/Resources/Localizable.xcstrings` en/ko/ja 동시 추가 + 리뷰 단계 L10N 검증 |
| guide metadata가 일부 운동에서 부족 | high | low | `ExerciseDescriptions` fallback + generic cue copy로 degrade |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: exercise metadata와 muscle map 자산은 이미 존재해 기능 slice 자체는 안정적이다. 다만 DUNEVision target source wiring과 visionOS build 검증은 XcodeGen/source membership에 민감하므로 medium으로 둔다.
