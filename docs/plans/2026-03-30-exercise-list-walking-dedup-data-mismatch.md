---
tags: [dedup, exercise-list, walking, healthkit, cardio]
date: 2026-03-30
category: plan
status: approved
---

# Fix: Exercise 탭 걷기 운동 데이터 불일치

## Problem Statement

Activity 탭의 "최근 운동" 섹션과 Exercise 탭의 운동 목록이 같은 걷기 운동에 대해 다른 데이터를 표시함:
- **Activity 탭**: 6분 / 25 kcal / ❤️ 92 (HealthKit WorkoutSummary — 정확한 데이터)
- **Exercise 탭**: 0분 / 칼로리 없음 (ExerciseRecord — 빈 스텁)

## Root Cause

**두 화면의 dedup 전략이 불일치함**:

1. **Activity 탭** (`ExerciseListSection.buildItemsAndIndex`):
   - `recentListDedupRecords(from:)` → `hasSetData`인 레코드만 dedup 대상
   - 걷기 ExerciseRecord는 세트 없음 → dedup에서 제외 → HealthKit 버전 노출
   - 걷기 ExerciseRecord 자체도 목록에서 제외 (세트 없으므로)
   - **결과**: HealthKit WorkoutSummary가 정확한 데이터로 표시됨

2. **Exercise 탭** (`ExerciseViewModel.invalidateCache`):
   - `filteringAppDuplicates(against: manualRecords)` → **모든** ExerciseRecord로 dedup
   - 걷기 ExerciseRecord가 HealthKit 워크아웃과 매칭 → HealthKit 버전 제거
   - 빈 ExerciseRecord(duration=0, calories=nil, sets=[])가 목록에 표시
   - **결과**: 빈 스텁 레코드가 0분/칼로리 없음으로 표시됨

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Data/Persistence/Models/ExerciseRecord.swift` | `hasMeaningfulContent` computed property 추가 |
| `DUNE/Presentation/Exercise/ExerciseViewModel.swift` | dedup 및 표시 로직에 의미 있는 콘텐츠 필터링 적용 |

## Implementation Steps

### Step 1: ExerciseRecord에 `hasMeaningfulContent` 프로퍼티 추가

```swift
/// Whether this record carries user-visible content beyond a bare stub.
/// Empty stubs (0 duration, no calories, no sets) linked to HealthKit
/// should defer to the richer HealthKit WorkoutSummary.
var hasMeaningfulContent: Bool {
    hasSetData || duration > 0 || bestCalories != nil
}
```

### Step 2: ExerciseViewModel.invalidateCache() 수정

1. **dedup 필터에 의미 있는 레코드만 사용**: `filteringAppDuplicates(against: meaningfulRecords)`
2. **빈 스텁 레코드 표시 제외**: HealthKit 워크아웃이 표시되는 경우, 해당 빈 스텁은 목록에서 제외

```swift
// Only dedup HK workouts against records that have actual content
let dedupRecords = manualRecords.filter(\.hasMeaningfulContent)
var externalWorkouts = healthKitWorkouts.filteringAppDuplicates(
    against: dedupRecords,
    tombstonedIDs: tombstoned
)

// Build set of visible HK IDs to skip linked stubs
let visibleHKIDs = Set(externalWorkouts.map(\.id))

for record in manualRecords {
    // Skip empty stubs whose linked HealthKit workout is now visible
    if !record.hasMeaningfulContent,
       let hkID = record.healthKitWorkoutID, !hkID.isEmpty,
       visibleHKIDs.contains(hkID) {
        continue
    }
    items.append(.fromManualRecord(record, library: exerciseLibrary))
}
```

## Test Strategy

- 기존 `ExerciseViewModelTests`가 있으면 dedup 시나리오 추가
- 시나리오: 빈 ExerciseRecord + 매칭 HealthKit 워크아웃 → HealthKit 버전 표시

## Risks & Edge Cases

- **빈 스텁에 `healthKitWorkoutID` 없는 경우**: `isFromThisApp` + type+date 폴백으로 매칭된 경우 여전히 스텁 표시 가능. 이 경우는 빈도가 낮고 별도 이슈로 처리.
- **의도적 빈 레코드**: 사용자가 직접 만든 빈 레코드는 `healthKitWorkoutID`가 없으므로 그대로 표시됨.
- **HealthKit 워크아웃 없이 스텁만 존재**: `visibleHKIDs.contains(hkID)` 검사로 보호 — HK 버전이 없으면 스텁이라도 표시.
