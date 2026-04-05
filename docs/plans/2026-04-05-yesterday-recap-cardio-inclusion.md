---
tags: [dashboard, yesterday-recap, cardio, healthkit, workout-summary]
date: 2026-04-05
category: plan
status: approved
---

# Yesterday Recap 유산소 누락 수정

## Problem

투데이 탭의 "어제 운동 기록 요약" (YesterdayRecapCard)에 유산소 운동이 표시되지 않음.

### 근본 원인

`DashboardViewModel.updateYesterdayWorkoutSummary(from:)`가 SwiftData `ExerciseRecord`만 사용.
Apple Watch나 외부 앱에서 기록한 유산소(러닝, 걷기, 사이클링 등)는 HealthKit `WorkoutSummary`로만 존재하고
`ExerciseRecord`에 backfill되지 않으므로 어제 요약에서 누락됨.

Activity 탭에서는 HealthKit `WorkoutSummary`를 직접 사용하므로 유산소가 정상 표시됨.

## Solution

### 접근 방법

`fetchExerciseData()`에서 이미 30일치 HealthKit 워크아웃을 로드하므로,
이 시점에 어제 워크아웃 요약을 사전 계산하여 stored property에 저장.
`buildYesterdayRecap()`에서 이 값을 사용.

이렇게 하면:
- HealthKit 워크아웃 중복 호출 없음
- ExerciseRecord + HealthKit WorkoutSummary 합산
- 기존 dedup 로직(`filteringAppDuplicates`) 활용

### Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | `updateYesterdayWorkoutSummary` 시그니처 변경 — HealthKit `WorkoutSummary`도 받도록 확장 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | `updateYesterdayWorkoutSummary` 호출 시 HealthKit 워크아웃도 전달 |
| `DUNE/DUNETests/` | 유닛 테스트 추가 |

### Implementation Steps

#### Step 1: DashboardViewModel 수정

`updateYesterdayWorkoutSummary`에 `healthKitWorkouts: [WorkoutSummary]` 파라미터 추가.

1. ExerciseRecord에서 어제 기록 필터
2. HealthKit WorkoutSummary에서 어제 기록 필터
3. `filteringAppDuplicates` 로 HealthKit 워크아웃 dedup (ExerciseRecord와 중복 제거)
4. ExerciseRecord count + duration + deduped HealthKit 워크아웃 count + duration 합산
5. 요약 문자열 생성

#### Step 2: DashboardView 수정

`DashboardView`에서 HealthKit 워크아웃 데이터를 `updateYesterdayWorkoutSummary`에 전달.
`DashboardViewModel`에 어제 워크아웃 계산에 필요한 HealthKit 데이터를 전달하는 가장 간단한 방법:
- `fetchExerciseData()`에서 로드한 WorkoutSummary를 stored property로 캐싱
- `updateYesterdayWorkoutSummary`에서 이 캐시를 사용

#### Step 3: 유닛 테스트 작성

- ExerciseRecord만 있을 때 (기존 동작 유지)
- HealthKit WorkoutSummary만 있을 때 (유산소 포함)
- 둘 다 있을 때 (dedup 후 합산)
- 어제 기록 없을 때 (nil 반환)

## Test Strategy

- `DashboardViewModelTests`에 `updateYesterdayWorkoutSummary` 테스트 추가
- ExerciseRecord + WorkoutSummary 조합별 시나리오

## Risk & Edge Cases

- ExerciseRecord와 HealthKit 워크아웃이 동일 운동을 중복 카운트할 수 있음 → `filteringAppDuplicates` 재사용으로 해결
- `fetchLimit = 20`인 @Query가 어제 데이터를 포함하지 못할 수 있음 → HealthKit WorkoutSummary가 이를 보완
- HealthKit 권한 없는 경우 → WorkoutSummary가 비어있으므로 ExerciseRecord만으로 fallback (기존 동작)
