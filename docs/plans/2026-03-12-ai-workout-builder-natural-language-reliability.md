---
topic: ai-workout-builder-natural-language-reliability
date: 2026-03-12
status: draft
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-09-natural-language-workout-template-generation.md
  - docs/solutions/general/2026-03-09-natural-language-workout-template-failure-debugging.md
  - docs/solutions/architecture/2026-03-09-foundation-models-integration-pattern.md
related_brainstorms:
  - docs/brainstorms/2026-03-12-ai-workout-builder-prompt-reliability.md
---

# Implementation Plan: AI Workout Builder Natural-Language Reliability

## Context

AI 운동 빌더는 현재 Foundation Models + tool calling 구조는 갖추고 있지만, 초보자형 자연어 프롬프트 성공률이 낮다. 대표 증상은 `"어깨 운동 만들어줘"` 같은 generic Korean request가 `"We couldn't turn that request into a workout yet."`로 귀결되는 것이다.

기존 구조를 전면 교체할 필요는 없다. 현재 병목은 다음 두 군데에 집중되어 있다.

- `SearchExerciseTool`이 exercise name / localizedName / aliases substring match 중심이라 broad intent query에 약함
- `TemplateFormView`가 실패를 `noExercisesMatched` 중심의 generic message로만 노출해 사용자가 왜 실패했는지 알기 어렵다

이번 변경은 온디바이스-only 제약을 유지하면서, 초보자 자연어 요청을 현재 템플릿 생성 파이프라인 안에서 더 잘 수용하도록 개선한다.

## Requirements

### Functional

- `"어깨 운동 만들어줘"`, `"집에서 덤벨로 상체"`, `"러닝 전에 할 코어 운동"` 같은 한국어 자연어 프롬프트 성공률을 높인다.
- search tool이 broad beginner prompt에서 muscle / equipment / category 신호를 읽고 template-capable 후보를 반환할 수 있어야 한다.
- unsupported template type(HIIT-only, mobility-only 등)는 계속 차단한다.
- 생성 실패 시 이유와 다시 시도할 예시를 더 구체적으로 보여준다.
- 현재 `NaturalLanguageWorkoutGenerating` 계약과 `GeneratedWorkoutTemplate` 모델은 최대한 유지한다.

### Non-functional

- `FoundationModels` import는 계속 Data layer에만 둔다.
- 저장 스키마 allowlist(`.setsRepsWeight`, `.setsReps`, `.durationDistance`)는 유지한다.
- 새 로직은 Swift Testing으로 회귀 테스트를 추가한다.
- 새 사용자 대면 문구는 `Shared/Resources/Localizable.xcstrings`에 en/ko/ja로 추가한다.
- detached HEAD 상태에서는 Work phase에서 feature branch를 생성한다.

## Approach

핵심 접근은 **모델을 더 똑똑하게 기대하는 대신, search tool을 자연어 친화적으로 확장**하는 것이다.

1. `AIWorkoutTemplateGenerator`에 beginner prompt 해석용 helper를 추가한다.
2. `SearchExerciseTool`이 broad query를 그대로 substring search 하지 않고, 다음 신호를 조합해 candidate pool을 만든다.
   - normalized label match
   - Korean/English muscle synonym mapping
   - equipment intent mapping
   - cardio / bodyweight / strength category intent
   - fuzzy token overlap scoring
3. search 결과는 기존처럼 template-capable exercise만 반환한다.
4. generator instructions를 조정해 broad request일 때 muscle/equipment concept 단위로 tool query를 나누도록 유도한다.
5. `WorkoutTemplateGenerationError`를 세분화해 unsupported/ambiguous/no-match failure를 나눠 UI copy를 개선한다.
6. regression tests로 Korean generic prompt, unsupported request, failure messaging을 고정한다.

