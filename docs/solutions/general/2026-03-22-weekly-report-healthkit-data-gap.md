---
tags: [weekly-report, healthkit, data-gap, activity, workout-summary]
date: 2026-03-22
category: general
status: implemented
related_files:
  - DUNE/Presentation/Activity/ActivityViewModel.swift
related_solutions:
  - docs/solutions/healthkit/2026-03-15-orphaned-hkworkout-muscle-recovery.md
---

# Solution: 주간 리포트에서 HealthKit 워크아웃 누락

## Problem

### 증상

주간 리포트(`WorkoutReportCard`)가 "운동을 더 하세요" empty state만 표시.
사용자는 실제로 운동을 하고 있지만, HealthKit 경유 워크아웃(Watch, 서드파티 앱, 고아 워크아웃)이 리포트에 포함되지 않음.

### Root Cause

`ActivityViewModel.generateWeeklyReport()`가 `exerciseRecordSnapshots`(SwiftData 전용)만 사용하여 주간 데이터를 분할.
반면 `recomputeFatigueAndSuggestion()`는 이미 SwiftData + HealthKit 스냅샷을 병합하여 fatigue/suggestion에 활용.

이 불일치로 인해:
- Watch에서 기록한 운동 → fatigue에는 반영 ✅, 주간 리포트에는 누락 ❌
- 서드파티 앱(Apple Fitness 등) 워크아웃 → 동일하게 누락 ❌
- 스토어 복구 후 고아 워크아웃 → fatigue에는 복구됨 ✅, 주간 리포트에는 누락 ❌

### 영향 범위

`exerciseRecordSnapshots` 단독 사용하는 곳이 3곳:
1. `generateWeeklyReport()` — 주간 리포트
2. `partitionSnapshotsByWeek()` — injury risk 계산
3. `rebuildWeeklyStats()` — 주간 통계 위젯

## Solution

1. `healthKitOnlySnapshots` stored property 추가 — `recomputeFatigueAndSuggestion()`에서 계산 후 저장
2. `allExerciseSnapshots` computed property로 SwiftData + HealthKit 병합 단일 소스 제공
3. 3곳 모두 `allExerciseSnapshots` 사용으로 교체

```swift
private var healthKitOnlySnapshots: [ExerciseRecordSnapshot] = []

private var allExerciseSnapshots: [ExerciseRecordSnapshot] {
    exerciseRecordSnapshots + healthKitOnlySnapshots
}
```

### 핵심 원칙

HealthKit 데이터를 소비하는 모든 집계/리포트 경로는 `allExerciseSnapshots`를 사용해야 함.
`exerciseRecordSnapshots` 단독 사용은 SwiftData-only 로직(personal records 등 ExerciseRecord 전용 기능)에만 허용.

## Prevention

- 새 집계/리포트 기능 추가 시 `exerciseRecordSnapshots` 대신 `allExerciseSnapshots` 사용 확인
- HealthKit 워크아웃이 포함되어야 하는지 설계 단계에서 명시
- `recomputeFatigueAndSuggestion()`과 동일 데이터 소스를 사용하는지 교차 확인

## Lessons Learned

1. 같은 ViewModel 내에서도 데이터 소스 불일치가 발생할 수 있음 — fatigue는 병합, 리포트는 미병합
2. 고아 워크아웃 복구(2026-03-15)를 fatigue에만 적용하고 리포트에 적용하지 않은 것이 근본 원인
3. 데이터 병합 로직은 중복하지 않고 단일 computed property로 통일해야 일관성 보장
