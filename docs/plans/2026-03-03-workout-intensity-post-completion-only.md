---
topic: workout-intensity-post-completion-only
date: 2026-03-03
status: implemented
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-02-workout-manual-intensity-all-input-types.md
related_brainstorms:
  - docs/brainstorms/2026-03-02-workout-intensity-redesign.md
---

# Implementation Plan: Workout Intensity Post-Completion Only

## Context

세트 입력 단계에서 강도(intensity)를 받으면, 사용자가 실제 운동 완료 전 체감 난이도를 추정 입력해야 하는 UX 문제가 발생한다.
요구사항은 강도를 운동 중 입력값이 아닌, 운동이 끝난 뒤 사용자 체감(Effort 1-10)으로만 평가하도록 통일하는 것이다.

## Requirements

### Functional

- 모든 세트 입력 화면(단일 운동/컴파운드)에서 세트 단위 강도 입력 UI를 제거한다.
- 세트 저장 시 `WorkoutSet.intensity`는 입력되지 않도록 한다.
- 강도 평가는 운동 종료 시트(`WorkoutCompletionSheet`)에서만 수행한다.
- 기존 종료 후 Effort 저장(`ExerciseRecord.rpe`) 흐름은 유지한다.

### Non-functional

- 기존 자동 강도 계산(`autoIntensityRaw`) 및 추천(`suggestEffort`) 로직과 충돌 없이 동작해야 한다.
- 기존 입력 타입별 검증 규칙(중량/반복/시간/거리)은 유지해야 한다.
- 회귀 테스트를 통해 세트 강도 미저장 동작을 보장해야 한다.

## Approach

세트 편집 모델/검증/프리필에서 intensity 경로를 제거하고, UI에서는 input type 공통으로 intensity 입력 컴포넌트를 삭제한다.
저장은 기존처럼 완료된 세트를 `WorkoutSet`으로 변환하되 `intensity`를 항상 `nil`로 기록한다.
운동 후 강도 평가는 `WorkoutCompletionSheet`의 Effort 선택값을 `ExerciseRecord.rpe`로 반영하는 기존 구조를 유지한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 세트 강도 UI를 숨기고 데이터 모델/검증은 유지 | 구현량이 적음 | 코드 경로가 남아 회귀 가능성 높음 | 기각 |
| 세트 강도 필드를 전면 삭제(도메인 모델 변경) | 개념 단순화 | 마이그레이션/과거 데이터 호환 리스크 | 기각 |
| 세트 입력 경로만 제거하고 종료 Effort 단일화 | 요구사항 직접 충족, 리스크 낮음 | 과거 set intensity 데이터는 읽기 전용으로 남음 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | update | 단일 운동 입력 UI에서 intensity 섹션 제거, 세트 프리필에서 intensity 제외 |
| `DUNE/Presentation/Exercise/Components/SetRowView.swift` | update | 컴파운드 세트 행의 input type별 intensity 필드 제거 |
| `DUNE/Presentation/Exercise/CompoundWorkoutView.swift` | update | 컴파운드 테이블 헤더의 INT 칼럼 제거 |
| `DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift` | update | editable/draft/previous set intensity 제거, 검증/저장 경로 정리 |
| `DUNETests/WorkoutSessionViewModelTests.swift` | update | intensity 의존 테스트 제거/치환, 세트 intensity nil 저장 회귀 테스트 추가 |

## Implementation Steps

### Step 1: 세트 입력 UI에서 intensity 제거

- **Files**: `WorkoutSessionView.swift`, `SetRowView.swift`, `CompoundWorkoutView.swift`
- **Changes**:
  - 단일 세션 input type 빌더에서 INTENSITY 영역 삭제
  - 컴파운드 set row intensity 텍스트필드 삭제
  - 컴파운드 헤더 INT 컬럼 삭제
- **Verification**: 단일/컴파운드 화면에서 세트 입력 중 강도 UI가 노출되지 않음

### Step 2: ViewModel 데이터 경로 정리

- **Files**: `WorkoutSessionViewModel.swift`
- **Changes**:
  - `EditableSet`, `PreviousSetInfo`, `WorkoutSessionDraft.DraftSet`에서 intensity 제거
  - previous/fill/repeat/addSet 복사 로직에서 intensity 제거
  - `createValidatedRecord` intensity 검증 제거 + `WorkoutSet.intensity = nil` 고정
- **Verification**: 세트 저장 시 intensity가 항상 nil이며 기존 검증 규칙은 유지됨

### Step 3: 테스트 갱신 및 회귀 보강

- **Files**: `WorkoutSessionViewModelTests.swift`
- **Changes**:
  - intensity 프리필/검증 테스트를 core field 중심 테스트로 대체
  - rounds-based 저장 시 per-set intensity nil 확인 테스트 유지
- **Verification**: 관련 테스트 빌드 통과 및 핵심 시나리오 회귀 없음

## Edge Cases

| Case | Handling |
|------|----------|
| 과거 데이터에 `WorkoutSet.intensity`가 존재 | 읽기 시 허용, 신규 저장에서는 nil 유지 |
| durationIntensity 타입 명칭 혼선 | 세트 intensity 입력 제거하되 duration 입력은 유지 |
| 종료 시 Effort 미선택 | 기존대로 optional 처리(`rpe` nil 허용) |

## Testing Strategy

- Unit tests: `WorkoutSessionViewModelTests` 회귀 갱신
- Integration tests: `xcodebuild build` + 가능한 범위의 `xcodebuild test`
- Manual verification:
  - 단일 운동 세트 입력 화면에서 intensity 입력이 없음
  - 컴파운드 세트 행/헤더에 intensity 입력이 없음
  - 운동 완료 시트에서만 Effort(1-10) 선택 가능

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 기존 intensity 기반 테스트/로직 누락 | medium | medium | 관련 테스트 갱신 + rg로 참조 경로 확인 |
| UI 텍스트/컬럼 불일치 | low | low | set row와 column header 동시 수정 |
| 종료 Effort 경로 회귀 | low | medium | `WorkoutCompletionSheet` onDismiss 경로 유지 확인 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 요구사항이 명확하고 영향 범위가 세트 입력 UI/ViewModel로 국한되며, 종료 후 Effort 저장 경로는 이미 안정적으로 분리되어 있다.