이 접근은 Domain 계약을 흔들지 않으면서도 가장 큰 병목인 catalog retrieval recall을 직접 개선한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 새 interpretation schema를 Domain 모델로 추가하고 2-stage generation 도입 | 장기적으로 가장 깔끔함 | 스키마/프롬프트/UI 전체 범위가 커짐 | Deferred |
| SearchExerciseTool + helper 확장, 기존 response schema 유지 | 영향 범위가 좁고 성공률 개선 효과가 큼 | heuristic table 관리 필요 | Chosen |
| 실패 메시지만 개선 | 구현이 가장 작음 | 실제 성공률은 거의 안 오름 | Rejected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Services/AIWorkoutTemplateGenerator.swift` | Edit | 자연어 친화 search expansion, prompt/instruction refinement, failure taxonomy helper 추가 |
| `DUNE/Domain/Protocols/NaturalLanguageWorkoutGenerating.swift` | Edit | generation error case 확장 |
| `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift` | Edit | error-to-copy mapping과 retry guidance 개선 |
| `DUNETests/AIWorkoutTemplateGeneratorTests.swift` | Edit | Korean generic prompt recall, unsupported request, search ranking 회귀 테스트 추가 |
| `Shared/Resources/Localizable.xcstrings` | Edit | 새 failure/retry strings 등록 |

## Implementation Steps

### Step 1: Expand failure taxonomy and natural-language search helpers

- **Files**: `DUNE/Domain/Protocols/NaturalLanguageWorkoutGenerating.swift`, `DUNE/Data/Services/AIWorkoutTemplateGenerator.swift`
- **Changes**:
  - `WorkoutTemplateGenerationError`에 broad request/unsupported request를 구분할 case를 추가한다.
  - generator 내부에 normalized token parsing, muscle/equipment/category inference, fuzzy score helper를 추가한다.
  - broad query에서도 template-capable candidate를 반환하는 deterministic expansion path를 만든다.
- **Verification**:
  - `AIWorkoutTemplateGeneratorTests`에서 Korean generic prompt가 candidate를 찾는지 확인
  - unsupported category-only query가 여전히 차단되는지 확인

### Step 2: Refine search tool output and generator instructions

- **Files**: `DUNE/Data/Services/AIWorkoutTemplateGenerator.swift`
- **Changes**:
  - tool description/instructions에 concept-based search 예시를 추가한다.
  - broad query일 때 muscle/equipment/cardio intent를 이용해 ranked candidates를 반환한다.
  - exact match가 부족해도 fuzzy overlap으로 대표 exercise를 안정적으로 찾도록 정렬한다.
- **Verification**:
  - Korean prompt 기반 tool output이 empty가 아닌지 테스트
  - unsupported HIIT/flexibility input type는 여전히 제외되는지 테스트

### Step 3: Improve UI failure copy and retry guidance

- **Files**: `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift`, `Shared/Resources/Localizable.xcstrings`
- **Changes**:
  - error case별로 reason-specific localized copy를 분기한다.
  - 실패 시 retry examples를 포함한 helper text를 보여준다.
  - AI prompt placeholder/helper copy를 실제 지원 범위에 맞게 조정한다.
- **Verification**:
  - localization rule 기준으로 새 문자열이 `String(localized:)` 또는 SwiftUI localized key 경로를 따르는지 확인
  - xcstrings에 en/ko/ja가 모두 등록되었는지 확인

### Step 4: Lock regression coverage and run project validation

- **Files**: `DUNETests/AIWorkoutTemplateGeneratorTests.swift`
- **Changes**:
  - beginner 자연어 프롬프트 세트 일부를 unit test로 고정한다.
  - unsupported request와 failure classification을 테스트한다.
- **Verification**:
  - targeted unit tests 실행
  - `scripts/build-ios.sh` 실행

## Edge Cases

| Case | Handling |
|------|----------|
| `"어깨 운동 만들어줘"`처럼 broad muscle-only 요청 | shoulder-related template-capable candidate expansion 사용 |
| `"집에서 맨몸 상체"`처럼 equipment + region 조합 | bodyweight 우선 후보만 남기고 상체 관련 muscle group으로 정렬 |
| `"러닝 전에 할 코어"`처럼 goal text가 섞인 요청 | goal token은 search ranking 보조 정보로만 쓰고 core candidate를 우선 |
| HIIT-only / mobility-only 요청 | unsupported request로 분류하고 retry examples 제시 |
| query가 너무 추상적임 (`"좋은 운동 만들어줘"`) | ambiguous request로 분류하고 더 구체적인 예시 제시 |
| cardio/time-based 요청 | 기존 allowlist 안에서 `.durationDistance` exercise만 유지 |
| detached HEAD | Work phase에서 `codex/` prefix feature branch 생성 |

## Testing Strategy

- Unit tests:
  - `AIWorkoutTemplateGeneratorTests`에 Korean generic prompt search recall 테스트 추가
  - unsupported request 분류 테스트 추가
  - existing unsupported input-type rejection 회귀 유지
- Integration tests:
  - `scripts/build-ios.sh`
  - 가능하면 targeted `swift test` 또는 기존 test runner로 generator test 실행
- Manual verification:
  - 실기기/지원 기기에서 `"어깨 운동 만들어줘"` 입력
  - 실패 시 reason + retry example 노출 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| heuristic synonym table이 너무 좁아 일부 자연어를 여전히 놓침 | Medium | Medium | 초보자 대표 prompt 세트를 테스트로 고정하고 synonym을 최소 고효율 집합으로 시작 |
| fuzzy matching이 너무 넓어 잘못된 exercise를 추천함 | Medium | High | template-capable allowlist + score threshold + exact label 우선순위 유지 |
| localization 문자열 추가 과정에서 orphan/leak 발생 | Medium | Medium | localization rule 체크리스트 기준으로 새 문자열 추가/검증 |
| build/test가 기존 unrelated failure에 막힘 | Medium | Medium | 변경 범위와 무관한 blocker는 명시적으로 분리 기록 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 아키텍처를 유지한 채 retrieval recall과 failure UX만 강화하는 범위라서 구현 경로가 명확하다. 리스크는 heuristic tuning과 localization 누락 정도로 제한적이다.
