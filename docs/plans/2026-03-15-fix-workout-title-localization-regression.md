---
tags: [healthkit, workout-title, localization, regression]
date: 2026-03-15
category: plan
status: draft
---

# Plan: 운동 기록 제목이 "웨이트 트레이닝"으로 뭉개지는 회귀 버그 수정

## Problem

최근 변경(`2026-03-15-healthkit-custom-title-localization-fallback`)에서
`WorkoutSummary.localizedTitle`의 fallback 체인이 변경되면서,
DUNE 앱이 HealthKit metadata에 저장한 커스텀 운동명(Bench Press, Squat 등)이
`activityType.displayName`("웨이트 트레이닝")으로 덮어씌워지는 회귀 발생.

### Root Cause

```swift
// WorkoutActivityType+View.swift:246-248
if activityType != .other {
    return activityType.displayName  // "Bench Press" → "웨이트 트레이닝" !!
}
```

`localizedDisplayName(forStoredTitle: "Bench Press")`가 nil을 반환하면
(known activity type name이 아니므로), `activityType.displayName`으로 fallback.
이 fallback이 **metadata에서 온 커스텀 운동명도 덮어씀**.

### 핵심 구분

| `type` 값 | 출처 | 올바른 동작 |
|-----------|------|------------|
| "Bench Press" | DUNE metadata (`com.dune.workout.exerciseName`) | **그대로 표시** |
| "Strength" | `activityType.typeName` (metadata 없음) | `localizedDisplayName`이 이미 처리 |
| "Tempo Run" | 실제로 발생하지 않음 (resolveTitle은 우리 metadata key만 읽음) | N/A |

## Affected Files

| File | Change | Risk |
|------|--------|------|
| `DUNE/Presentation/Shared/Extensions/WorkoutActivityType+View.swift` | `localizedTitle` fallback 수정 | Medium |
| `DUNETests/WorkoutTypeCorrectionStoreTests.swift` | "Tempo Run" 테스트 수정 | Low |
| `DUNE/Presentation/Activity/ActivityViewModel.swift` | 고아 HK 워크아웃에서 근육 데이터 복구 | Medium |

## Implementation Steps

### Step 1: `localizedTitle` fallback 수정 (완료)

`activityType.displayName` fallback 제거. 이유:
- `type == activityType.typeName`인 경우: `localizedDisplayName`이 이미 매칭 성공
- `type != activityType.typeName`인 경우: custom name → 보존 필요
- 따라서 `activityType.displayName` fallback 도달 경로가 없음

### Step 2: 테스트 수정 (완료)

- `testLocalizedTitleFallsBackToActivityTypeDisplayName` → `testLocalizedTitlePreservesCustomMetadataExerciseName`으로 교체
- "Bench Press" 보존 테스트 통과 확인

### Step 3: 고아 HK 워크아웃에서 근육 데이터 복구 (완료)

SwiftData 스토어 복구(PersistentStoreRecovery)로 ExerciseRecord가 삭제된 경우,
HealthKit에 남아있는 앱 생성 워크아웃에서 근육 데이터를 복구.

`recomputeFatigueAndSuggestion()`에서:
1. `manualRecordsCache`의 `healthKitWorkoutID`로 연결된 HK ID 집합 구성
2. 앱 생성 HK 워크아웃 중 연결된 ExerciseRecord가 없는 것(고아)을 식별
3. 고아 워크아웃의 exercise name을 라이브러리에서 검색하여 근육 데이터 획득
4. 라이브러리 매칭 실패 시 activityType 기본 근육 데이터로 fallback

## Test Strategy

- `testLocalizedTitlePreservesCustomMetadataExerciseName` 통과 확인
- `testLocalizedTitleReturnsRawTypeForOtherActivity` 통과 확인
- `testWorkoutSummaryLocalizedTitleUsesCorrectionStore` 통과 확인
- 고아 워크아웃 복구: 기존 `recomputeFatigueAndSuggestion` 경로 테스트는 ViewModel 통합 테스트 영역

## Risks

- 라이브러리 검색이 대소문자/로케일 차이로 실패할 수 있음 → `caseInsensitiveCompare` 사용
- 고아 워크아웃이 많을 경우 검색 비용 → `recentWorkouts`는 최근 N일로 제한되어 있으므로 실질적 부담 없음
- 라이브러리에 없는 커스텀 운동명 → `activityType.primaryMuscles` fallback 사용
