---
tags: [dashboard, yesterday-recap, cardio, healthkit, workout-summary, dedup]
date: 2026-04-05
category: general
status: implemented
---

# Yesterday Recap에 유산소 운동 누락 수정

## Problem

투데이 탭의 "어제 운동 기록 요약" (YesterdayRecapCard)에 Apple Watch/외부 앱에서 기록한
유산소 운동(러닝, 걷기, 사이클링 등)이 표시되지 않음.

근본 원인: `DashboardViewModel.updateYesterdayWorkoutSummary(from:)`가 SwiftData `ExerciseRecord`만
사용하여 어제 운동을 집계. Apple Watch 등에서 기록된 유산소는 HealthKit `WorkoutSummary`로만 존재하고
`ExerciseRecord`에는 없으므로 누락됨. Activity 탭에서는 HealthKit `WorkoutSummary`를 직접 사용하므로 유산소가 정상 표시됨.

## Solution

### 핵심 변경

1. `DashboardViewModel`에 `cachedHealthKitWorkouts: [WorkoutSummary]` 프로퍼티 추가
2. `fetchExerciseData()`에서 이미 로드하는 30일치 HealthKit 워크아웃을 캐시에 저장
3. `updateYesterdayWorkoutSummary`에서 ExerciseRecord + 캐시된 HealthKit WorkoutSummary를
   `filteringAppDuplicates`로 dedup 후 합산

### 변경 파일

| 파일 | 변경 |
|------|------|
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | cachedHealthKitWorkouts 추가, updateYesterdayWorkoutSummary 확장 |
| `DUNETests/YesterdayWorkoutSummaryTests.swift` | 6개 시나리오 테스트 |

### 핵심 코드

```swift
// HealthKit workouts from yesterday, deduped against ExerciseRecords
let yesterdayHKWorkouts = cachedHealthKitWorkouts
    .filter { calendar.isDate($0.date, inSameDayAs: yesterday) }
    .filteringAppDuplicates(against: yesterdayRecords)

let totalCount = yesterdayRecords.count + yesterdayHKWorkouts.count
let totalDuration = recordSeconds + hkSeconds
```

## Prevention

- Dashboard 요약 데이터를 집계할 때 ExerciseRecord만이 아닌 HealthKit WorkoutSummary도 고려
- 새 요약 기능 추가 시 Activity 탭과 동일한 데이터 소스 parity 확인 (corrections-active.md #213)
- `filteringAppDuplicates` dedup 로직은 이미 잘 작동하므로 재사용

## Lessons Learned

- SwiftData `ExerciseRecord`와 HealthKit `WorkoutSummary`는 서로 다른 데이터 경로.
  앱 내에서 직접 기록한 운동만 `ExerciseRecord`에 저장되고, Apple Watch나 외부 앱 운동은
  HealthKit에만 존재. 요약/통계 화면에서 두 소스를 모두 사용해야 완전한 데이터를 표시할 수 있음.
- 기존 dedup 유틸리티(`filteringAppDuplicates`)를 재사용하여 중복 카운트 방지
