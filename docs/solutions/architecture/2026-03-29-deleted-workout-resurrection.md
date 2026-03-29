---
tags: [healthkit, delete, tombstone, dedup, exercise, resurrection, bug]
date: 2026-03-29
category: architecture
severity: important
related_files:
  - DUNE/Data/Persistence/DeletedWorkoutTombstoneStore.swift
  - DUNE/Presentation/Shared/Extensions/WorkoutSummary+Dedup.swift
  - DUNE/Presentation/Exercise/ExerciseViewModel.swift
  - DUNE/Presentation/Activity/Components/ExerciseListSection.swift
  - DUNE/Presentation/Activity/ActivityView.swift
related_solutions:
  - docs/solutions/architecture/2026-03-03-watch-manual-workout-delete-parity.md
---

# Solution: Deleted Workout Resurrection After App Restart

## Problem

사용자가 운동 기록을 삭제한 후 앱을 재실행하면, 삭제된 운동이 다시 나타남.

### Symptoms

- Exercise 탭에서 운동 삭제 → 앱 재실행 → 삭제된 운동이 HealthKit 항목으로 다시 표시
- Activity 탭의 Recent Workouts 섹션에서도 동일 증상

### Root Cause

삭제 흐름:
1. `ConfirmDeleteRecordModifier`: tombstone 생성 → SwiftData 삭제 → HealthKit 삭제 (fire-and-forget)
2. HealthKit 삭제가 비동기로 실패하거나 앱 종료 전 미완료 시, HealthKit에 워크아웃 잔존
3. 앱 재시작 → `WorkoutQueryService.fetchWorkouts()` → tombstone 체크 없이 모든 HealthKit 워크아웃 반환
4. `filteringAppDuplicates(against:)`: ExerciseRecord가 이미 삭제됐으므로 매칭 실패 → 워크아웃 재표시

tombstone은 Watch sync 경로(`DUNEApp.swift`)와 backfill 경로에서만 확인되고, **UI 표시 경로(`filteringAppDuplicates`)에서는 확인되지 않았음**.

## Solution

`filteringAppDuplicates(against:)` 메서드에 `tombstonedIDs: Set<String>` 파라미터를 추가하여, tombstone에 기록된 HealthKit 워크아웃 ID를 UI 표시에서 항상 제외.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DeletedWorkoutTombstoneStore.swift` | `tombstonedIDs` computed property 추가 + `_tombstonedIDs` Set 캐싱 | 매 호출마다 Set 재할당 방지 |
| `WorkoutSummary+Dedup.swift` | `tombstonedIDs` 파라미터 추가 (기본값 `[]`) | 모든 dedup 지점에서 tombstone 체크 |
| `ExerciseViewModel.swift` | `invalidateCache()` 시 tombstone IDs 전달 | Exercise 탭 필터링 |
| `ExerciseListSection.swift` | `tombstonedIDs` init 파라미터 추가 (View에서 Data 레이어 직접 접근 제거) | Activity 탭 필터링 + 레이어 경계 준수 |
| `ActivityView.swift` | `ExerciseListSection` 호출 시 tombstone IDs 전달 | View → ViewModel → View 데이터 흐름 유지 |

### Key Design Decisions

1. **`WorkoutQueryService`에서 필터링하지 않은 이유**: 통계/분석용 쿼리까지 영향받으면 부정확한 결과 발생. UI 표시 경로에서만 필터링.
2. **`filteringAppDuplicates`에 통합한 이유**: 기존 dedup 메서드에 자연스럽게 확장. 기본값 `[]`로 기존 호출 호환.
3. **Set 캐싱**: `tombstonedIDs`가 `buildItemsAndIndex()` 등 SwiftUI render path에서 호출될 수 있어 `Set(cache.keys)` 재할당 방지.

## Prevention

### Checklist

- [ ] HealthKit 워크아웃을 UI에 표시하는 모든 경로에서 tombstone 체크가 포함되는가
- [ ] 새로운 dedup/필터 로직 추가 시 `filteringAppDuplicates`를 경유하는가
- [ ] View에서 Data 레이어 싱글턴 직접 접근 없이 파라미터로 전달하는가

### Pattern

HealthKit 데이터를 UI에 표시하는 새 경로를 추가할 때:
```swift
let tombstoned = DeletedWorkoutTombstoneStore.shared.tombstonedIDs
let filtered = workouts.filteringAppDuplicates(
    against: records,
    tombstonedIDs: tombstoned
)
```

## Lessons Learned

tombstone 메커니즘은 "데이터 생성 방지"와 "데이터 표시 방지" 두 역할이 있다. 이 코드베이스에서는 생성 방지(Watch sync, backfill)만 구현되어 있었고, 표시 방지가 누락되어 있었다. 삭제 기능 구현 시 두 경로를 모두 검증해야 한다.
