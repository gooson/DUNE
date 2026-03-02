---
tags: [healthkit, cardio, gps, live-tracking, clocationmanager, hkworkoutsession, iphone]
date: 2026-03-02
category: solution
status: implemented
---

# iOS Cardio Live Tracking (GPS + HKWorkoutSession)

## Problem

iPhone 단독 유산소 운동(러닝, 사이클링, 워킹 등) 시 실시간 거리/페이스/심박/칼로리 추적이 불가능했음.
Watch에는 `CardioMetricsView`가 있었으나 iPhone에는 해당 기능이 없어 유산소 기록이 수동 입력에 의존.

## Solution

### Architecture

```
ExerciseStartView (Outdoor/Indoor 분기)
    ↓ navigationDestination
CardioSessionView (TimelineView 1초 업데이트)
    ↓ @State
CardioSessionViewModel (세션 lifecycle + record 생성)
    ↓ owns
CardioSessionManager (CLLocationManager + HKWorkoutSession)
    ↓ writes via
WorkoutWriteService (distance sample 지원 추가)
```

### Key Design Decisions

1. **CLLocationManager + HKWorkoutSession 조합**: GPS 거리는 CLLocationManager, 심박/칼로리는 HKWorkoutSession(Watch 연동)
2. **GPS 필터링**: `horizontalAccuracy <= 50m`, 연속 업데이트 간 점프 `< 100m`
3. **일시정지 처리**: `pausedDuration` 누적기로 활성 시간만 추적. 일시정지 중 GPS 업데이트 무시(`state == .running` guard)
4. **startDate 타이밍**: HK 세션 설정 성공 후에만 `startDate` 할당 (실패 시 stale state 방지)
5. **위치 권한**: `requestWhenInUseAuthorization()` 호출 + `locationManagerDidChangeAuthorization` 콜백에서 업데이트 시작
6. **거리 유형 분기**: cycling → `distanceCycling`, swimming → `distanceSwimming`, default → `distanceWalkingRunning`

### Paused Duration Tracking Pattern

```swift
// pause()
pauseStart = Date()

// resume()
if let pauseStart {
    pausedDuration += Date().timeIntervalSince(pauseStart)
}
pauseStart = nil

// activeElapsedTime(at:)
var elapsed = now.timeIntervalSince(startDate) - pausedDuration
if let pauseStart, state == .paused {
    elapsed -= now.timeIntervalSince(pauseStart)
}
return Swift.max(elapsed, 0)
```

### Distance-Based Exercise Detection

`WorkoutActivityType.resolveDistanceBased(from:name:)` 3단계 해석:
1. ID → rawValue 직접 매핑
2. Stem 추출 (e.g., "outdoor-running" → "running")
3. Name 키워드 추론

### Files

| File | Role |
|------|------|
| `Data/HealthKit/CardioSessionManager.swift` | GPS + HK 세션 관리 |
| `Presentation/Exercise/CardioSessionViewModel.swift` | 세션 lifecycle + record 생성 |
| `Presentation/Exercise/CardioSessionView.swift` | 실시간 UI |
| `Presentation/Exercise/ExerciseStartView.swift` | Outdoor/Indoor 분기 추가 |
| `Data/HealthKit/WorkoutWriteService.swift` | distance sample 지원 |

## Prevention

- **일시정지 시간 계산**: 항상 `pausedDuration` 누적기 사용. `Date() - startDate`로 wall-clock 시간 사용 금지
- **위치 권한**: `startUpdatingLocation()` 전 반드시 권한 확인/요청
- **HK 세션 실패**: `startDate` 설정 전 HK 세션 설정 완료 확인
- **#if DEBUG**: 테스트 전용 mutator는 반드시 `#if DEBUG` guard
- **HR 범위**: 프로젝트 전체 20-300 bpm 통일 (`input-validation.md`)
