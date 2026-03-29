---
tags: [sleep, weather, location, bug-fix]
date: 2026-03-30
category: plan
status: approved
---

# Fix: 수면환경 데이터 표시 안되는 문제

## Problem

`MetricDetailView`의 수면 상세 화면에서 "Sleep Environment" 카드가 항상 `SleepDataPlaceholder()`를 표시한다.

### Root Cause

`MetricDetailViewModel.loadSleepEnvironment()` (라인 652-653):

```swift
guard locationService.isAuthorized,
      let location = locationService.currentLocation else { return }
```

- `MetricDetailViewModel`은 자체 `LocationService()` 인스턴스를 생성 (라인 342)
- 이 인스턴스에서 `requestLocation()`이 한 번도 호출되지 않음
- 따라서 `currentLocation`은 항상 `nil`
- guard 실패 → silent return → `sleepEnvironment`가 nil → 플레이스홀더 표시

### 대조: WeatherProvider (정상 동작)

`WeatherProvider.fetchCurrentWeather()` (라인 49)는 `locationService.requestLocation()`을 **능동적으로** 호출:

```swift
let location = try await locationService.requestLocation()
```

## Affected Files

| 파일 | 변경 |
|------|------|
| `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift` | `loadSleepEnvironment`에서 `requestLocation()` 사용 |
| `DUNE/DUNETests/AnalyzeSleepEnvironmentUseCaseTests.swift` | 기존 테스트 확인 (UseCase 자체 변경 없으므로 추가 불필요) |

## Implementation Steps

### Step 1: `loadSleepEnvironment`에서 능동적 위치 요청

`currentLocation` 수동 체크 대신 `requestLocation()`을 사용:

```swift
private func loadSleepEnvironment(today: Date, calendar: Calendar, requestID: Int) async {
    let days = 30
    let start = calendar.date(byAdding: .day, value: -days, to: today) ?? today
    let end = today

    do {
        guard await locationService.isAuthorized else { return }
        let location = try await locationService.requestLocation()
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        // ... rest unchanged
```

### Key Changes

1. `guard locationService.isAuthorized` → `guard await locationService.isAuthorized` (MainActor 접근)
2. `let location = locationService.currentLocation` → `let location = try await locationService.requestLocation()`
3. `requestLocation()`이 throw하면 catch 블록에서 로깅 (기존 에러 핸들링 활용)

## Test Strategy

- **기존 UseCase 테스트**: `AnalyzeSleepEnvironmentUseCaseTests` — UseCase 로직 자체는 변경 없음
- **수동 확인**: 수면 상세 화면에서 환경 카드가 데이터를 표시하는지 확인
- **빌드 검증**: `scripts/build-ios.sh`

## Edge Cases

1. **위치 권한 미허용**: `isAuthorized` false → silent return (기존과 동일)
2. **위치 요청 실패/타임아웃**: `requestLocation()`이 throw → catch 블록에서 로깅 (기존 에러 핸들링)
3. **위치 요청 중복 (`locationRequestInFlight`)**: `requestLocation()`이 `WeatherError.locationRequestInFlight` throw → catch에서 로깅
4. **캐시된 위치 존재**: `requestLocation()`이 내부적으로 60분 미만 캐시 반환 (추가 네트워크 없음)

## Risk Assessment

- **낮음**: 단일 guard 조건 변경. `requestLocation()`은 이미 검증된 패턴 (WeatherProvider에서 사용 중)
- `requestLocation()`은 30초 타임아웃이 있으므로 무한 대기 없음
- 다른 수면 인사이트 카드 로딩에 영향 없음 (병렬 async let)
