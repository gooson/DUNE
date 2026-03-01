---
tags: [weather, location, reverse-geocoding, CLGeocoder, async-let, caching]
category: architecture
date: 2026-03-01
severity: minor
related_files:
  - DUNE/Domain/Models/WeatherSnapshot.swift
  - DUNE/Data/Weather/LocationService.swift
  - DUNE/Data/Weather/WeatherProvider.swift
  - DUNE/Presentation/Dashboard/Components/WeatherCard.swift
  - DUNE/Presentation/Dashboard/WeatherDetailView.swift
related_solutions: []
---

# Solution: Weather Location Display via Reverse Geocoding

## Problem

날씨 데이터에 위치 정보(지역명)가 없어 사용자가 어떤 지역의 날씨인지 알 수 없었음.

### Symptoms

- WeatherCard에 온도와 기상 조건만 표시
- WeatherDetailView에도 위치 정보 없음
- 위치 기반 데이터임에도 "어디의 날씨인지" 불명확

### Root Cause

LocationService가 CLLocation 좌표만 제공하고 역지오코딩을 수행하지 않았음.
WeatherSnapshot 모델에 locationName 필드가 없었음.

## Solution

CLGeocoder 역지오코딩을 통해 좌표 → 지역명(구/동 수준) 변환 후 날씨 스냅샷에 첨부.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| WeatherSnapshot.swift | `locationName: String?` 필드 + `with(locationName:)` copy method | 도메인 모델에 위치 이름 포함 |
| LocationService.swift | `reverseGeocode()` + `formatPlaceName()` 추가 | 역지오코딩 + 결과 캐싱 |
| WeatherProvider.swift | `async let` 병렬 실행 (weather + geocoding) | 지연 시간 최소화 |
| OpenMeteoService.swift | `locationName: nil` 전달 | 새 필드 호환 |
| WeatherCard.swift | "condition · location" 패턴 표시 | 대시보드 위치 표시 |
| WeatherDetailView.swift | `Label(locationName, systemImage:)` | 상세 화면 위치 표시 |

### Key Code

**역지오코딩 + 캐싱** (LocationService.swift):
```swift
private var geocodeCache: (location: CLLocation, name: String?, cachedAt: Date)?

func reverseGeocode(_ location: CLLocation) async -> String? {
    if let cache = geocodeCache,
       cache.location.distance(from: location) < 1000,
       Date().timeIntervalSince(cache.cachedAt) < 60 * 60 {
        return cache.name
    }
    let geocoder = CLGeocoder()
    do {
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        let name = placemarks.first.flatMap {
            Self.formatPlaceName(subLocality: $0.subLocality, locality: $0.locality)
        }
        geocodeCache = (location: location, name: name, cachedAt: Date())
        return name
    } catch {
        return nil
    }
}

nonisolated static func formatPlaceName(subLocality: String?, locality: String?) -> String? {
    let parts = [subLocality, locality].compactMap { $0 }
    guard !parts.isEmpty else { return nil }
    return parts.joined(separator: ", ")
}
```

**병렬 실행** (WeatherProvider.swift):
```swift
async let weatherTask = weatherService.fetchWeather(for: location)
async let locationNameTask = locationService.reverseGeocode(location)
let snapshot = try await weatherTask
let locationName = await locationNameTask
return snapshot.with(locationName: locationName)
```

**값 타입 copy 패턴** (WeatherSnapshot.swift):
```swift
func with(locationName: String?) -> WeatherSnapshot {
    WeatherSnapshot(
        temperature: temperature, feelsLike: feelsLike, condition: condition,
        humidity: humidity, uvIndex: uvIndex, windSpeed: windSpeed,
        isDaytime: isDaytime, fetchedAt: fetchedAt,
        hourlyForecast: hourlyForecast, dailyForecast: dailyForecast,
        locationName: locationName
    )
}
```

## Prevention

향후 유사 패턴 적용 시 참고 사항:

### Checklist Addition

- [ ] CLGeocoder 사용 시 반드시 캐싱 (Apple rate limit 존재)
- [ ] `@MainActor` 클래스의 순수 함수는 `nonisolated` 마킹 (테스트 용이성)
- [ ] CLPlacemark 직접 의존 금지 → primitive 파라미터로 테스트 가능하게

### Design Decisions

1. **geocoding을 WeatherProvider에서 조율**: OpenMeteoService는 순수 API 클라이언트로 유지
2. **`async let` 병렬 실행**: 날씨 fetch와 역지오코딩이 독립적이므로 동시 실행
3. **`with(locationName:)` copy**: WeatherSnapshot이 value type이므로 post-construction injection
4. **캐시 정책 정렬**: 위치 캐시(60min) = 날씨 캐시(60min) = 역지오코딩 캐시(60min + 1km)

## Lessons Learned

1. **CLPlacemark 테스트 불가**: `CLPlacemark`은 간단한 init이 없어 mock 생성이 어려움. 순수 함수를 primitive 파라미터로 추출하면 테스트 가능
2. **`@MainActor` 전파 주의**: `@MainActor` 클래스의 static func도 isolation을 상속함. 순수 함수는 `nonisolated` 명시 필수
3. **역지오코딩은 locale-aware**: `CLGeocoder`가 디바이스 locale에 맞는 지명을 자동 반환하므로 별도 번역 불필요
