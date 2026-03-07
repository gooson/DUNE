---
topic: cardio-template-audit
date: 2026-03-07
status: draft
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-02-phone-watch-cardio-parity.md
  - docs/solutions/general/2026-03-03-watch-template-sync-watchconnectivity-fallback.md
related_brainstorms:
  - docs/brainstorms/2026-03-07-non-distance-cardio-level-model.md
---

# Implementation Plan: Cardio Template Audit

## Context

템플릿 생성/편집 화면에서 `durationDistance` 계열 유산소가 근력 운동과 동일한 `sets / reps / weight / rest` 폼으로 렌더링된다.
동시에 템플릿 실행 경로 일부는 custom exercise 메타데이터를 잃고 fallback으로 근력 운동처럼 해석할 수 있다.

이 문제는 최소한 다음 두 가지 증상을 만든다.

- 유산소 템플릿 등록 화면이 잘못된 mental model을 유도한다.
- custom cardio 템플릿이 다시 열리거나 시작될 때 strength fallback으로 기울 수 있다.

## Requirements

### Functional

- cardio/non-strength 템플릿 항목은 생성/편집 화면에서 strength 전용 기본값 UI를 노출하지 않는다.
- template entry -> exercise resolution은 built-in과 custom exercise 모두 원본 `inputType`/`cardioSecondaryUnit`을 유지한다.
- single-entry strength/bodyweight template는 저장된 template defaults를 실제 시작 화면에 전달한다.
- single-entry cardio template는 기존 live cardio 시작 경로를 유지한다.
- template transition/preview 텍스트는 cardio 항목에서 strength 용어를 노출하지 않는다.

### Non-functional

- 기존 `TemplateEntry` CloudKit 직렬화 계약은 깨지지 않도록 유지한다.
- 새 문자열 추가는 최소화하고 existing localized keys를 우선 재사용한다.
- 변경 로직은 pure helper로 분리해 unit test로 회귀를 막는다.

## Approach

템플릿 엔트리 자체를 마이그레이션하지 않고, 템플릿에서 운동 정의를 다시 해석하는 resolver/helper 계층을 추가한다.
이 helper로 `TemplateEntry`의 실제 input profile을 판별하고, 생성/편집/시작/전환 UI가 그 profile을 기준으로 동작하게 만든다.

single-entry template 시작은 `ExerciseStartView`에 optional template entry를 전달해 strength/bodyweight defaults를 적용하고,
cardio는 기존 cardio sheet를 그대로 사용한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `TemplateEntry` 스키마를 optional reps/inputType 포함으로 확장 | 데이터 의미가 가장 정확함 | CloudKit 직렬화 계약 영향이 크고 연쇄 수정 범위가 커짐 | 이번 범위에서는 보류 |
| `CreateTemplateView`만 cardio-aware로 수정 | 화면 증상은 즉시 해결 | custom cardio resolution, single template defaults 누락은 그대로 남음 | 기각 |
| 템플릿 실행 전체를 cardio live session까지 재설계 | 구조적으로 가장 완전함 | sequential template orchestration까지 바뀌어 범위가 과도함 | 후속 과제로 분리 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift` | modify | cardio/non-strength entry rows를 strength 전용 폼 대신 profile 기반 UI로 렌더링 |
| `DUNE/Presentation/Exercise/ExerciseView.swift` | modify | template entry resolution을 helper 기반으로 통일하고 single-entry template launch를 보정 |
| `DUNE/Presentation/Exercise/ExerciseStartView.swift` | modify | optional template entry를 받아 single strength/bodyweight template defaults 전달 |
| `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | modify | template entry defaults를 session view model에 적용 |
| `DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift` | modify | template entry defaults 적용 helper 추가 및 cardio leakage 방지 |
| `DUNE/Presentation/Exercise/Components/ExerciseTransitionView.swift` | modify | cardio/non-strength transition copy에서 strength 용어 제거 |
| `DUNE/Presentation/Exercise/TemplateExerciseResolver.swift` | new | template entry -> exercise resolution/profile helper |
| `DUNETests/TemplateExerciseResolverTests.swift` | new | custom cardio resolution/profile 판별 테스트 |
| `DUNETests/WorkoutSessionViewModelTests.swift` | modify | template defaults 적용/비적용 분기 회귀 테스트 추가 |

