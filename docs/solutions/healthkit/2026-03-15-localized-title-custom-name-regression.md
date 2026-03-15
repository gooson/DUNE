---
tags: [healthkit, workout-title, localization, regression, localizedTitle]
date: 2026-03-15
category: healthkit
status: implemented
related_files:
  - DUNE/Presentation/Shared/Extensions/WorkoutActivityType+View.swift
  - DUNETests/WorkoutTypeCorrectionStoreTests.swift
related_solutions:
  - docs/solutions/healthkit/2026-03-07-healthkit-workout-title-roundtrip.md
  - docs/solutions/general/2026-03-15-healthkit-custom-title-localization-fallback.md
---

# Solution: localizedTitle fallback이 커스텀 운동명을 덮어씌우는 회귀 수정

## Problem

### 증상

Activity 탭에서 최근 근력 운동 기록이 모두 "웨이트 트레이닝"으로 표시됨. "Bench Press", "Squat" 등 개별 운동명이 사라짐. 오래된 기록(ExerciseRecord가 있는 것)은 정상.

### Root Cause

같은 날 적용된 `2026-03-15-healthkit-custom-title-localization-fallback` 수정에서 `WorkoutSummary.localizedTitle`의 fallback 체인에 `activityType.displayName` 분기를 추가:

```swift
// 문제: custom metadata name도 activityType.displayName으로 대체됨
if activityType != .other {
    return activityType.displayName  // "Bench Press" → "웨이트 트레이닝"
}
```

이 fallback의 의도는 Apple Fitness의 커스텀 워크아웃 이름("Tempo Run")을 한국어화하려는 것이었지만, 실제로는 DUNE 앱이 HealthKit metadata에 저장한 운동명까지 덮어씌움.

### 잘못된 가정

"Tempo Run"이 `WorkoutSummary.type`에 도달한다고 가정했지만, `HealthKitWorkoutTitle.resolveTitle()`은 DUNE 전용 metadata key(`com.dune.workout.exerciseName`)만 읽음. 서드파티 앱 워크아웃은 이 key가 없으므로 `type = activityType.typeName`이 되고, `localizedDisplayName(forStoredTitle:)`이 이미 정상 처리함.

## Solution

`activityType.displayName` fallback 분기를 제거. 이 분기에 도달하는 정당한 경로가 없음:

- `type == activityType.typeName`인 경우: `localizedDisplayName(forStoredTitle:)` 가 이미 매칭
- `type != activityType.typeName`인 경우: custom exercise name → 보존 필요

```swift
func localizedTitle(using correctionStore: WorkoutTypeCorrectionStore = .shared) -> String {
    if let corrected = correctionStore.correctedTitle(for: id) {
        return corrected
    }
    if let localized = WorkoutActivityType.localizedDisplayName(forStoredTitle: type) {
        return localized
    }
    return type
}
```

## Prevention

- `localizedTitle` fallback 체인 변경 시 반드시 **custom metadata 운동명** 시나리오를 테스트
- `HealthKitWorkoutTitle.resolveTitle()`이 읽는 metadata key 범위를 확인하고, 서드파티 워크아웃의 `type` 값이 실제로 어떻게 설정되는지 trace
- 가설 기반 수정 전에 실제 데이터 흐름을 코드에서 추적

## Lessons Learned

1. Presentation fallback을 확장할 때는 Data layer(`resolveTitle`)의 출력 가능 범위를 먼저 분석해야 한다
2. "이 시나리오가 발생할 수 있다"는 가정은 실제 코드 경로 추적으로 검증해야 한다
3. 같은 날 적용한 수정이 다른 정상 경로를 깨뜨릴 수 있으므로, 관련 테스트(`healthKitDisplayNamePrefersStoredWorkoutTitle`)를 반드시 확인
