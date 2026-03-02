---
topic: Workout Manual Intensity for All Input Types
date: 2026-03-02
status: draft
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-02-28-auto-workout-intensity-patterns.md
related_brainstorms:
  - docs/brainstorms/2026-02-28-auto-workout-intensity.md
---

# Implementation Plan: Workout Manual Intensity for All Input Types

## Context

현재 세트 단위 수동 강도(`intensity`, 1-10) 입력 UI가 `durationIntensity`에만 노출되어, 사용자가 원하는 "모든 운동에서 강도 입력" 요구를 충족하지 못한다.
데이터 모델(`WorkoutSet.intensity`)과 저장 경로는 이미 공통 필드로 존재하므로, UI/검증/프리필 범위를 모든 input type으로 확장하는 방식이 가장 안전하다.

## Requirements

### Functional

- 모든 운동 input type (`setsRepsWeight`, `setsReps`, `durationDistance`, `durationIntensity`, `roundsBased`)에서 세트 강도(1-10) 입력 가능
- 단일 운동 세션 화면과 컴파운드 세트 행 화면 모두에서 강도 입력 필드 노출
- 저장 시 `WorkoutSet.intensity`에 동일하게 반영
- 강도 입력값은 1-10 범위 검증 유지

### Non-functional

- 기존 입력 흐름(무게/횟수/시간/거리/라운드) 동작 회귀 없음
- 기존 자동 강도 산출(`autoIntensityRaw`) 로직과 충돌 없음
- 테스트로 검증 로직 회귀 방지

## Approach

UI 노출 범위를 확장하되, 데이터 모델을 변경하지 않고 `WorkoutSessionViewModel`의 intensity 검증을 input type 독립 로직으로 통합한다.
`SetRowView`와 `CompoundWorkoutView` 헤더를 함께 맞춰 컴파운드 플로우에서도 동일한 일관성을 보장한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존처럼 `durationIntensity`만 유지 | 영향 범위 작음 | 사용자 요구 미충족 | 기각 |
| 새 공통 "운동 강도" 필드를 모델에 추가 | 의미 분리 가능 | 마이그레이션/중복 데이터 리스크 | 기각 |
| 기존 `WorkoutSet.intensity`를 모든 타입으로 확장 사용 | 마이그레이션 없음, 구현 단순 | 기존 UI 레이아웃 수정 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNE/Presentation/Exercise/WorkoutSessionView.swift | update | 모든 input type 입력 UI에 INTENSITY 필드 추가 |
| DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift | update | intensity 검증 공통화 + previous set intensity 프리필 |
| DUNE/Presentation/Exercise/Components/SetRowView.swift | update | 모든 input type row에서 intensity 텍스트필드 노출 |
| DUNE/Presentation/Exercise/CompoundWorkoutView.swift | update | 컬럼 헤더에 intensity 칼럼 추가 |
| DUNETests/WorkoutSessionViewModelTests.swift | update | 비-durationIntensity 타입의 intensity 검증/저장 테스트 추가 |

## Implementation Steps

### Step 1: Single Session UI 확장

- **Files**: `WorkoutSessionView.swift`
- **Changes**:
  - `weightRepsInput`, `repsOnlyInput`, `durationDistanceInput`, `roundsBasedInput`에 `INTENSITY` stepper 섹션 추가
  - 기존 `durationIntensityInput`은 유지하되 공통 패턴으로 정렬
- **Verification**:
  - 각 input type에서 현재 세트 화면에 `INTENSITY` 입력이 노출되는지 확인

### Step 2: Compound UI 정합성 맞춤

- **Files**: `SetRowView.swift`, `CompoundWorkoutView.swift`
- **Changes**:
  - 각 input type row에 `intensity` 필드 추가
  - 컬럼 헤더에 `INT` 라벨 추가
- **Verification**:
  - 컴파운드 편집 행에서 타입별로 강도 칸이 표시되고 입력 가능한지 확인

### Step 3: ViewModel 검증/프리필 공통화

- **Files**: `WorkoutSessionViewModel.swift`
- **Changes**:
  - `loadPreviousSets`/`fillSetFromPrevious` 경로에 intensity 복사 추가
  - `createValidatedRecord`에서 intensity 범위 검증을 타입 조건 없이 공통 처리
- **Verification**:
  - 어떤 input type에서도 intensity=11 입력 시 validation error 발생
  - intensity=7 저장 시 `WorkoutSet.intensity == 7`

### Step 4: 테스트 보강

- **Files**: `WorkoutSessionViewModelTests.swift`
- **Changes**:
  - `setsRepsWeight`, `durationDistance`, `roundsBased`에서 intensity 검증/저장 테스트 추가
- **Verification**:
  - 추가 테스트 및 기존 테스트 모두 통과

## Edge Cases

| Case | Handling |
|------|----------|
| intensity 빈 입력 | optional로 허용 (nil 저장) |
| intensity 0/11 등 범위 밖 | `Intensity must be between 1 and 10` 에러 |
| 이전 세트 intensity 존재 | 새 세트/이전세션 프리필 시 복사 |
| durationDistance의 count/floors 같은 reps-기반 보조값 | 기존 reps/distance 검증 로직 유지, intensity는 독립 검증 |

## Testing Strategy

- Unit tests: `WorkoutSessionViewModelTests`에 intensity 공통 검증/저장 케이스 추가
- Integration tests: 없음 (기존 저장 경로 재사용)
- Manual verification:
  - Single Exercise: 각 input type에서 INTENSITY 입력 노출 확인
  - Compound: 행 편집에서 INT 칼럼 노출/입력 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| UI 가로 공간 부족(Compound row) | medium | medium | 필드 width 유지 + 헤더 라벨 축약(`INT`) |
| 기존 검증 흐름 회귀 | low | high | 기존 케이스 유지 + 신규 테스트 추가 |
| 자동 강도 산출과 의미 혼동 | medium | low | 기존 `WorkoutCompletionSheet` Effort 흐름은 변경하지 않음 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 데이터 모델은 이미 공통 intensity를 지원하고 있어 UI/검증 확장 중심 변경으로 리스크가 낮으며, 기존 테스트 파일에 직접 회귀 테스트를 추가할 수 있음.
