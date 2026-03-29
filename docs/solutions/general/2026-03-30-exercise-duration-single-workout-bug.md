---
tags: [exercise, duration, dashboard, aggregation, healthkit, bug-fix]
date: 2026-03-30
category: solution
status: implemented
---

# Exercise Duration Shows Only Single Workout Duration

## Problem

Dashboard Exercise metric 히어로 값이 "5 min"으로 표시됨. 실제로는 100분 이상 운동했으나 유산소 포함 여러 운동 중 마지막 하나의 duration만 반영.

### 근본 원인

`DashboardViewModel.fetchExerciseData()`에서 오늘 운동이 없을 때 fallback 경로가 가장 최근 운동 **하나**의 duration만 사용:

```swift
} else if let latest = recentWorkouts.first {
    let totalMinutes = latest.duration / 60.0  // 1개만 사용
```

같은 함수 내에서 `minutesByDay` 딕셔너리가 이미 모든 운동을 일별로 합산하고 있었으나, fallback 경로에서 이를 사용하지 않았음.

## Solution

`minutesByDay` 딕셔너리를 활용하여 해당 날짜의 전체 운동 시간을 조회:

```swift
} else if let latest = recentWorkouts.first {
    let latestDay = calendar.startOfDay(for: latest.date)
    let totalMinutes = minutesByDay[latestDay] ?? (latest.duration / 60.0)
```

### 변경 파일

- `DUNE/Presentation/Dashboard/DashboardViewModel.swift` (2줄)

## Prevention

- **집계 로직에서 "latest single item" vs "daily aggregate" 분기 시**, 이미 계산된 aggregate 딕셔너리가 있으면 재사용할 것
- 같은 함수 내에서 today 경로(`todayWorkouts.map(\.duration).reduce(0, +)`)와 fallback 경로의 aggregation 수준이 일치하는지 확인

## Lessons Learned

- HealthKit 데이터 표시 로직에서 "today" 경로와 "historical fallback" 경로의 aggregation 수준이 달라지기 쉬움
- 차트 데이터(`MetricDetailViewModel.groupWorkoutsByDay`)는 정확했으나 히어로 값(`DashboardViewModel`)만 틀렸음 — 같은 데이터를 다른 경로로 표시할 때 일관성 주의
