---
topic: activity-ai-workout-builder-entry
date: 2026-03-12
status: implemented
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-07-activity-inline-quick-start.md
  - docs/solutions/architecture/2026-03-07-activity-section-consolidation.md
  - docs/solutions/architecture/2026-03-09-natural-language-workout-template-generation.md
related_brainstorms: []
---

# Implementation Plan: Restore Activity AI Workout Builder Entry

## Context

Activity 탭의 `Suggested Workout` 섹션에는 검색, 추천 루틴, 저장된 템플릿 strip는 남아 있지만
자연어 운동 생성 UI가 들어 있는 `TemplateFormView`로 이동하는 진입점이 없다.
`AI Workout Builder`는 0.3.0 What's New에서 `activity` 영역 기능으로 노출되고 있으므로,
현재 상태는 기능 삭제라기보다 Activity 정보구조에서 entry가 끊긴 회귀에 가깝다.

## Requirements

### Functional

- Activity 탭에서 자연어 운동 생성 화면(`TemplateFormView`)으로 다시 진입할 수 있어야 한다.
- 기존 `Suggested Workout` 검색, 추천 루틴 시작, 저장된 템플릿 시작 플로우를 깨뜨리지 않아야 한다.
- 진입 후 AI prompt 필드가 보이는 create mode가 열려야 한다.

### Non-functional

- 기존 Activity/Exercise 패턴을 유지하고 과한 새 네비게이션 구조를 만들지 않는다.
- UI 테스트로 Activity entry 복귀를 고정한다.
- localization leak 없이 기존 string catalog 키를 재사용하거나 필요한 경우만 추가한다.

## Approach

`SuggestedWorkoutSection` 하단에 Activity 전용 `AI Workout Builder` CTA를 추가하고,
`ActivityView`가 `TemplateFormView()` sheet를 직접 띄우게 한다.
이 접근은 자연어 생성 화면을 가장 짧은 경로로 복원하면서,
Exercise 탭의 template list / create flow와도 충돌하지 않는다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Activity에서 `TemplateFormView()` 직접 sheet presentation | 가장 짧게 자연어 생성 화면 복원, 구현 범위 작음 | Activity에 sheet state 1개 추가 필요 | Selected |
| Activity에서 `WorkoutTemplateListView`로 push 후 plus 버튼으로 생성 | 기존 템플릿 IA 재사용 | 사용자가 2단계 더 거쳐야 해서 "사라짐" 체감 해소가 약함 | Rejected |
| `All Exercises` 버튼 동작을 template/form 허브로 변경 | 버튼 수 증가 없음 | 기존 quick start 의미를 깨고 회귀 위험이 큼 | Rejected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-12-activity-ai-workout-builder-entry.md` | add | 이번 수정 계획서 |
| `DUNE/Presentation/Activity/ActivityView.swift` | update | AI builder sheet state/presentation 추가 |
| `DUNE/Presentation/Activity/Components/SuggestedWorkoutSection.swift` | update | Activity AI builder CTA 추가 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | update | 새 Activity CTA / template AI field selector 추가 |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | update | Activity entry -> template form 회귀 테스트 추가 |

## Implementation Steps

### Step 1: Activity entry 복원

- **Files**: `DUNE/Presentation/Activity/ActivityView.swift`, `DUNE/Presentation/Activity/Components/SuggestedWorkoutSection.swift`
- **Changes**:
  - `SuggestedWorkoutSection`에 `AI Workout Builder` CTA와 callback을 추가한다.
  - `ActivityView`에 sheet state를 추가하고 `TemplateFormView()`를 present한다.
  - CTA는 기존 `All Exercises`와 같은 섹션 맥락 안에 두되, 자연어 생성 entry임이 명확히 드러나게 한다.
- **Verification**:
  - Activity 탭의 Suggested Workout 섹션에서 CTA가 보인다.
  - CTA 탭 시 `TemplateFormView` create mode가 열린다.

### Step 2: UI regression 고정

- **Files**: `DUNEUITests/Helpers/UITestHelpers.swift`, `DUNEUITests/Full/ActivityExerciseRegressionTests.swift`
- **Changes**:
  - Activity AI builder CTA와 template AI prompt/generate selector를 AXID 상수에 추가한다.
  - seeded Activity regression test에서 CTA 탭 후 `TemplateFormView` + AI prompt 필드 존재를 확인한다.
- **Verification**:
  - Activity regression test가 새 entry를 탐색한다.
  - 기존 template list / recommendation / picker 관련 테스트와 selector contract가 충돌하지 않는다.

## Edge Cases

| Case | Handling |
|------|----------|
| Apple Intelligence 미지원 기기 | `TemplateFormView`는 열리되 내부 안내 문구와 disabled generate 버튼으로 graceful degrade |
| 저장된 템플릿이 없어도 CTA는 보여야 함 | CTA는 template strip 존재 여부와 무관하게 항상 노출 |
| search text 입력 중 CTA가 가려짐 | CTA는 검색 비활성 상태 블록에만 노출해 현재 구조와 충돌하지 않게 유지 |

## Testing Strategy

- Unit tests: 없음. 이번 범위는 UI entry 복원이다.
- Integration tests:
  - `scripts/test-ui.sh --test-plan DUNEUITests-Full --only-testing DUNEUITests/Full/ActivityExerciseRegressionTests`
- Manual verification:
  - Activity 탭 진입
  - Suggested Workout 섹션에서 `AI Workout Builder` CTA 확인
  - 탭 후 `TemplateFormView`와 AI prompt field 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Suggested Workout 섹션 하단 CTA가 과밀해 보일 수 있음 | Medium | Low | 기존 link/button 톤과 맞춘 compact CTA로 배치 |
| 새 sheet가 기존 Activity modal들과 충돌 | Low | Medium | 독립 state 사용, 기존 picker/template/fullScreenCover와 분리 |
| UI 테스트가 seeded 스크롤 위치에 민감 | Medium | Low | 기존 Activity seeded regression helper + AXID 기반 탐색 재사용 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: root cause가 "기능 구현 누락"이 아니라 "Activity entry 누락"으로 명확하고, 복원 범위도 Activity presentation 계층에 국한되어 있어 회귀 범위를 작게 유지할 수 있다.
