---
tags: [swiftui-state-caching, computed-property, healthkit-validation, error-propagation, async-let, task-id, partial-failure, chart-performance, review-fix]
category: general
date: 2026-02-19
severity: important
related_files:
  - Dailve/Presentation/Activity/Components/TrainingLoadChartView.swift
  - Dailve/Data/HealthKit/EffortScoreService.swift
  - Dailve/Data/HealthKit/WorkoutQueryService.swift
  - Dailve/Domain/Services/PersonalRecordService.swift
  - Dailve/Presentation/Activity/ActivityViewModel.swift
  - Dailve/Presentation/Activity/Components/ExerciseListSection.swift
related_solutions:
  - general/2026-02-17-review-fix-activity-tab
---

# Solution: 6관점 리뷰 수정 — 차트 캐싱, 에러 전파, 값 검증

## Problem

Enhanced Workout Display 기능 구현 후 6관점 리뷰에서 P1~P3 총 9개 문제 발견.

### Symptoms

- **P1 성능**: TrainingLoadChartView의 `movingAverage`(O(N) 루프)와 `weekSummary`(2×O(N) filter)가 SwiftUI body 접근 시 매번 재계산
- **P1 에러**: EffortScoreService.saveEffortScore()가 잘못된 입력을 silent return — caller가 성공/실패 구분 불가
- **P2 UX**: ActivityViewModel이 4개 병렬 fetch 중 일부 실패 시 사용자에게 알림 없음
- **P2 데이터**: WorkoutQueryService distance 값에 `isFinite` 검증 없음 — NaN/Inf 가능
- **P3 성능**: EffortScoreService가 effort score 2개를 순차 fetch
- **P3 데이터**: PersonalRecordService elevation 상한 없음, TrainingLoadService 산술 결과 NaN/Inf 미검증
- **P3 중복**: ExerciseListSection에서 동일 dedup 로직 3회 호출 (onAppear + 2×onChange)

### Root Cause

1. **Chart computed property**: SwiftUI body 내 접근되는 computed property는 뷰 재렌더마다 호출됨. O(1)이면 무방하지만 O(N) 루프는 성능 저하.
2. **Silent guard return**: `guard ... else { return }` 패턴이 `throws` 함수에서도 사용되어 에러 정보 소실.
3. **Partial failure 무시**: `async let` 병렬 fetch 후 개별 실패를 catch하지만 사용자에게 전체적 상태 미보고.
4. **HealthKit 값 신뢰**: 센서 오류, 수동 입력 오류로 비현실적 값(거리 999km, 고도 50km)이 유입 가능.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| TrainingLoadChartView.swift | computed var → `@State` + `func` | 매 렌더 O(N) 재계산 방지 |
| EffortScoreService.swift | silent guard → `throw EffortScoreError` | 에러 정보 전파 |
| EffortScoreService.swift | sequential → `async let` | 병렬 effort score fetch |
| ActivityViewModel.swift | partial failure 카운트 + 에러 메시지 | 사용자 UX 개선 |
| WorkoutQueryService.swift | distance에 `isFinite, < 500_000` 추가 | 비현실적 값 차단 |
| WorkoutQueryService.swift | elevation에 `< 10_000` 추가 | 에베레스트 초과 차단 |
| PersonalRecordService.swift | elevation에 `< 10_000` 추가 | 동일 검증 일관성 |
| PersonalRecordService.swift | 산술 결과 `isFinite, !isNaN` guard | NaN/Inf 전파 방지 |
| ExerciseListSection.swift | 3× dedup → `.task(id:)` 1회 | 코드 중복 제거 |

### Key Code

**패턴 1: Chart computed property @State 캐싱**

```swift
// Before: 매 렌더마다 O(N) 재계산
private var movingAverage: [ChartDataPoint] { ... } // body에서 접근

// After: @State + 명시적 무효화
@State private var cachedMovingAverage: [ChartDataPoint] = []

.onAppear { recalculateChartData() }
.onChange(of: data.count) { _, _ in recalculateChartData() }

private func recalculateChartData() {
    cachedMovingAverage = computeMovingAverage()
}
private func computeMovingAverage() -> [ChartDataPoint] { ... }
```

**패턴 2: Silent guard → Typed error**

```swift
// Before: 에러 정보 소실
guard score >= 1, score <= 10 else { return }

// After: 구체적 에러 throw
enum EffortScoreError: LocalizedError {
    case invalidScore(Double)
    case invalidWorkoutID(String)
    case workoutNotFound(String)
}
guard score >= 1, score <= 10, score.isFinite else {
    throw EffortScoreError.invalidScore(score)
}
```

**패턴 3: Partial failure 보고**

```swift
let failedCount = [
    exerciseResult.weeklyData.isEmpty && exerciseResult.todayMetric == nil,
    stepsResult.weeklyData.isEmpty && stepsResult.todayMetric == nil,
    workoutsResult.isEmpty,
    loadResult.isEmpty
].filter(\.self).count
if failedCount > 0, failedCount < 4 {
    errorMessage = "일부 데이터를 불러올 수 없습니다 (\(failedCount)/4 소스)"
}
```

**패턴 4: .task(id:) 통합**

```swift
// Before: onAppear + 2× onChange — 동일 로직 3회
.onAppear { externalWorkouts = workouts.filteringAppDuplicates(against: exerciseRecords) }
.onChange(of: workouts.count) { _, _ in /* 동일 */ }
.onChange(of: exerciseRecords.count) { _, _ in /* 동일 */ }

// After: .task(id:) 1회
.task(id: "\(workouts.count)-\(exerciseRecords.count)") {
    externalWorkouts = workouts.filteringAppDuplicates(against: exerciseRecords)
}
```

## Prevention

### Checklist Addition

- [ ] Chart View에서 computed property가 O(1) 이상이면 `@State` 캐싱 적용 여부 확인
- [ ] `throws` 함수의 guard에서 `return` 대신 `throw`를 사용하는지 확인
- [ ] `async let` 4개+ 병렬 fetch 후 partial failure 보고 로직이 있는지 확인
- [ ] HealthKit 값에 물리적 상한이 적용되었는지 확인 (거리 500km, 고도 10km)
- [ ] 동일 로직이 `onAppear` + `onChange` 양쪽에 있으면 `.task(id:)`로 통합 가능한지 확인

### Rule Addition (if applicable)

기존 규칙으로 충분:
- Correction #8: computed property 캐싱
- Correction #18: 나눗셈 결과 이중 검증
- Correction #22: HealthKit 값 범위 검증
- Correction #25: partial failure 보고

## Lessons Learned

1. **`@State` 캐싱은 차트 뷰에서 특히 중요**: 차트는 selection/interaction으로 빈번히 재렌더되므로 O(N) computed property의 영향이 증폭됨.
2. **Silent failure는 서비스 레이어에서 가장 위험**: UI 레이어는 에러 표시를 위해 에러 정보가 필요. `guard...return`은 View에서는 허용되지만 Service에서는 `throw` 필수.
3. **`.task(id:)`는 `onAppear` + `onChange` 조합의 상위 호환**: 동일 로직을 의존 값 변경 시 자동 재실행하므로 코드 중복과 실행 순서 문제를 동시에 해결.
4. **HealthKit 값 상한은 쿼리 경로마다 일관 적용**: `WorkoutQueryService`와 `PersonalRecordService`가 동일 데이터(elevation)를 다르게 검증하면 한쪽에서 비현실적 값이 통과.
