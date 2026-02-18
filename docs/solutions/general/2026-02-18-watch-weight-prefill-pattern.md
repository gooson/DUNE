---
tags: [watch, weight, prefill, workout, sets, ux]
date: 2026-02-18
category: general
status: implemented
---

# Watch Weight Pre-fill Pattern (Previous Set → Template Default)

## Problem

Apple Watch 운동 시 다음 세트로 넘어갈 때 weight/reps가 0으로 초기화되어 매번 재입력 필요.
Quick Start 시에는 machine default weight가 전혀 전달되지 않음.

## Solution

### Pre-fill 우선순위 체인

```swift
private func prefillFromEntry() {
    guard let entry = workoutManager.currentEntry else { return }

    // 1순위: 직전 완료 세트의 weight/reps
    if let lastSet = workoutManager.lastCompletedSetForCurrentExercise {
        weight = lastSet.weight ?? entry.defaultWeightKg ?? 0
        reps = lastSet.reps ?? entry.defaultReps
    } else {
        // 2순위: 템플릿 기본값
        weight = entry.defaultWeightKg ?? 0
        reps = entry.defaultReps
    }
}
```

### WorkoutManager computed property

```swift
var lastCompletedSetForCurrentExercise: CompletedSetData? {
    guard currentExerciseIndex < completedSetsData.count else { return nil }
    return completedSetsData[currentExerciseIndex].last  // O(1)
}
```

### 호출 시점

1. `.onAppear` — 운동 시작 시
2. `.onChange(of: currentExerciseIndex)` — 다음 운동으로 전환 시
3. `handleRestComplete()` — 휴식 타이머 완료 후 다음 세트

### WatchExerciseInfo에 defaultWeightKg 추가

iPhone ↔ Watch 간 `WatchExerciseInfo` DTO에 `defaultWeightKg: Double?` 필드 추가.
양쪽 target에 동일하게 적용 (향후 shared package로 통합 권장).

## Prevention

- 세트 간 전환 시 항상 `prefillFromEntry()` 호출
- `completedSetsData`는 session start 시 모든 exercise에 대해 빈 배열로 초기화 — index 정렬 보장
