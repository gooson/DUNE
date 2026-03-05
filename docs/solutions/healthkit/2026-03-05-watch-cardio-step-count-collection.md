---
tags: [healthkit, watch, cardio, stepCount, HKLiveWorkoutDataSource]
date: 2026-03-05
category: solution
status: implemented
---

# Watch 카디오 운동 걸음수 미기록 수정

## Problem

Watch에서 걷기/달리기 등 카디오 운동 후 종료하면 걸음수가 0으로 기록됨.
`WorkoutManager.steps`가 항상 0인 상태에서 `saveCardioRecord`가 호출됨.

## Root Cause

`HKLiveWorkoutDataSource`는 workout configuration에 따라 **자동 수집 타입이 제한적**:
- 자동 수집: heartRate, activeEnergyBurned, distanceWalkingRunning
- **미수집**: stepCount, flightsClimbed

`enableCollection(for:predicate:)`를 명시적으로 호출하지 않으면,
`workoutBuilder(_:didCollectDataOf:)` delegate에 해당 타입이 전달되지 않음.

## Solution

### 1. `enableCollection` 명시적 호출

```swift
let dataSource = HKLiveWorkoutDataSource(
    healthStore: healthStore,
    workoutConfiguration: config
)
dataSource.enableCollection(for: HKQuantityType(.stepCount), predicate: nil)
dataSource.enableCollection(for: HKQuantityType(.flightsClimbed), predicate: nil)
newBuilder.dataSource = dataSource
```

### 2. Crash recovery 시 step 복원

`restoreDistanceFromBuilder`에서 distance, floors와 함께 steps도 복원:

```swift
if let stats = builder.statistics(for: HKQuantityType(.stepCount)),
   let totalSteps = stats.sumQuantity()?.doubleValue(for: .count()),
   totalSteps > 0, totalSteps < 200_000 {
    steps = totalSteps
}
```

### 3. `saveCardioRecord` 누락 필드 추가

- `averagePaceSecondsPerKm`: `workoutManager.currentPace`
- `floorsAscended`: `workoutManager.floorsClimbed`

## Prevention

- `HKLiveWorkoutDataSource` 사용 시, 기본 수집 타입 외에 필요한 metric은 반드시 `enableCollection` 호출
- 새 metric 추가 시 Correction #198 체크리스트 적용: WorkoutManager 수집 → saveCardioRecord 전달 → ExerciseRecord init 확인
- 수집/복원/저장의 validation guard (`> 0`)를 일관되게 유지

## Affected Files

| File | Change |
|------|--------|
| `DUNEWatch/Managers/WorkoutManager.swift` | enableCollection + step restore |
| `DUNEWatch/Views/SessionSummaryView.swift` | pace/floors 전달 추가 |
| `DUNE/Data/HealthKit/CardioSessionManager.swift` | enableCollection (iOS) |
