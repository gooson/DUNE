---
tags: [weather, location, geocoding, CLGeocoder, UI]
date: 2026-03-01
category: plan
status: approved
---

# Plan: Weather 표시 영역에 위치(지명) 표시

## Summary

WeatherCard(Dashboard)와 WeatherDetailView에 현재 위치의 지명(구/동 수준)을 표시한다.
CLGeocoder reverse geocoding을 사용하여 좌표 → 지명 변환.

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `Domain/Models/WeatherSnapshot.swift` | 수정 | `locationName: String?` 필드 추가 |
| `Data/Weather/LocationService.swift` | 수정 | `reverseGeocode(_:)` 메서드 추가 |
| `Data/Weather/WeatherProvider.swift` | 수정 | geocoding 호출 → snapshot에 locationName 전달 |
| `Data/Weather/OpenMeteoService.swift` | 수정 | `fetchWeather` 시그니처에 locationName 파라미터 추가 또는 WeatherProvider에서 후처리 |
| `Presentation/Dashboard/Components/WeatherCard.swift` | 수정 | 지명 표시 UI 추가 |
| `Presentation/Dashboard/WeatherDetailView.swift` | 수정 | Hero 섹션에 지명 표시 |
| `DUNETests/OpenMeteoServiceTests.swift` | 수정 | locationName 필드 반영 |
| `DUNE/Resources/Localizable.xcstrings` | 수정 | 새 문자열 키 추가 |

## Implementation Steps

### Step 1: WeatherSnapshot에 locationName 필드 추가

`WeatherSnapshot`에 `locationName: String?` 추가.
- Optional: geocoding 실패 시 nil → UI에서 생략
- Hashable 자동 합성이 새 필드를 포함하므로 별도 작업 불필요

### Step 2: LocationService에 reverse geocoding 추가

```swift
func reverseGeocode(_ location: CLLocation) async -> String? {
    let geocoder = CLGeocoder()
    do {
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let place = placemarks.first else { return nil }
        // 구/동 수준: subLocality + locality
        return Self.formatPlaceName(place)
    } catch {
        return nil
    }
}

private static func formatPlaceName(_ place: CLPlacemark) -> String? {
    let parts = [place.subLocality, place.locality].compactMap { $0 }
    guard !parts.isEmpty else { return nil }
    return parts.joined(separator: ", ")
}
```

CLGeocoder는 자동으로 현재 locale에 맞는 지명 반환.

### Step 3: WeatherProvider에서 geocoding 연동

`fetchCurrentWeather()`에서:
1. `locationService.requestLocation()` → CLLocation
2. 병렬로 `weatherService.fetchWeather(for:)` + `locationService.reverseGeocode(_:)` 실행
3. WeatherSnapshot 생성 시 locationName 포함

**접근 방식**: OpenMeteoService는 변경하지 않음. WeatherProvider에서 snapshot을 받은 후 locationName을 주입하는 방식.
→ `WeatherSnapshot`에 `with(locationName:)` copy 메서드 추가.

### Step 4: WeatherCard UI 수정

condition label 옆에 location pin + 지명 표시:
```
☀️  23°C  Feels 26°        🏃 Good  >
    Clear
📍 Gangnam-gu, Seoul     (coaching insight...)
```

`snapshot.locationName`이 nil이면 해당 줄 생략.

### Step 5: WeatherDetailView UI 수정

Hero 섹션의 condition label 아래에 지명 표시:
```
☀️  23°C
    Clear
    📍 Gangnam-gu, Seoul
```

### Step 6: 테스트 업데이트

- OpenMeteoServiceTests: WeatherSnapshot init에 locationName 파라미터 반영
- 새 테스트: LocationService.formatPlaceName 로직 (static이라 테스트 가능)

### Step 7: Localization

`Localizable.xcstrings`에 새 문자열 키 추가 (필요시).
지명 자체는 CLGeocoder가 locale-aware로 반환하므로 별도 번역 불필요.

## Design Decisions

1. **OpenMeteoService 변경 최소화**: WeatherProvider에서 후처리하여 Data 레이어 영향 최소화
2. **Optional locationName**: geocoding은 네트워크 의존 → 실패 시 graceful fallback
3. **병렬 실행**: weather fetch와 geocoding을 `async let`으로 병렬 → 추가 latency 없음
4. **캐싱**: LocationService의 기존 location 캐싱(60분)에 의존. geocoding 결과도 location이 같으면 재사용

## Risks

- CLGeocoder rate limit: Apple 권고를 따라 날씨 fetch 시 1회만 호출 (기존 60분 캐싱과 동일 주기)
- 네트워크 없을 때 geocoding 실패: nil fallback으로 처리
