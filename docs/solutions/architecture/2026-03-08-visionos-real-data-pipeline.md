---
tags: [visionos, healthkit, real-data, pipeline, shared-snapshot]
date: 2026-03-08
category: solution
status: implemented
---

# visionOS 실데이터 파이프라인 연결

## Problem

visionOS 앱의 모든 탭(Dashboard, Train, Wellness, Chart3D)이 더미 데이터에 의존.
실제 HealthKit 데이터와 SharedHealthSnapshot을 연결해야 함.

## Solution

### 핵심 아키텍처

1. **SharedHealthDataService 주입**: visionOS App → VisionContentView → 각 View/ViewModel에 `SharedHealthDataService?` 전달
2. **HealthKit 직접 접근**: visionOS에서 HealthKit 사용 가능. `WorkoutQuerying`, `HeartRateQuerying`, `BodyCompositionQuerying` 프로토콜 기반 서비스 주입
3. **VisionFetchResult<Value>**: Vision 레이어 공용 결과 래퍼. 값 + 메시지 구조

### 주요 패턴

```swift
// ViewModel에서 parallel fetch
async let snapshotResult = fetchSnapshot()
async let workoutsResult = healthKitAvailable
    ? fetchWorkouts()
    : VisionFetchResult(value: [], message: nil)
let (snapResult, wktsResult) = await (snapshotResult, workoutsResult)
```

```swift
// Chart View에서 pre-computed plottable data
@State private var plottableDataPoints: [ConditionDataPoint] = []
// loadData()에서:
let filtered = points.filter(\.isPlottable)
(dataPoints, plottableDataPoints) = (points, filtered)
```

### 적용 파일

| View/ViewModel | 데이터 소스 |
|----------------|-----------|
| VisionDashboardWorkspaceViewModel | SharedHealthSnapshot + HealthKit (workouts, body comp) |
| VisionTrainViewModel | HealthKit workouts + SharedHealthSnapshot (sleep/readiness modifiers) |
| VisionSpatialViewModel | SharedHealthSnapshot + HealthKit (HR, workouts) |
| VisionWellnessView | SharedHealthSnapshot (sleep, body) |
| ConditionScatter3DView | SharedHealthSnapshot (HRV, RHR, sleep, condition scores) |
| TrainingVolume3DView | HealthKit workouts via WorkoutQuerying |

### 타입 주의사항

- `ConditionScore.init`: `status` 파라미터 없음 (score에서 자동 계산)
- `SleepDailyDuration`: `SharedHealthSnapshot.SleepDailyDuration` (nested type)
- `SleepStage.Stage`: `.light` 없음 → `.core` 사용 (Apple 내부 명칭)
- `rhrCollection` 튜플: `(date: Date, min: Double, max: Double, average: Double)`

## Prevention

- visionOS View/ViewModel에 `SharedHealthDataService?`를 Optional로 전달하여 서비스 미연결 시 graceful degradation
- `VisionFetchResult` 공용 타입으로 DRY 유지
- Chart body에서 computed property 대신 `@State` pre-compute로 N× 재계산 방지
- `.task(id:)` 패턴으로 `.onChange` + `Task { }` 이중 패턴 제거
