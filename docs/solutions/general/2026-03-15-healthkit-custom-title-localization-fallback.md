---
tags: [healthkit, localization, workout-title, badge, ui, fixedSize]
date: 2026-03-15
category: general
status: implemented
related_files:
  - DUNE/Presentation/Shared/Extensions/WorkoutActivityType+View.swift
  - DUNE/Presentation/Exercise/Components/WorkoutBadgeView.swift
related_solutions:
  - docs/solutions/healthkit/2026-03-08-today-activity-workout-title-parity.md
  - docs/solutions/healthkit/2026-03-07-healthkit-workout-title-roundtrip.md
---

# Solution: HealthKit 커스텀 운동 타이틀 한국어화 + 뱃지 줄바꿈 수정

## Problem

### 증상 1: 영어 운동 이름
HealthKit 워크아웃 중 커스텀 타이틀(Tempo Run, Upper Strength, Long Ride, Ridge Hike 등)이 한국어로 번역되지 않고 영어 원문 그대로 Activity 리스트에 표시됨.

### 증상 2: 뱃지 텍스트 줄바꿈
10K, PR 뱃지가 compact row에서 공간 부족 시 "10"+"K", "P"+"R"로 줄바꿈됨.

### Root Cause

**영어 이름**: `WorkoutSummary.localizedTitle`의 fallback 체인이 `localizedDisplayName(forStoredTitle:)` → raw `type`이었음. 커스텀 HealthKit 타이틀("Tempo Run")은 어떤 `typeName`과도 정확히 일치하지 않아 nil 반환 → 영어 raw string으로 fallback. 하지만 `activityType`은 `.running`으로 정확히 설정되어 있었으므로 이를 활용하면 한국어 표시 가능.

**뱃지 줄바꿈**: `WorkoutBadgeView`의 milestone/PR 뱃지에 `.fixedSize()` 미적용 → HStack에서 exercise name이 공간을 차지하면 뱃지가 압축되어 내부 텍스트 줄바꿈 발생.

## Solution

### 1. localizedTitle fallback 개선

```swift
func localizedTitle(using correctionStore: WorkoutTypeCorrectionStore = .shared) -> String {
    if let corrected = correctionStore.correctedTitle(for: id) {
        return corrected
    }
    if let localized = WorkoutActivityType.localizedDisplayName(forStoredTitle: type) {
        return localized
    }
    if activityType != .other {
        return activityType.displayName
    }
    return type
}
```

Fallback 체인: CorrectionStore → typeName 매칭 → **activityType.displayName** → raw type

### 2. 뱃지 fixedSize

`WorkoutBadgeView.milestone()`과 `.personalRecord()`에 `.fixedSize()` 추가. `metricsRow`의 기존 패턴과 동일.

## Prevention

- HealthKit 커스텀 타이틀은 Apple Fitness의 workout type 변형(Tempo Run, Long Ride 등)으로 `typeName` 매칭이 불가능한 경우가 많음
- `activityType`은 HKWorkoutActivityType에서 정확히 매핑되므로 안정적인 fallback
- 새 ornament view(badge, chip)에는 항상 `.fixedSize()` 적용 검토

## Lessons Learned

- `localizedDisplayName(forStoredTitle:)`는 정확한 `typeName` 매칭만 지원하므로, Apple이 제공하는 커스텀 workout 이름(서브타입)은 매칭 실패
- `activityType`은 HKWorkoutActivityType enum에서 직접 매핑되므로 항상 정확 → 안전한 localization fallback
