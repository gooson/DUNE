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

## Implementation Steps

### Step 1: `localizedTitle` fallback 수정

`type`이 `activityType.typeName`과 다르면 metadata에서 온 커스텀 이름 →
그대로 반환. 같으면 generic name이므로 localized fallback 적용.

```swift
func localizedTitle(using correctionStore: WorkoutTypeCorrectionStore = .shared) -> String {
    if let corrected = correctionStore.correctedTitle(for: id) {
        return corrected
    }
    if let localized = WorkoutActivityType.localizedDisplayName(forStoredTitle: type) {
        return localized
    }
    // type이 activityType.typeName과 다르면 custom exercise name (metadata) → 보존
    // 같으면 generic name이므로 activityType.displayName으로 localize
    return type
}
```

핵심: `activityType.displayName` fallback 제거. 이유:
- `type == activityType.typeName`인 경우: `localizedDisplayName`이 이미 매칭 성공
- `type != activityType.typeName`인 경우: custom name → 보존 필요
- 따라서 `activityType.displayName` fallback 도달 경로가 없음

### Step 2: 테스트 수정

- `testLocalizedTitleFallsBackToActivityTypeDisplayName`: "Tempo Run" 시나리오는 실제 코드 경로에서 발생 불가 → 삭제 또는 실제 시나리오로 교체
- `healthKitDisplayNamePrefersStoredWorkoutTitle`: "Bench Press" 테스트 통과 확인

## Test Strategy

- 기존 테스트 `healthKitDisplayNamePrefersStoredWorkoutTitle` 통과 확인
- 기존 테스트 `healthKitDisplayNameLocalizesLegacyActivityTitle` 통과 확인
- "Tempo Run" 테스트 → 실제 시나리오(type == activityType.typeName)로 변경

## Risks

- "Tempo Run" 같은 서드파티 커스텀 이름이 실제로 type에 도달할 경우 영어로 표시됨
  → 하지만 `resolveTitle`이 우리 metadata key만 읽으므로 이 시나리오는 발생 불가
