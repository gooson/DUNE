---
tags: [workout, intensity, effort, post-completion, swiftui, viewmodel]
category: general
date: 2026-03-03
severity: important
related_files:
  - DUNE/Presentation/Exercise/WorkoutSessionView.swift
  - DUNE/Presentation/Exercise/Components/SetRowView.swift
  - DUNE/Presentation/Exercise/CompoundWorkoutView.swift
  - DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift
  - DUNETests/WorkoutSessionViewModelTests.swift
related_solutions:
  - docs/solutions/general/2026-03-02-workout-manual-intensity-all-input-types.md
---

# Solution: Workout Intensity Input Restricted to Post-Completion Evaluation

## Problem

운동 세트 입력 단계에서 강도(intensity)를 받는 구조 때문에, 사용자가 실제 운동 체감 이전에 강도를 입력해야 하는 UX 불일치가 발생했다.
요구사항은 강도를 세트 입력값이 아닌 운동 완료 후 평가(Effort)로만 받는 것이다.

### Symptoms

- 단일 운동 세션 입력 화면에 `INTENSITY` 스테퍼가 표시됨
- 컴파운드 세트 행과 헤더에 `INT` 칼럼/입력칸이 표시됨
- ViewModel 검증/저장 경로가 세트 intensity 입력을 허용함

### Root Cause

기존 확장 작업에서 `WorkoutSet.intensity`를 모든 input type 입력 UI까지 확장하면서, “세트 입력”과 “운동 완료 후 체감 평가” 개념이 혼합되었다.
그 결과 UI, draft, prefill, validation, persistence에 세트 intensity 경로가 남아 있었다.

## Solution

세트 입력 경로의 intensity를 전면 제거하고, 강도 평가는 `WorkoutCompletionSheet`의 Effort(`rpe`) 경로만 사용하도록 정리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `WorkoutSessionView.swift` | 모든 input type에서 INTENSITY 섹션 제거, prefill intensity 복사 제거 | 세트 입력 단계 강도 입력 금지 |
| `SetRowView.swift` | 모든 input type set row의 `1-10` intensity 텍스트필드 제거 | 컴파운드 입력 단계 강도 입력 금지 |
| `CompoundWorkoutView.swift` | 컬럼 헤더 `INT` 제거 | UI 헤더/필드 정합성 유지 |
| `WorkoutSessionViewModel.swift` | `EditableSet/PreviousSetInfo/DraftSet` intensity 제거, 검증/저장에서 intensity 경로 제거, `WorkoutSet.intensity = nil` 고정 | 저장 모델 일관성 확보 |
| `WorkoutSessionViewModelTests.swift` | intensity 의존 테스트 제거/치환, rounds-based 저장 시 intensity nil 검증 추가 | 회귀 방지 |

### Key Code

```swift
let workoutSet = WorkoutSet(
    setNumber: editableSet.setNumber,
    setType: editableSet.setType,
    weight: weightKg,
    reps: repsValue,
    duration: durationSeconds,
    distance: distanceKm,
    intensity: nil,
    isCompleted: true
)
```

## Prevention

세트 입력 UX와 운동 완료 평가 UX를 분리해서 리뷰 체크리스트로 고정한다.

### Checklist Addition

- [ ] 세트 입력 단계에 체감 강도(Effort/RPE) 입력 UI가 추가되지 않았는지 확인
- [ ] 강도 저장 경로가 `WorkoutCompletionSheet` → `ExerciseRecord.rpe`로만 이어지는지 확인
- [ ] `WorkoutSet.intensity`가 신규 세션 저장에서 다시 사용되지 않는지 테스트로 검증

### Rule Addition (if applicable)

새 규칙 파일 추가는 불필요. 기존 `input-validation.md`, `testing-required.md` 규칙 범위에서 관리 가능하다.

## Lessons Learned

강도처럼 “운동 결과를 회고하는 값”은 세트 입력 데이터와 분리해야 UX/데이터 의미가 안정된다.
입력 UI 변경 시에는 View, ViewModel, Draft, Validation, Test를 동시에 점검해야 요구사항 역행을 막을 수 있다.
