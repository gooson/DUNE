---
topic: 추천 루틴 탭 무반응 수정
date: 2026-03-08
status: draft
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-07-activity-inline-quick-start.md
  - docs/solutions/general/2026-03-08-orphaned-feature-wiring-audit.md
  - docs/solutions/testing/2026-03-08-e2e-phase3-activity-exercise-regression-hardening.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-recommended-workout-improvement.md
---

# Implementation Plan: 추천 루틴 탭 무반응 수정

## Context

Activity 탭의 `추천 루틴` 카드는 표시되지만 탭 시 어떤 액션도 연결되지 않아 시작 전환이 일어나지 않는다. 최근 감사 문서에서 추천 루틴 노출까지만 연결했고, 실제 시작 경로는 빠진 상태다.

## Requirements

### Functional

- `추천 루틴` 카드 탭 시 실제 시작 경로가 동작해야 한다.
- 단일 운동 추천은 `ExerciseStartView`로, 다중 시퀀스 추천은 템플릿 워크아웃 경로로 이어져야 한다.
- 추천 시퀀스가 exercise library와 매칭될 때만 안전하게 시작하고, 매칭이 실패하는 항목은 잘못된 운동으로 치환하지 않는다.
- 회귀 방지를 위해 탭 가능한 카드 surface를 테스트로 고정한다.

### Non-functional

- 기존 Activity quick start/template 시작 패턴을 재사용한다.
- 새 문자열 추가 없이 현재 localization 계약을 유지한다.
- 제스처 변경이므로 seeded/mock 기반 검증 경로를 남긴다.

## Approach

추천 루틴을 표시용 카드에서 실제 시작 가능한 ephemeral template로 승격한다.

1. `SuggestedWorkoutSection`에 추천 카드용 명시적 탭 액션과 accessibility identifier를 추가한다.
2. `TemplateExerciseResolver`에 추천 시퀀스(`WorkoutTemplateRecommendation`)를 exercise library의 visible exercise로 복원하는 helper를 추가한다.
3. `ActivityView`에서 추천 카드를 탭하면:
   - 1개 운동이면 기존 `selectedExercise` sheet를 사용
   - 2개 이상이면 `TemplateWorkoutConfig` + default `TemplateEntry`를 생성해 `TemplateWorkoutContainerView`를 연다
4. UI 테스트 시나리오에서 추천 루틴이 노출되도록 seeded workout fixture를 보강하고, 탭 후 시작 화면이 열리는 regression test를 추가한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 카드에 `Button`만 추가하고 액션은 나중에 연결 | 최소 diff | 사용자 문제 해결 안 됨 | 기각 |
| 추천 탭 시 항상 검색 picker로 보내기 | 구현 단순 | 추천 루틴의 원탭 시작 UX와 불일치 | 기각 |
| 추천 탭 시 library 매칭 후 ephemeral template 생성 | 기존 시작 경로 재사용, UX 일관성 | 이름 매칭 실패 케이스 처리 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Activity/Components/SuggestedWorkoutSection.swift` | modify | 추천 카드 버튼화, AXID 추가, 상위 액션 전달 |
| `DUNE/Presentation/Activity/ActivityView.swift` | modify | 추천 카드 시작 helper 추가, single/multi 경로 분기 |
| `DUNE/Presentation/Exercise/TemplateExerciseResolver.swift` | modify | 추천 시퀀스 → exercise/template entry 복원 helper 추가 |
| `DUNE/App/TestDataSeeder.swift` | modify | activity seeded 시나리오에 반복 workout summary fixture 추가 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | modify | 추천 루틴 카드 AXID 상수 추가 |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | modify | 추천 루틴 카드 탭 regression test 추가 |
| `DUNETests/TemplateExerciseResolverTests.swift` | modify | recommendation resolution unit test 추가 |

## Implementation Steps

### Step 1: 추천 루틴 탭 액션 surface 연결

- **Files**: `SuggestedWorkoutSection.swift`, `ActivityView.swift`
- **Changes**:
  - 추천 카드 렌더링을 `Button`으로 감싸고 AXID를 부여한다.
  - 상위에서 `onStartRecommendation` 클로저를 받아 시작 로직으로 연결한다.
- **Verification**: 추천 카드가 탭 가능 element로 노출되고 상위 액션이 호출된다.

### Step 2: 추천 시퀀스 복원 helper 추가

- **Files**: `TemplateExerciseResolver.swift`, `TemplateExerciseResolverTests.swift`
- **Changes**:
  - recommendation의 label/activityType 조합을 library exercise로 복원하는 helper 추가
  - 복원된 exercise로 default `TemplateEntry`를 생성하는 경로 구성
  - exact/canonical name match 우선, 필요한 최소 fallback만 허용
- **Verification**: cardio 단일 추천과 multi-sequence 추천이 올바른 exercise/order로 복원된다.

### Step 3: seeded regression 테스트 고정

- **Files**: `TestDataSeeder.swift`, `UITestHelpers.swift`, `ActivityExerciseRegressionTests.swift`
- **Changes**:
  - `activity-exercise-seeded` 시나리오에서 recommendation service가 결과를 만들 수 있는 workout summary fixture 추가
  - Activity UI test에서 추천 루틴 카드 탭 후 `ExerciseStartView` 또는 template container가 뜨는지 검증
- **Verification**: seeded UI test가 red 없이 통과한다.

## Edge Cases

| Case | Handling |
|------|----------|
| 추천 label이 library와 매칭되지 않음 | 해당 항목은 시작 config에서 제외하고, 결과가 0개면 액션을 중단한다 |
| recommendation이 1개 운동만 포함 | 기존 `selectedExercise` 경로 사용 |
| recommendation이 cardio 운동 포함 | `TemplateExerciseResolver.defaultEntry`를 사용해 cardio default set을 1로 유지 |
| 일부 sequence만 매칭됨 | 순서를 보존한 채 매칭된 exercise만 사용하되, 0개면 시작하지 않는다 |

## Testing Strategy

- Unit tests: `TemplateExerciseResolverTests`에 recommendation resolution 케이스 추가
- UI tests: `ActivityExerciseRegressionTests`에 추천 루틴 카드 탭 시작 경로 추가
- Manual verification: Activity seeded/mock 데이터에서 추천 루틴 카드 탭 후 시작 화면 노출 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| generic HealthKit title(`Strength`)가 특정 exercise로 복원되지 않음 | medium | medium | exact/canonical name 우선, 모호한 fallback 최소화 |
| UI test seed가 recommendation 조건을 만족하지 못함 | medium | medium | fixture를 3회 이상 반복 시퀀스로 명시 구성 |
| single-exercise recommendation이 generic quick start로 열리며 루틴 제목을 유지하지 못함 | low | low | 현재 UX에서는 실제 운동 시작이 우선이며, 후속 필요 시 dedicated start sheet 고려 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 카드 무반응의 직접 원인은 명확하다. 다만 recommendation 데이터를 실제 exercise로 복원하는 과정은 과거 로그 title 품질에 영향을 받으므로, exact/canonical match 우선 정책과 seeded 검증이 필요하다.
