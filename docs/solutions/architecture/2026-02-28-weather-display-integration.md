---
tags: [weather, weatherkit, corelocation, wave-background, coaching, environment-key]
date: 2026-02-28
category: solution
status: implemented
---

# WeatherKit Integration for Today Tab

## Problem

Today 탭에 실시간 날씨 정보를 표시하고, 날씨 기반 코칭과 배경 시각 효과를 제공해야 함.
WeatherKit/CoreLocation은 Data 레이어에만 존재해야 하며, Domain/Presentation에 누출 금지.

## Solution

### Architecture

```
Domain:
  WeatherConditionType (enum, 11 cases)
  WeatherSnapshot (DTO: temp, humidity, UV, wind, forecast)
  WeatherAtmosphere (wave parameter DTO)
  CoachingEngine (weather trigger evaluation)

Data:
  LocationService (@MainActor, CLLocationManager wrapper)
  WeatherDataService (WeatherKit fetch + inline cache)
  WeatherProvider (LocationService + WeatherDataService 조합)

Presentation:
  WeatherCard (InlineCard, 현재 날씨 + 6시간 예보)
  WeatherConditionType+View (SF Symbol, label, color 매핑)
  WeatherAtmosphere+View (wave params, gradient, environment key)
  DashboardViewModel (weatherProvider optional injection)
  TabWaveBackground (atmosphere-reactive wave rendering)
```

### Key Patterns

1. **WeatherProviding protocol**: ViewModel이 CoreLocation을 import하지 않도록 단일 `fetchCurrentWeather()` 인터페이스 제공

2. **Graceful degradation**: 날씨는 non-critical — 실패 시 nil 반환, UI에서 `if let weather` 분기로 카드 숨김

3. **Inline cache**: 15분 TTL, NSLock + optional로 WeatherDataService 내부에 구현. 별도 클래스 불필요 (단일 소비자)

4. **Environment-driven atmosphere**: `.environment(\.weatherAtmosphere, viewModel.weatherAtmosphere)`로 TabWaveBackground에 전달. preset == .today일 때만 활성화

5. **Stored property for atmosphere**: `weatherAtmosphere`를 computed property로 만들면 매 렌더마다 `WeatherAtmosphere.from()` 실행. `loadData()`에서 1회 계산 후 stored property에 저장 (Correction #8/#52 적용)

6. **Conservative @unknown default**: 미인식 WeatherCondition을 `.cloudy`로 매핑. `.clear`로 매핑하면 심각한 기상 조건에서 "야외 운동 추천" 코칭이 나올 수 있음

### Continuation Safety (LocationService)

```swift
// BAD: 동시 호출 시 첫 번째 continuation 영구 orphan
func requestLocation() async throws -> CLLocation {
    return try await withCheckedThrowingContinuation { continuation in
        locationContinuation = continuation // overwrites!
        manager.requestLocation()
    }
}

// GOOD: guard로 동시 호출 차단
guard locationContinuation == nil else {
    throw WeatherError.locationRequestInFlight
}
return try await withCheckedThrowingContinuation { continuation in
    locationContinuation = continuation
    manager.requestLocation()
}
```

### Coaching Triggers (Priority)

| Priority | Trigger | Condition |
|----------|---------|-----------|
| P2 (high) | Extreme heat | feelsLike >= 35°C |
| P2 (high) | Freezing | feelsLike <= 0°C |
| P3 (medium) | High UV | uvIndex >= 8 |
| P4 (standard) | Rain/Snow | condition match |
| P4 (standard) | High humidity | humidity >= 80% (heat와 비중복) |
| P5 (low) | Favorable | isFavorableOutdoor && isDaytime && 다른 경고 없음 |

## Prevention

1. **Domain에 WeatherKit import 금지**: `WeatherConditionType` enum으로 추상화. Data 레이어에서 `mapCondition()`으로 변환
2. **ViewModel에 CoreLocation import 금지**: `WeatherProviding` protocol로 추상화
3. **CalendarOps in body 금지**: WeatherCard처럼 반복 렌더되는 View에서 `Calendar.current.component()` 호출은 init에서 pre-compute (Correction #102)
4. **CheckedContinuation 동시성 guard 필수**: `@MainActor`여도 async 함수는 suspension point에서 재진입 가능
5. **@unknown default는 conservative mapping**: 미인식 값을 "안전"으로 분류하면 위험. 중립 또는 약간 부정적으로 매핑
