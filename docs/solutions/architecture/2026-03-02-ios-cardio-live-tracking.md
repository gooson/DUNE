---
tags: [cardio, gps, distance, live-tracking, location, healthkit, ios, timer]
date: 2026-03-02
category: solution
status: implemented
---

# iOS Cardio Live Tracking

## Problem

iOS에서 유산소 운동 시 실시간 타이머, GPS 거리, 페이스, 칼로리를 표시하는 기능이 없어 Watch에서만 카디오 세션 추적이 가능했다. iPhone 단독 사용자에게 동일한 경험을 제공해야 했다.

## Solution

### Architecture: ViewModel + Protocol-based DI

Watch의 단일 WorkoutManager 패턴과 달리, iOS에서는 **CardioSessionViewModel** + **LocationTrackingServiceProtocol** 구조를 채택하여 테스트 용이성과 레이어 분리를 확보했다.

```
Domain:  LocationTrackingServiceProtocol (Foundation only)
Data:    LocationTrackingService (CLLocationManager)
Presentation: CardioSessionViewModel (@Observable @MainActor)
              CardioStartSheet / CardioSessionView / CardioSessionSummaryView
```

### GPS Distance Tracking

CLLocationManager 래퍼가 NSLock으로 스레드 안전한 거리 누적을 수행:
- 정확도 필터: `horizontalAccuracy < 20m`
- 거리 필터: `distanceFilter = 10m`
- 글리치 방어: 점프 > 100m 무시

### Location Authorization

`CheckedContinuation` 패턴으로 권한 콜백을 `async/await`로 브릿지:

```swift
func startTracking() async throws {
    if status == .notDetermined {
        locationManager.requestWhenInUseAuthorization()
        let grantedStatus = await withCheckedContinuation { continuation in
            self.authContinuation = continuation
        }
        guard grantedStatus == .authorizedWhenInUse || ... else { throw ... }
    }
}

func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if status != .notDetermined, let continuation = authContinuation {
        authContinuation = nil
        continuation.resume(returning: status)
    }
}
```

**핵심**: `Task.sleep(1s)` 기반 폴링은 사용자 응답 시간을 예측할 수 없어 실패. Continuation이 delegate 콜백을 비동기적으로 대기.

### Sheet Dismiss 패턴

3단 NavigationStack (Sheet → CardioStartSheet → CardioSessionView → SummaryView)에서 `dismiss()`는 한 단계만 pop. **`onComplete` 콜백**을 sheet root까지 전달하여 전체 sheet를 한 번에 닫는다:

```swift
// CardioStartSheet
.navigationDestination(item: $selectedOutdoor) { isOutdoor in
    CardioSessionView(
        exercise: exercise,
        onComplete: { dismiss() }  // sheet root의 dismiss
    )
}

// CardioSessionSummaryView
onComplete()  // 저장 완료 후 sheet root의 dismiss 호출
```

### HealthKit Write Race 방지

SwiftData `@Model` 객체를 비동기 Task에서 직접 참조하면 context 해제 후 crash 위험. `persistentModelID`를 캡처하여 완료 후 re-fetch:

```swift
let recordID = record.persistentModelID
Task { @MainActor in
    let hkID = try await WorkoutWriteService().saveWorkout(input)
    if let liveRecord = modelContext.model(for: recordID) as? ExerciseRecord {
        liveRecord.healthKitWorkoutID = hkID
    }
}
```

### Timer Race 방지

`end()` 시 `timerTask?.cancel()`을 `elapsedSeconds` 할당 **전에** 호출하여, timer Task의 마지막 tick이 최종 값을 덮어쓰는 것을 방지:

```swift
func end() async {
    timerTask?.cancel()       // FIRST: stop timer
    timerTask = nil
    // THEN: compute final elapsed
    elapsedSeconds = pausedAccumulated
}
```

### Protocol의 async 프로퍼티 제거

`totalDistanceMeters`를 `async`로 선언하면 매 1초 tick마다 새 Task가 spawn되어 Task 누적 발생. NSLock 기반 동기 읽기이므로 `async` 제거:

```swift
// BEFORE (bad): spawns nested Task every second
var totalDistanceMeters: Double { get async }

// AFTER (good): direct synchronous read in timer loop
var totalDistanceMeters: Double { get }
```

## Key Decisions

1. **CardioSessionRecord struct**: Correction #90 준수 — 8-field tuple 대신 Sendable struct 사용
2. **exerciseType = exerciseID**: ExerciseRecord 생성 시 exerciseName이 아닌 exerciseID 사용 (기존 strength 패턴 일관성)
3. **Distance cap 250km**: 물리적 최대값 기반 검증 (500km에서 하향)
4. **CLLocationManager @State 캐싱**: computed property에서 매 body 렌더마다 인스턴스 생성 방지
5. **`.navigationDestination(item:)`**: Bool + Optional 2개 @State 대신 단일 Optional로 navigation 제어

## Prevention

- Location 권한 대기 시 **`Task.sleep` 사용 금지** → CheckedContinuation 사용
- SwiftData `@Model` 객체를 async Task에 **직접 캡처 금지** → `persistentModelID` 캡처 후 re-fetch
- 다단 NavigationStack에서 `dismiss()`는 한 단계만 pop → **`onComplete` 콜백** 패턴 사용
- Protocol 프로퍼티의 **불필요한 `async`** 선언은 호출부에 Task spawn을 강제 → 실제 구현이 동기면 `async` 제거
- **`timerTask?.cancel()`은 최종 값 계산 전에** 호출

## Files

| File | Role |
|------|------|
| `Domain/Services/LocationTrackingServiceProtocol.swift` | **신규** — GPS 추적 Domain 프로토콜 |
| `Data/Location/LocationTrackingService.swift` | **신규** — CLLocationManager 래퍼 |
| `Data/HealthKit/WorkoutWriteService.swift` | 거리 샘플 추가 (totalDistanceMeters) |
| `Presentation/Exercise/CardioSession/CardioSessionViewModel.swift` | **신규** — 세션 상태 머신 |
| `Presentation/Exercise/CardioSession/CardioStartSheet.swift` | **신규** — Indoor/Outdoor 선택 |
| `Presentation/Exercise/CardioSession/CardioSessionView.swift` | **신규** — 실시간 메트릭 UI |
| `Presentation/Exercise/CardioSession/CardioSessionSummaryView.swift` | **신규** — 요약 + 저장 |
| `Presentation/Exercise/ExerciseStartView.swift` | 카디오 분기 추가 |
| `DUNETests/CardioSessionViewModelTests.swift` | **신규** — 16 유닛 테스트 |
