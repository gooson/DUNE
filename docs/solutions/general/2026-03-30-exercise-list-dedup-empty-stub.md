---
tags: [dedup, exercise-list, healthkit, walking, cardio, empty-stub]
date: 2026-03-30
category: general
status: implemented
---

# Exercise 목록 빈 스텁 레코드 dedup 불일치

## Problem

Activity 탭의 "최근 운동"과 Exercise 탭의 운동 목록이 같은 걷기 운동에 대해 다른 데이터를 표시.

- Activity: 6분/25kcal/HR 92 (HealthKit WorkoutSummary)
- Exercise: 0분/칼로리 없음 (빈 ExerciseRecord 스텁)

**근본 원인**: 두 화면의 dedup 전략 불일치.
- Activity의 `ExerciseListSection`은 `hasSetData`인 레코드만 dedup 대상으로 사용 → 빈 스텁은 dedup에서 제외 → HealthKit 버전 노출
- Exercise의 `ExerciseViewModel`은 **모든** `manualRecords`로 dedup → 빈 스텁이 HealthKit 워크아웃을 숨김 → 빈 데이터 표시

## Solution

### 1. `ExerciseRecord.hasMeaningfulContent` 추가 (ExerciseRecord.swift)

```swift
var hasMeaningfulContent: Bool {
    hasSetData || duration > 0 || bestCalories != nil
}
```

### 2. `ExerciseViewModel.invalidateCache()` dedup 로직 수정

- dedup 필터에 `hasMeaningfulContent`인 레코드만 사용
- HealthKit 워크아웃이 표시될 때 연결된 빈 스텁은 목록에서 제외

### Changed Files

- `DUNE/Data/Persistence/Models/ExerciseRecord.swift`
- `DUNE/Presentation/Exercise/ExerciseViewModel.swift`
- `DUNETests/ExerciseViewModelTests.swift` (3개 테스트 추가)

## Prevention

- **Dedup 일관성 원칙**: 같은 데이터를 표시하는 두 화면은 동일한 dedup 기준을 사용해야 함
- **빈 스텁 경계**: HealthKit 연동 ExerciseRecord가 의미 있는 데이터를 갖지 못할 때는 HealthKit 버전에 양보
- 새 화면에서 운동 목록을 표시할 때 `hasMeaningfulContent` 기준을 먼저 확인

## Lessons Learned

- 같은 데이터를 다른 화면에서 표시할 때 dedup 전략이 달라지면 사용자에게 혼란을 줌
- Activity 탭이 이미 `hasSetData` 필터로 올바르게 처리하고 있었으므로, 같은 원칙을 Exercise 탭에도 적용하면 됨
