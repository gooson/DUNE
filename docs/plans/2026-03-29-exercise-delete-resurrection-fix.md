---
tags: [healthkit, delete, tombstone, dedup, exercise, bug]
date: 2026-03-29
category: plan
status: draft
---

# Plan: 운동 삭제 후 앱 재실행 시 데이터 부활 버그 수정

## Problem Statement

사용자가 운동 기록을 삭제한 후 앱을 재실행하면, 삭제된 운동이 다시 나타남.

### Root Cause

삭제 플로우에서 **tombstone은 생성되지만**, 앱 재시작 시 HealthKit 쿼리 결과에서 tombstone을 확인하지 않음.

1. `ConfirmDeleteRecordModifier`: tombstone 생성 → SwiftData 삭제 → HealthKit 삭제 (fire-and-forget)
2. HealthKit 삭제가 비동기로 실패하거나 완료 전 앱 종료 시, HealthKit에 워크아웃이 남음
3. 앱 재시작 → `ExerciseViewModel.loadHealthKitWorkouts()` → `WorkoutQueryService.fetchWorkouts()` 실행
4. `WorkoutQueryService`는 **tombstone 체크 없이** 모든 HealthKit 워크아웃 반환
5. `filteringAppDuplicates(against:)`: ExerciseRecord가 이미 삭제됐으므로 매칭 실패
6. 삭제된 워크아웃이 UI에 다시 표시됨

### Affected Paths

| 경로 | 파일 | Tombstone 체크 |
|------|------|----------------|
| Exercise 탭 | `ExerciseViewModel.invalidateCache()` | ❌ 없음 |
| Activity 탭 최근 운동 | `ExerciseListSection.buildItemsAndIndex()` | ❌ 없음 |
| Watch sync | `DUNEApp.swift` (~line 700) | ✅ 있음 |
| Backfill | `DUNEApp.swift` (~line 864) | ✅ 있음 |

## Affected Files

| File | Change | Risk |
|------|--------|------|
| `Data/Persistence/DeletedWorkoutTombstoneStore.swift` | `tombstonedIDs` computed property 추가 | Low |
| `Presentation/Shared/Extensions/WorkoutSummary+Dedup.swift` | `tombstonedIDs` 파라미터 추가 | Low |
| `Presentation/Exercise/ExerciseViewModel.swift` | tombstone IDs 전달 | Low |
| `Presentation/Activity/Components/ExerciseListSection.swift` | tombstone IDs 전달 | Low |
| `DUNETests/ExerciseViewModelTests.swift` | tombstone 필터링 테스트 추가 | Low |

## Implementation Steps

### Step 1: DeletedWorkoutTombstoneStore — tombstonedIDs 노출

`DeletedWorkoutTombstoneStore`에 캐시된 tombstone ID Set을 반환하는 프로퍼티 추가.

```swift
var tombstonedIDs: Set<String> {
    ensureCache()
    return Set(cache.keys)
}
```

### Step 2: filteringAppDuplicates — tombstone 필터링 통합

`WorkoutSummary+Dedup.swift`의 `filteringAppDuplicates(against:)` 메서드에 `tombstonedIDs: Set<String>` 파라미터 추가. 기본값 `[]`로 하위 호환 유지.

```swift
func filteringAppDuplicates(
    against records: [ExerciseRecord],
    tombstonedIDs: Set<String> = []
) -> [WorkoutSummary] {
    // ... existing logic ...
    return filter { workout in
        // NEW: tombstone check first
        if tombstonedIDs.contains(workout.id) { return false }
        // ... rest of existing logic ...
    }
}
```

### Step 3: ExerciseViewModel — tombstone IDs 전달

`invalidateCache()` 호출 시 tombstone IDs를 전달.

```swift
private func invalidateCache() {
    let tombstoned = DeletedWorkoutTombstoneStore.shared.tombstonedIDs
    var externalWorkouts = healthKitWorkouts.filteringAppDuplicates(
        against: manualRecords,
        tombstonedIDs: tombstoned
    )
    // ... rest unchanged
}
```

### Step 4: ExerciseListSection — tombstone IDs 전달

`buildItemsAndIndex()` 호출 시 tombstone IDs 전달.

```swift
let tombstoned = DeletedWorkoutTombstoneStore.shared.tombstonedIDs
let externalWorkouts = workouts.filteringAppDuplicates(
    against: setRecords,
    tombstonedIDs: tombstoned
)
```

### Step 5: 테스트 작성

`ExerciseViewModelTests`에 tombstone 필터링 테스트 추가:
- tombstoned ID를 가진 워크아웃이 `allExercises`에서 제외되는지 검증

## Test Strategy

- **Unit test**: tombstoned workout이 dedup 결과에서 제외됨
- **Manual test**: 운동 삭제 → 앱 재실행 → 삭제된 운동이 표시되지 않음

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| 90일 경과 tombstone 만료 + HealthKit 워크아웃 잔존 | HealthKit 삭제 fire-and-forget는 유지. 90일 후에도 HealthKit에 남아있으면 재표시되지만, 일반적으로 삭제 성공 |
| `tombstonedIDs` 호출 빈도 | `invalidateCache()` 시 매번 호출. UserDefaults 읽기는 lazy cache 후 메모리에서 반환하므로 성능 영향 없음 |
| Activity 탭 내 다른 ViewModel들 | `ActivityViewModel` 등은 `WorkoutSummary`를 통계용으로 사용하여 UI 목록 표시와 무관. 통계에서 삭제된 항목을 제외하면 오히려 부정확해질 수 있으므로 현재 범위에서 제외 |

## Alternatives Considered

1. **WorkoutQueryService에서 필터링**: Data 레이어에서 tombstone 체크. 하지만 통계용 쿼리까지 영향받아 부작용 가능
2. **HealthKit 삭제를 await**: 삭제 완료를 보장하지만 UI가 느려지고, 권한 문제로 실패 시 사용자 경험 악화
3. **선택: filteringAppDuplicates에 통합**: 모든 dedup 지점에서 자동 적용. 기본값 `[]`로 기존 호출 호환
