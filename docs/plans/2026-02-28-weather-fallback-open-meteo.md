---
tags: [weather, api, fallback, open-meteo, weatherkit]
date: 2026-02-28
category: plan
status: draft
---

# Plan: WeatherKit Fallback — Open-Meteo 도입

## Overview

WeatherKit 실패 시 Open-Meteo를 fallback 날씨 소스로 사용하여 날씨 데이터 가용성을 높인다.

## Architecture

```
WeatherFetching protocol
    ├── WeatherDataService (primary: WeatherKit)
    └── OpenMeteoService (fallback: Open-Meteo REST API)  ← NEW
         ↓
WeatherProvider (tries primary → fallback)  ← MODIFY
    ↓
DashboardViewModel (unchanged)
```

## Affected Files

| 파일 | 변경 | 설명 |
|------|------|------|
| `DUNE/Data/Weather/OpenMeteoService.swift` | NEW | Open-Meteo REST API 호출 + WeatherSnapshot 변환 |
| `DUNE/Data/Weather/WeatherDataService.swift` | MODIFY | WeatherProvider에 fallback 서비스 주입 |
| `DUNE/Presentation/Settings/SettingsView.swift` | MODIFY | About 섹션에 Open-Meteo 크레딧 추가 |
| `DUNETests/OpenMeteoServiceTests.swift` | NEW | WMO 매핑, JSON 파싱, 에러 처리 테스트 |

## Implementation Steps

### Step 1: OpenMeteoService 생성

**파일**: `DUNE/Data/Weather/OpenMeteoService.swift`

Open-Meteo REST API를 호출하여 `WeatherSnapshot`을 반환하는 서비스.

**API Endpoint**:
```
GET https://api.open-meteo.com/v1/forecast?
  latitude={lat}&longitude={lon}&
  current=temperature_2m,apparent_temperature,relative_humidity_2m,
          weather_code,wind_speed_10m,uv_index,is_day&
  hourly=temperature_2m,weather_code,is_day&
  forecast_hours=6&
  timezone=auto
```

**구현 내용**:
- `WeatherFetching` 프로토콜 준수
- Codable response models (private, 파일 내부)
- WMO weather code → `WeatherConditionType` 매핑
- 값 범위 검증 (기존 `WeatherDataService`와 동일 clamp 로직)
- 15분 캐시 (기존과 동일 패턴: NSLock + cached property)
- URLSession으로 직접 호출 (추가 의존성 없음)

**WMO Code 매핑**:
| WMO Code | → WeatherConditionType |
|----------|----------------------|
| 0-1 | `.clear` |
| 2 | `.partlyCloudy` |
| 3 | `.cloudy` |
| 45, 48 | `.fog` |
| 51-55 | `.rain` |
| 56-57, 66-67 | `.sleet` |
| 61, 63, 80-81 | `.rain` |
| 65, 82 | `.heavyRain` |
| 71-77, 85-86 | `.snow` |
| 95, 96, 99 | `.thunderstorm` |
| unknown | `.cloudy` |

### Step 2: WeatherProvider fallback 로직

**파일**: `DUNE/Data/Weather/WeatherDataService.swift`

WeatherProvider에 fallback 서비스 추가:

```swift
final class WeatherProvider: WeatherProviding, Sendable {
    private let locationService: LocationService
    private let weatherService: WeatherFetching
    private let fallbackService: WeatherFetching?  // NEW

    init(
        locationService: LocationService,
        weatherService: WeatherFetching = WeatherDataService(),
        fallbackService: WeatherFetching? = OpenMeteoService()  // NEW
    ) { ... }

    func fetchCurrentWeather() async throws -> WeatherSnapshot {
        // ... location auth (unchanged) ...
        let location = try await locationService.requestLocation()
        do {
            return try await weatherService.fetchWeather(for: location)
        } catch {
            guard let fallbackService else { throw error }
            AppLogger.data.info("[Weather] Primary failed, trying fallback: \(error.localizedDescription)")
            return try await fallbackService.fetchWeather(for: location)
        }
    }
}
```

### Step 3: 설정 화면 크레딧

**파일**: `DUNE/Presentation/Settings/SettingsView.swift`

About 섹션에 크레딧 추가:

```swift
private var aboutSection: some View {
    Section("About") {
        // ... 기존 Version, Build ...

        // NEW: Open-Meteo 크레딧
        HStack {
            Text("Weather Data")
            Spacer()
            Text("Apple WeatherKit, Open-Meteo.com")
                .foregroundStyle(DS.Color.textSecondary)
                .font(.caption)
        }
    }
}
```

### Step 4: 유닛 테스트

**파일**: `DUNETests/OpenMeteoServiceTests.swift`

테스트 케이스:
1. **WMO 매핑**: 전체 WMO code → WeatherConditionType 매핑 검증
2. **JSON 파싱**: 정상 응답 파싱
3. **값 범위 검증**: 극단값 clamp 확인
4. **에러 처리**: 네트워크 에러, 잘못된 JSON, HTTP 에러 코드

## Validation

- `scripts/build-ios.sh` 빌드 통과
- `xcodebuild test` 테스트 통과
- 기존 `WeatherAtmosphereTests` 통과 확인

## Risks

| 리스크 | 완화 방법 |
|--------|----------|
| Open-Meteo 서비스 중단 | fallback이므로 기존 Placeholder로 graceful degradation |
| WMO 코드 매핑 불완전 | unknown → `.cloudy` (보수적 기본값) |
| 응답 지연 | WeatherKit 실패 후에만 호출되므로 추가 지연 허용 가능 |
