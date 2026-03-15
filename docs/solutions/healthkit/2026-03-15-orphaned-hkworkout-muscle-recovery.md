---
tags: [healthkit, muscle-map, data-recovery, store-recovery, fatigue]
date: 2026-03-15
category: healthkit
status: implemented
related_files:
  - DUNE/Presentation/Activity/ActivityViewModel.swift
  - DUNE/Data/Persistence/Migration/PersistentStoreRecovery.swift
related_solutions:
  - docs/solutions/healthkit/2026-03-15-localized-title-custom-name-regression.md
---

# Solution: SwiftData 스토어 복구 후 고아 HKWorkout에서 근육 데이터 복구

## Problem

### 증상

근육 맵에서 최근 가슴 운동(Bench Press 등)이 표시되지 않음. Activity 탭에서 운동 제목은 보이지만 근육 활성화 데이터가 누락.

### Root Cause

`PersistentStoreRecovery`가 마이그레이션 실패(error code 134100-134504) 시 SwiftData 스토어를 삭제.
이로 인해 `ExerciseRecord`가 모두 사라지지만, HealthKit에 저장된 `HKWorkout`은 영향 없이 유지.

`recomputeFatigueAndSuggestion()`에서 앱 생성 HKWorkout은 `!$0.isFromThisApp` 필터로 제외됨.
정상 상황에서는 ExerciseRecord가 해당 근육 데이터를 제공하므로 문제 없지만,
스토어 복구 후에는 ExerciseRecord가 없으므로 해당 운동의 근육 데이터가 완전히 소실.

### 핵심 구조

```
정상 경로:
  ExerciseRecord → buildExerciseRecordSnapshot() → primaryMuscles 포함
  HKWorkout (isFromThisApp) → 필터로 제외 (중복 방지)

스토어 복구 후:
  ExerciseRecord → 삭제됨 (없음)
  HKWorkout (isFromThisApp) → 필터로 제외 → 근육 데이터 소실!
```

## Solution

`recomputeFatigueAndSuggestion()`에서 "고아" 앱 생성 HKWorkout을 식별하고 근육 데이터를 복구:

1. `manualRecordsCache`의 `healthKitWorkoutID`로 연결된 HK ID 집합 구성
2. 앱 생성 HK 워크아웃 중 연결된 ExerciseRecord가 없는 것(고아)을 식별
3. 고아 워크아웃의 `type`(= 운동명, metadata에서 읽음)을 라이브러리에서 검색
4. 라이브러리 매칭 성공 → `ExerciseDefinition`의 근육 데이터 사용
5. 매칭 실패 → `activityType.primaryMuscles` fallback

```swift
let linkedHKIDs = Set(manualRecordsCache.compactMap(\.healthKitWorkoutID))

for workout in recentWorkouts {
    if !workout.isFromThisApp {
        // 서드파티: 기존 동작 유지
    } else if !linkedHKIDs.contains(workout.id) {
        // 고아: 라이브러리 검색으로 근육 데이터 복구
        let exerciseName = workout.type
        if let definition = library.search(query: exerciseName).first(where: {
            $0.name.caseInsensitiveCompare(exerciseName) == .orderedSame
                || $0.localizedName.caseInsensitiveCompare(exerciseName) == .orderedSame
        }), !definition.primaryMuscles.isEmpty {
            // 라이브러리 매칭 성공 → 정확한 근육 데이터
        } else if !workout.activityType.primaryMuscles.isEmpty {
            // fallback → activityType 기본 근육
        }
    }
    // else: 연결된 ExerciseRecord가 있음 → exerciseRecordSnapshots에서 이미 처리
}
```

## Prevention

- `isFromThisApp` 필터를 변경할 때는 반드시 "ExerciseRecord가 없는 경우"도 고려
- `PersistentStoreRecovery` 스토어 삭제 시 HealthKit 데이터는 살아남는다는 점을 인식
- 데이터 소스 간 join 관계(ExerciseRecord ↔ HKWorkout)가 끊어질 수 있는 시나리오를 테스트

## Lessons Learned

1. SwiftData 스토어 삭제는 HealthKit 데이터에 영향을 주지 않으므로, 두 소스 간의 연결이 끊어지면 데이터 불일치 발생
2. "중복 방지" 필터(`isFromThisApp`)는 정상 경로에서만 유효하고, 복구 경로에서는 데이터 소실을 초래
3. 운동명 → 근육 데이터 매핑은 ExerciseLibrary를 통해 간접적으로 복구 가능 (metadata에 운동명이 보존되어 있으므로)
