---
tags: [watch, inputType, durationIntensity, plank, MetricsView, SetInputSheet]
date: 2026-03-28
category: plan
status: approved
---

# Watch 운동 세션 inputType-aware 입력 UI

## Problem

Watch MetricsView와 SetInputSheet가 모든 운동에 weight+reps 입력을 하드코딩.
Plank 등 durationIntensity 운동도 "kg × reps"로 표시되어 무게 입력이 강제됨.

- exercises.json의 plank inputType은 `durationIntensity`로 이미 수정됨 (PR #641)
- iOS 측은 `WorkoutSessionView`에서 inputType별 분기 완료
- **Watch 측만** inputType 미반영 → 이 수정의 대상

## Root Cause

1. `MetricsView.inputCard` — "kg × reps" 하드코딩 (inputType 무시)
2. `SetInputSheet` — weight + reps 입력만 지원
3. `CompletedSetData` — `duration` 필드 없음
4. `SessionSummaryView` — `WatchSetData.duration` 항상 nil 전달

## Affected Files

| File | Change |
|------|--------|
| `DUNEWatch/Managers/WorkoutManager.swift` | `CompletedSetData`에 `duration` 필드 추가, `completeSet`에 duration 파라미터 추가 |
| `DUNEWatch/Views/MetricsView.swift` | inputType 분기: inputCard/prefill/completeSet 호출을 inputType별로 분기 |
| `DUNEWatch/Views/SetInputSheet.swift` | inputType 파라미터 추가: durationIntensity 시 MINUTES 입력, setsReps 시 reps만 표시 |
| `DUNEWatch/Views/SessionSummaryView.swift` | `CompletedSetData.duration` → `WatchSetData.duration` 전달 |

## Implementation Steps

### Step 1: CompletedSetData에 duration 추가

`WorkoutManager.swift`의 `CompletedSetData`에 `duration: TimeInterval?` 필드 추가.
`completeSet()` 메서드에 `duration: TimeInterval?` 파라미터 추가.
기존 호출부(MetricsView)는 nil로 전달하여 backward compatible.

### Step 2: SetInputSheet inputType 분기

`SetInputSheet`에 `inputType: ExerciseInputType` 파라미터 추가 (default: `.setsRepsWeight`).
- `.setsRepsWeight`: 기존 동작 유지 (weight + reps)
- `.setsReps`: weight 섹션 숨김, reps만 표시
- `.durationIntensity`: weight/reps 대신 MINUTES 스테퍼 표시
  - `@Binding var duration: Int` 추가
  - Digital Crown으로 분 단위 조절 (0~120)
  - 기존 weight/reps binding은 inputType에 따라 조건부 사용

### Step 3: MetricsView inputType 인식

`MetricsView`에서 `workoutManager.currentEntry?.inputTypeRaw`로 현재 운동의 inputType 확인.
- `inputCard`: inputType별 표시 (kg×reps vs MIN)
- `prefillFromEntry()`: durationIntensity는 weight 대신 duration 초기값 설정
- `completeSet()`: durationIntensity는 duration으로 전달
- `SetInputSheet` 호출 시 적절한 바인딩 전달

### Step 4: SessionSummaryView duration 전달

`sendWorkoutToPhone()`에서 `CompletedSetData.duration`을 `WatchSetData.duration`으로 전달.

## inputType 해석

`TemplateEntry.inputTypeRaw`는 String?이므로 Watch에서 `ExerciseInputType`으로 변환 필요.
`ExerciseInputType(rawValue:)` 사용. nil/unknown → `.setsRepsWeight` fallback.

## Test Strategy

- 기존 `WatchExerciseInfoHashableTests` — inputType 관련 아님, 변경 불필요
- 빌드 검증: iOS + Watch 빌드 통과 확인
- 기능 검증: exercises.json의 plank 5개가 Watch에서 MINUTES 입력으로 표시되는지 확인

## Risks & Edge Cases

1. **기존 Watch 운동 데이터**: `CompletedSetData`에 optional field 추가이므로 기존 데이터에 영향 없음
2. **ExerciseInputType import**: Watch 타겟에서 이미 `ExerciseInputType`이 접근 가능한지 확인 필요 (Domain 모델이므로 Shared)
3. **Cardio(durationDistance)는 별도 UI**: 기존 cardio 경로는 이미 `CardioSessionView`로 분리됨 — strength template 세션만 수정 대상
4. **setsReps(bodyweight) 추가 개선**: weight 섹션 숨기기는 이번에 함께 처리 (scope 범위)