## Implementation Steps

### Step 1: Add template resolution/profile helper

- **Files**: `DUNE/Presentation/Exercise/TemplateExerciseResolver.swift`, `DUNETests/TemplateExerciseResolverTests.swift`
- **Changes**:
  - built-in/custom exercise를 모두 해석하는 pure resolver 추가
  - template entry input profile(strength/cardio/rounds/flexibility)를 판별하는 helper 추가
  - custom cardio entry가 strength fallback으로 붕괴하지 않는 테스트 추가
- **Verification**:
  - resolver unit tests 통과
  - cardio custom definition의 `inputType == .durationDistance` 유지

### Step 2: Make template editor/start flow cardio-aware

- **Files**: `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift`, `DUNE/Presentation/Exercise/ExerciseView.swift`, `DUNE/Presentation/Exercise/ExerciseStartView.swift`
- **Changes**:
  - template editor row를 profile 기반으로 분기
  - single-entry template 시작 시 optional template entry를 전달
  - non-cardio template defaults가 실제 시작 flow로 전달되도록 상태 모델 정리
- **Verification**:
  - cardio row에서 sets/reps/weight/rest control이 렌더링되지 않음
  - single strength/bodyweight template가 저장된 set count/defaults를 사용
  - single cardio template는 기존 cardio start sheet 유지

### Step 3: Apply template defaults in session/transition UI

- **Files**: `DUNE/Presentation/Exercise/WorkoutSessionView.swift`, `DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift`, `DUNE/Presentation/Exercise/Components/ExerciseTransitionView.swift`, `DUNETests/WorkoutSessionViewModelTests.swift`
- **Changes**:
  - template entry defaults 적용 helper 추가
  - cardio/non-strength에서 reps/weight 기본값이 새지 않도록 guard
  - transition summary에서 cardio input label 사용
- **Verification**:
  - strength template defaults는 session에 반영됨
  - cardio template defaults는 reps/weight leak 없이 유지
  - new/updated unit tests 통과

## Edge Cases

| Case | Handling |
|------|----------|
| legacy template entry가 custom exercise를 가리키지만 library에 없음 | `customExercises`에서 `custom-{UUID}` 매칭으로 복원 |
| legacy cardio template가 이미 `defaultReps=10`을 저장함 | profile-aware UI/session helper가 해당 값을 무시해 strength UI leakage 차단 |
| single-entry cardio template | template defaults는 무시하고 기존 cardio live start sheet 유지 |
| multi-entry template에 cardio 포함 | 이번 변경에서는 editor/preview 오표시를 제거하지만, full sequential cardio orchestration은 후속 범위로 남김 |

## Testing Strategy

- Unit tests: `TemplateExerciseResolverTests`, `WorkoutSessionViewModelTests`
- Integration tests: 없음 (SwiftUI view 구조 변경은 unit-level helper 검증으로 대체)
- Manual verification:
  - iPhone 템플릿 생성 화면에서 Stair Climber/Running/custom cardio 확인
  - single strength template 시작 시 default sets/reps/weight 반영 확인
  - single cardio template 시작 시 cardio start sheet 유지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| template start flow 상태 변경으로 일반 quick start가 깨질 위험 | medium | high | `ExerciseView` state 변경을 template/non-template 공용 config로 통일하고 manual 확인 |
| custom exercise ID 매칭 누락 | medium | medium | `custom-{UUID}` exact match unit test 추가 |
| multi-entry cardio template 기대 동작 불일치 | high | medium | 이번 변경 범위를 명시적으로 문서화하고 residual risk로 기록 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: create/edit 오표시와 custom resolution bug는 명확하지만, multi-entry cardio template 전체 orchestration은 이번 수정으로 완전히 해결되지 않는다.
