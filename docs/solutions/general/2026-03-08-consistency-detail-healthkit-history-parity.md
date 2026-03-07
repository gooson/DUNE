tags: [consistency, healthkit, streak, activity, detail-view, parity]
date: 2026-03-08
category: solution
status: implemented
---

# Consistency Detail HealthKit History Parity Fix

## Problem

Consistency 상세 화면에서 현재 연속 기록, 최장 연속 기록, 월간 진행이 `0`으로 표시될 수 있었다.

특히 Activity 카드에는 기록이 보이는데 상세 진입 후에는 `아직 연속 기록이 없어요.`로 나오는 불일치가 발생했다.

## Root Cause

`ConsistencyDetailViewModel`은 SwiftData `ExerciseRecord`만 읽어서 streak를 계산하고 있었다.

반면 Activity 카드의 `workoutStreak`는 manual record와 HealthKit workout을 함께 써서 계산한다. 그래서 HealthKit 중심 사용자에게는 카드와 상세가 서로 다른 데이터 소스를 보게 됐다.

추가로 ActivityViewModel의 `recentWorkouts`는 7일 fetch라서, 그 값을 그대로 넘기는 방식으로는 최장 연속 기록이나 긴 월간 히스토리를 안정적으로 복원할 수 없었다.

## Solution

Consistency 상세도 자체적으로 장기 HealthKit workout history를 가져와 manual record와 병합한 뒤 streak를 계산하도록 바꿨다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/Consistency/ConsistencyDetailViewModel.swift` | `WorkoutQuerying` 주입 추가, 3650일 HealthKit workout fetch + manual record 병합 | card/detail streak data parity 복구 |
| `DUNE/Presentation/Activity/Consistency/ConsistencyDetailView.swift` | `.task`에서 async `loadData` 호출 | HealthKit fetch 반영 |
| `DUNETests/ConsistencyDetailViewModelTests.swift` | HealthKit-only streak, HealthKit fetch failure fallback 테스트 추가 | 회귀 방지 |

### Key Code

```swift
let manualWorkouts = exerciseRecords.map { ... }
let healthKitWorkouts = await fetchHealthKitWorkouts()
let workouts = manualWorkouts + healthKitWorkouts

workoutStreak = WorkoutStreakService.calculate(from: workouts)
streakHistory = WorkoutStreakService.extractStreakHistory(from: workouts)
```

## Prevention

- Activity summary card와 detail 화면이 같은 metric을 보여주면 데이터 소스 계약도 같아야 한다.
- summary가 manual+HealthKit merged metric이면 detail도 같은 merged input을 재사용하거나 동등한 fetch를 해야 한다.
- `recentWorkouts` 같은 짧은 캐시는 overview용과 history용을 구분해서 써야 한다.

## Lessons Learned

같은 화면군 안에서 card와 detail이 다른 저장소를 보면 “계산 로직”이 아니라 “입력 집합” 차이로 버그가 난다. 특히 streak처럼 dedup/day-level metric은 계산 함수보다 데이터 소스 parity가 더 중요하다.
