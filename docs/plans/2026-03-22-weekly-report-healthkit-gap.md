---
tags: [weekly-report, healthkit, data-gap, activity]
date: 2026-03-22
category: plan
status: approved
---

# Plan: 주간 리포트에 HealthKit 워크아웃 포함

## Problem

주간 리포트(`WorkoutReportCard`)가 "운동을 더 하세요" empty state만 표시.
사용자는 운동을 하고 있지만, HealthKit 경유 워크아웃(Watch, 서드파티 앱)이 리포트에서 누락됨.

### Root Cause

`generateWeeklyReport()`가 `exerciseRecordSnapshots`(SwiftData)만 사용.
`recomputeFatigueAndSuggestion()`는 이미 SwiftData + HealthKit 스냅샷을 병합하여 fatigue/suggestion에 사용하지만,
주간 리포트는 이 병합을 하지 않아 HealthKit-only 워크아웃이 제외됨.

```
recomputeFatigueAndSuggestion():
  exerciseRecordSnapshots + healthKitSnapshots → fatigue, suggestion ✅

generateWeeklyReport():
  exerciseRecordSnapshots only → weeklyReport ❌ (HealthKit 누락)

partitionSnapshotsByWeek():
  exerciseRecordSnapshots only → 주간 분할 ❌ (HealthKit 누락)
```

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Presentation/Activity/ActivityViewModel.swift` | HealthKit 스냅샷 병합 추출 + 리포트에 포함 |
| `DUNETests/ActivityViewModelTests.swift` | HealthKit 워크아웃 포함 테스트 추가 |

## Implementation Steps

### Step 1: HealthKit 스냅샷 저장 프로퍼티 추가

`recomputeFatigueAndSuggestion()`에서 계산되는 `healthKitSnapshots`를 stored property로 승격.

```swift
private var healthKitOnlySnapshots: [ExerciseRecordSnapshot] = []
```

### Step 2: `recomputeFatigueAndSuggestion()`에서 저장

기존 local `healthKitSnapshots` 계산 결과를 property에도 저장.

### Step 3: `allExerciseSnapshots` computed property 추가

```swift
private var allExerciseSnapshots: [ExerciseRecordSnapshot] {
    exerciseRecordSnapshots + healthKitOnlySnapshots
}
```

### Step 4: `generateWeeklyReport()`에서 allExerciseSnapshots 사용

- `exerciseRecordSnapshots` → `allExerciseSnapshots`로 교체
- `partitionSnapshotsByWeek()` → inline으로 `allExerciseSnapshots` 기반 필터

### Step 5: `partitionSnapshotsByWeek()` 업데이트

`exerciseRecordSnapshots` → `allExerciseSnapshots`로 교체.
`recomputeInjuryRisk`, `rebuildWeeklyStats`도 이 메서드를 사용하므로 같이 수정됨.

### Step 6: `rebuildWeeklyStats()` 업데이트

이미 HealthKit 칼로리와 active days를 별도 처리하고 있지만,
volume/duration도 HealthKit 워크아웃을 포함하도록 `allExerciseSnapshots` 사용.

### Step 7: 테스트 추가

- HealthKit-only 워크아웃이 있을 때 주간 리포트가 생성되는지 검증
- SwiftData + HealthKit 혼합 시 중복 없이 합산되는지 검증

## Test Strategy

- `ActivityViewModelTests`에 HealthKit 워크아웃 시나리오 추가
- `GenerateWorkoutReportUseCaseTests`는 변경 불필요 (UseCase 자체는 변경 없음)

## Risks

- `partitionSnapshotsByWeek()` 변경으로 injury risk 계산에도 HealthKit 워크아웃 포함됨 → 기존보다 정확해지므로 문제 없음
- `rebuildWeeklyStats()` volume이 HealthKit 워크아웃의 volume(대부분 nil)을 포함 → `compactMap(\.totalWeight)`으로 nil은 자동 제외
