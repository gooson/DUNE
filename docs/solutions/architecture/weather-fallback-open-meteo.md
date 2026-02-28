---
tags: [weather, fallback, open-meteo, weatherkit, api, resilience]
category: architecture
date: 2026-02-28
severity: important
related_files:
  - DUNE/Data/Weather/OpenMeteoService.swift
  - DUNE/Data/Weather/WeatherDataService.swift
  - DUNE/Data/Weather/Double+TemperatureClamping.swift
  - DUNETests/OpenMeteoServiceTests.swift
related_solutions: []
---

# Solution: WeatherKit Fallback with Open-Meteo

## Problem

WeatherKit이 유일한 날씨 데이터 소스로, 서비스 장애/인증 실패/rate limit 시 날씨 데이터가 완전히 불가용해짐.

### Symptoms

- WeatherKit 서버 장애 시 날씨 카드에 placeholder만 표시
- Apple Developer 계정 이슈 시 날씨 기능 전체 사용 불가
- 사용자에게 에러 상태가 지속적으로 노출

### Root Cause

Single point of failure — 날씨 데이터 소스가 WeatherKit 하나뿐.

## Solution

Open-Meteo REST API를 fallback 서비스로 추가하여 WeatherKit 실패 시 자동 전환.

### Architecture

```
WeatherProvider.fetchCurrentWeather()
  ├── try WeatherDataService (primary: WeatherKit)
  │     └── catch → fallback
  └── try OpenMeteoService (fallback: Open-Meteo REST API)
        └── catch → throw (caller handles placeholder)
```

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `OpenMeteoService.swift` | NEW | Open-Meteo REST API 클라이언트 |
| `Double+TemperatureClamping.swift` | NEW | 공유 온도 clamp 확장 |
| `WeatherDataService.swift` | MODIFY | WeatherProvider에 fallback 주입 |
| `SettingsView.swift` | MODIFY | About에 Open-Meteo 크레딧 |
| `OpenMeteoServiceTests.swift` | NEW | 18개 유닛 테스트 |

### Key Code

**Fallback pattern in WeatherProvider:**
```swift
func fetchCurrentWeather() async throws -> WeatherSnapshot {
    let location = try await locationService.requestLocation()
    do {
        return try await weatherService.fetchWeather(for: location)
    } catch {
        guard let fallbackService else { throw error }
        AppLogger.data.info("[Weather] Primary failed, trying fallback")
        return try await fallbackService.fetchWeather(for: location)
    }
}
```

**WMO Code mapping (Open-Meteo → WeatherConditionType):**
```swift
static func mapWMOCode(_ code: Int) -> WeatherConditionType {
    switch code {
    case 0, 1: return .clear
    case 2: return .partlyCloudy
    case 3: return .cloudy
    // ... (full mapping in source)
    default: return .cloudy  // conservative fallback
    }
}
```

**Shared temperature clamping:**
```swift
extension Double {
    func clampedToPhysicalTemperature() -> Double {
        guard isFinite else { return 20 }
        return Swift.max(-50, Swift.min(60, self))
    }
}
```

### Key Decisions

1. **Open-Meteo 선택 이유**: 무료, API 키 불필요, ECMWF/GFS/ICON 모델 (높은 정확도), CC BY 4.0
2. **fallback-only**: primary 대체가 아닌 WeatherKit 실패 시에만 사용
3. **동일 캐시 패턴**: NSLock + 15분 캐시 (기존 WeatherDataService와 동일)
4. **WMO unknown → .cloudy**: 보수적 기본값 (가장 중립적인 날씨 표현)
5. **DI를 통한 테스트 가능성**: `session: URLSession` 파라미터로 mock 주입 가능

## Prevention

### Checklist Addition

- [ ] 새 외부 API 도입 시 fallback 전략 수립 (단일 소스 의존 금지)
- [ ] 날씨 데이터 값 범위 검증은 `clampedToPhysicalTemperature()` 등 공유 확장 사용
- [ ] Open-Meteo 응답 형식 변경 시 `OpenMeteoResponse` Codable 모델 업데이트

### Rule Addition (if applicable)

외부 API fallback 패턴이 반복되면 `.claude/rules/`에 외부 서비스 resilience 규칙 추가 고려.

## Lessons Learned

1. **DRY 검증은 리뷰에서 잡힌다**: `clampTemperature` 중복이 리뷰 Phase에서 발견되어 공유 확장으로 추출됨
2. **Swift 6 Sendable**: `ISO8601DateFormatter`/`DateFormatter`는 NSObject 기반으로 Sendable 아님. `nonisolated(unsafe)` 또는 `DateFormatter`는 Swift 6에서 자동 Sendable 처리됨
3. **WeatherKit API 타입 확인 필수**: `UVIndex.value`가 이미 `Int`라서 `.rounded()` 불필요. API 리턴 타입을 반드시 확인
4. **CC BY 4.0 귀속 요구**: Open-Meteo 사용 시 설정 화면 About 섹션에 크레딧 필수
