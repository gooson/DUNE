---
tags: [activity, volume, bug, snapshot, weekly-stats]
date: 2026-03-28
category: plan
status: draft
---

# Fix: Activity Tab Volume Display Bug

## Problem

Activity 탭 전체에서 "Volume" (볼륨) 표시가 나오지 않음. WeeklyStatsGrid의 Volume 카드가 "—"으로 표시되고, WorkoutReportCard의 Volume도 0으로 표시됨.

## Root Cause

`ExerciseRecordSnapshot.totalWeight`가 **세트별 무게의 단순 합**으로 계산되고 있음:
```swift
// 현재: sum(weight) — 잘못된 계산
let totalWeight = completedSets.compactMap(\.weight).reduce(0, +)
// 예: 3세트 × 60kg = 180
```

`ExerciseRecord.totalVolume`은 올바르게 **weight × reps**로 계산됨:
```swift
// 올바른 계산: sum(weight × reps)
total + weight * reps
// 예: 3세트 × 60kg × 10reps = 1800
```

이 불일치로 인해:
1. Volume 표시값이 실제 훈련 볼륨보다 훨씬 작음
2. 맨몸 운동(weight=nil)은 볼륨이 0으로 표시됨 — 세트 수 기반 표시도 없음
3. 여러 곳에서 동일 metric을 다르게 계산하는 DRY 위반

## Affected Files

| File | Change | Purpose |
|------|--------|---------|
| `DUNE/Presentation/Activity/ActivityViewModel.swift` | `buildExerciseRecordSnapshot` 수정 | Snapshot `totalWeight` → weight×reps |
| `DUNE/Presentation/Shared/Extensions/ExerciseRecord+Snapshot.swift` | `snapshot(library:)` 수정 | 동일 계산 통일 |
| `DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift` | `makeExerciseSnapshot` 수정 | 동일 계산 통일 |
| `DUNE/Domain/UseCases/GenerateWorkoutReportUseCase.swift` | `totalVolume` 계산 확인 | Report volume도 올바른 계산 사용 |
| `DUNETests/` | 테스트 추가/수정 | Volume 계산 검증 |

## Implementation Steps

### Step 1: `ActivityViewModel.buildExerciseRecordSnapshot` 수정

`totalWeight` 계산을 `ExerciseRecord.totalVolume`과 동일한 weight×reps 방식으로 변경:

```swift
// Before:
let totalWeight = Swift.min(completedSets.compactMap(\.weight).reduce(0, +), 50_000)

// After:
let totalWeight = Swift.min(
    completedSets.reduce(0.0) { total, set in
        let w = set.weight ?? 0
        let r = Double(set.reps ?? 0)
        guard w > 0, r > 0 else { return total }
        return total + w * r
    },
    999_999
)
```

### Step 2: `ExerciseRecord+Snapshot.swift` 동일 수정

```swift
// Before:
let totalWeight = completedSets.compactMap(\.weight).reduce(0, +)

// After:
let totalWeight = completedSets.reduce(0.0) { total, set in
    let w = set.weight ?? 0
    let r = Double(set.reps ?? 0)
    guard w > 0, r > 0 else { return total }
    return total + w * r
}
```

### Step 3: `TrainingVolumeViewModel.makeExerciseSnapshot` 동일 수정

```swift
// Before:
let totalWeight = Swift.min(completedSets.compactMap(\.weight).reduce(0, +), 50_000)

// After:
let totalWeight = Swift.min(
    completedSets.reduce(0.0) { total, set in
        let w = set.weight ?? 0
        let r = Double(set.reps ?? 0)
        guard w > 0, r > 0 else { return total }
        return total + w * r
    },
    999_999
)
```

### Step 4: `GenerateWorkoutReportUseCase` 확인

이미 `ExerciseRecordSnapshot.totalWeight`를 사용하므로, Step 1-3 수정으로 자동 반영됨.

### Step 5: 테스트 추가

- `ExerciseRecordSnapshot.totalWeight`가 weight×reps인지 검증
- Volume이 0인 경우 (bodyweight) nil 반환 검증
- WeeklyStats에서 volume 계산 검증

## Test Strategy

- 기존 `ActivityViewModelTests`에 volume 계산 검증 추가
- `ExerciseRecord+Volume` 테스트와 snapshot totalWeight가 일관되는지 검증
- 경계값: weight=0, reps=0, mixed (일부 weighted + 일부 bodyweight)

## Risk / Edge Cases

- Volume 값이 기존보다 크게 변함 (sum(weight) → sum(weight×reps)). 이것이 올바른 변경
- `50_000` cap → `999_999`로 변경 (실제 훈련 볼륨은 수만~수십만 kg 가능)
- Bodyweight 운동은 여전히 nil (weight × reps = 0). 향후 rep volume 추가 고려 가능
