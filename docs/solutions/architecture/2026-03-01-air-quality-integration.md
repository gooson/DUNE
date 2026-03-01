---
tags: [air-quality, weather, open-meteo, korean-standard, pm25, pm10, outdoor-fitness]
category: architecture
date: 2026-03-01
severity: important
related_files:
  - DUNE/Domain/Models/AirQualityLevel.swift
  - DUNE/Domain/Models/AirQualitySnapshot.swift
  - DUNE/Domain/Protocols/AirQualityFetching.swift
  - DUNE/Data/Weather/OpenMeteoAirQualityService.swift
  - DUNE/Data/Weather/WeatherProvider.swift
  - DUNE/Domain/Models/WeatherSnapshot.swift
  - DUNE/Presentation/Shared/Extensions/AirQualityLevel+View.swift
  - DUNE/Presentation/Dashboard/Components/WeatherCard.swift
  - DUNE/Presentation/Dashboard/WeatherDetailView.swift
related_solutions: []
---

# Solution: Air Quality Integration (PM2.5/PM10)

## Problem

운동 시 미세먼지(PM10)/초미세먼지(PM2.5) 정보가 없어 대기질이 나쁜 날에도 실외 운동을 추천하는 문제.

### Symptoms

- 실외 운동 점수가 대기질을 반영하지 않음
- 미세먼지가 매우 나쁜 날에도 `isFavorableOutdoor == true`
- 사용자가 별도 앱에서 대기질을 확인해야 함

### Root Cause

기존 날씨 시스템이 기온/습도/자외선/바람/강수만 고려하고, 대기질 데이터를 수집하지 않았음.

## Solution

Open-Meteo Air Quality API를 활용한 대기질 통합. 한국 환경부 기준 4단계 등급 + US AQI 병기.

### Architecture

```
WeatherProvider
  ├── async let weatherTask = weatherService.fetchWeather()
  └── async let airQualityTask = safeAirQualityFetch()   ← 병렬, 실패 허용
         │
         ▼
  snapshot.withAirQuality(airQuality)   ← 불변 struct copy 패턴
```

- **비파괴적 통합**: 대기질 fetch 실패 시 기존 날씨 데이터만으로 동작 (graceful degradation)
- **Protocol 분리**: `AirQualityFetching` protocol → Domain/Protocols/ (테스트 주입 가능)
- **캐싱**: NSLock 보호 60분 TTL 캐시 (OpenMeteoService 패턴 일관)

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `Domain/Models/AirQualityLevel.swift` | 4단계 enum (한국 환경부) | 등급 분류 |
| `Domain/Models/AirQualitySnapshot.swift` | PM2.5, PM10, AQI, 오염물질, 시간별 | 도메인 모델 |
| `Domain/Protocols/AirQualityFetching.swift` | 프로토콜 (Domain 레이어) | DI + 테스트 |
| `Data/Weather/OpenMeteoAirQualityService.swift` | API fetch + 캐시 + 값 clamping | 데이터 계층 |
| `Data/Weather/WeatherProvider.swift` | 병렬 fetch + graceful failure | 통합 계층 |
| `Domain/Models/WeatherSnapshot.swift` | AQ 반영: 점수, isFavorable, bestHour | 점수 계산 |
| `Presentation/*/WeatherCard.swift` | AQ 뱃지 (PM₂.₅ 수치 + 아이콘) | 대시보드 |
| `Presentation/*/WeatherDetailView.swift` | AQ 섹션, 시간별 차트, 오염물질 그리드 | 상세 화면 |

### Key Code

```swift
// Korean MoE PM2.5 grade (half-open ranges for fractional safety)
static func fromPM25(_ value: Double) -> AirQualityLevel {
    switch value {
    case ..<16:   .good           // 0-15
    case ..<36:   .moderate       // 16-35
    case ..<76:   .unhealthy      // 36-75
    default:      .veryUnhealthy  // 76+
    }
}

// Outdoor fitness score penalty
switch airQualityLevel {
case .good:          break
case .moderate:      score -= 10
case .unhealthy:     score -= 30
case .veryUnhealthy: score -= 50
}

// Hourly AQ matching (Calendar granularity, not exact Date ==)
aqHourly.first(where: {
    Calendar.current.isDate($0.hour, equalTo: hour.hour, toGranularity: .hour)
})
```

### Review에서 발견된 주요 버그

1. **PM 등급 경계 gap** (`...15` → `16...35`): 15.1~15.9가 `veryUnhealthy`로 분류됨 → `..<16` half-open range로 수정
2. **시간별 AQ 매칭 실패**: 서로 다른 API의 Date 인스턴스를 `==`로 비교 → `Calendar.isDate(toGranularity:)` 사용
3. **비정상 농도값 0 표시**: `clampConcentration`이 NaN/Infinity를 0으로 반환 → nil 반환으로 수정

## Prevention

### Checklist Addition

- [ ] Double 값 범위 분류 시 half-open range (`..<`) 사용하여 gap 방지
- [ ] 서로 다른 API 응답의 Date 비교 시 `Calendar.isDate(toGranularity:)` 사용
- [ ] 선택적 데이터 fetch는 `CancellationError` 별도 처리 + 에러 로깅
- [ ] `displayName` 과 동일한 값을 가진 별도 프로퍼티 생성 금지

### Rule Addition (if applicable)

고려 대상 (아직 rules 승격 전):
- Double range classification에서 half-open range 패턴
- 서로 다른 소스의 시간 매칭 시 Calendar granularity 사용

## Lessons Learned

1. **Swift Double range gap**: `case ...15:` + `case 16...35:` 사이에 15.1~15.9 gap 존재. 정수 기준이라도 Double 입력에는 half-open range 필수.
2. **Date equality across APIs**: 동일 시간을 나타내는 두 Date가 sub-second 차이로 `==` 실패 가능. Calendar granularity 비교가 안전.
3. **Non-fatal fetch 패턴**: `async let` + wrapper 함수로 병렬 실행하되 실패를 nil로 변환. CancellationError는 별도 catch하여 불필요한 로그 방지.
4. **Protocol layer placement**: Data 계층의 service 구현체와 같은 파일에 protocol을 두면 Domain → Data 역방향 의존 발생. Protocol은 항상 Domain에 배치.
