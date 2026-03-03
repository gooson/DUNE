---
tags: [healthkit, flights-climbed, stair-climber, watch, cardio, barometric]
date: 2026-03-03
category: solution
status: implemented
---

# HealthKit Flights Climbed 수집 및 표시

## Problem

Stair Climber(천국의 계단) 운동 시 Apple Watch 기압 고도계로 측정되는 **flightsClimbed**(오른 층수) 데이터를
수집/표시하는 기능이 없어 계단 운동의 핵심 지표를 확인할 수 없었음.

## Solution

### 1. HealthKit 데이터 수집 (Watch)

`HKQuantityType(.flightsClimbed)`를 `readTypes`에 추가하고 `HKLiveWorkoutBuilderDelegate.didCollectDataOf`에서 실시간 수집:

```swift
case HKQuantityType(.flightsClimbed):
    let floors = stats.sumQuantity()?.doubleValue(for: .count()) ?? 0
    if floors > 0, floors.isFinite, floors < 10_000 {
        floorsValue = floors
    }
```

**검증 기준**: `> 0`, `isFinite`, `< 10_000` (물리적 상한)

### 2. 도메인 모델

`WorkoutActivityType`에 `isStairBased` computed property 추가:

```swift
var isStairBased: Bool {
    switch self {
    case .stairClimbing, .stairStepper: return true
    default: return false
    }
}
```

`WorkoutSummary`에 `flightsClimbed: Double?` 필드 추가.

### 3. Watch UI — 실시간 표시

`CardioMetricsView`에서 `isStairBased` 판별 후 distance 대신 floors를 primary metric으로 표시.

### 4. Watch UI — 운동 완료 요약

`SessionSummaryView`에서 stair 모드 시 "Floors Climbed" 표시 (distance/pace 대신).

### 5. iOS UI — HealthKit 워크아웃 상세

`HealthKitWorkoutDetailView`의 stats grid에 flightsClimbed 카드 추가.

### 6. iOS WorkoutQueryService

`HKWorkout.statistics(for: .flightsClimbed)` 추출 로직 추가.

## Key Decisions

| 결정 | 근거 |
|------|------|
| iOS CardioSessionSummaryView에 floors 미추가 | iOS 타이머 기반 세션은 HKLiveWorkoutBuilder 미사용 → 기압 고도계 데이터 없음 |
| `isStairBased`를 Domain layer에 배치 | View에서 inline switch 대신 Domain computed property로 layer boundary 준수 |
| 검증 `> 0` 통일 (not `>= 0`) | 0층은 의미 없는 값, 모든 경로에서 동일 기준 |
| WatchWorkoutUpdate DTO에 floors 미추가 | Cardio workout은 HealthKit sync로 데이터 전달, WatchConnectivity DTO 불필요 |

## Prevention

- 새 HealthKit metric 추가 시 **Watch 수집 → Domain 모델 → Watch UI → iOS 쿼리 → iOS UI** 전체 파이프라인 점검
- 검증 기준(> 0, isFinite, 상한)은 모든 경로에서 동일하게 적용
- `isDistanceBased`와 유사한 패턴으로 `isStairBased` 등 activity-type 쿼리는 Domain enum에 배치

## Related Files

- `DUNEWatch/Managers/WorkoutManager.swift` — 실시간 수집
- `DUNEWatch/Views/CardioMetricsView.swift` — Watch 실시간 표시
- `DUNEWatch/Views/SessionSummaryView.swift` — Watch 완료 요약
- `DUNE/Domain/Models/WorkoutActivityType.swift` — `isStairBased`
- `DUNE/Domain/Models/HealthMetric.swift` — `WorkoutSummary.flightsClimbed`
- `DUNE/Data/HealthKit/WorkoutQueryService.swift` — iOS 추출
- `DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift` — iOS 상세 표시
