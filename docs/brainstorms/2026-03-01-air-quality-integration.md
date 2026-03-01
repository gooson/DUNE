---
tags: [weather, air-quality, pm2.5, pm10, aqi, outdoor-exercise, open-meteo]
date: 2026-03-01
category: brainstorm
status: draft
---

# Brainstorm: 대기질(미세먼지) 정보 통합

## Problem Statement

야외 운동 시 대기질(미세먼지/초미세먼지)은 호흡기 건강과 운동 효과에 직접 영향을 미친다.
현재 앱은 날씨(온도, UV, 습도, 풍속)만으로 야외 운동 적합성을 판단하지만, 한국 사용자에게
가장 중요한 **PM2.5/PM10 정보가 없다**. 대기질이 나쁜 날 야외 운동은 오히려 건강에 해로우므로,
이 정보를 날씨 시스템에 통합하여 운동 판단 + 컨디션 분석에 활용한다.

## Target Users

- 야외 운동(러닝, 자전거, 등산 등)을 자주 하는 사용자
- 미세먼지에 민감한 사용자 (호흡기 질환, 알레르기)
- 한국/일본 사용자 (미세먼지 관심도 높은 지역)

## Success Criteria

1. 대시보드 WeatherCard에서 현재 대기질 상태를 한눈에 확인 가능
2. 시간별 대기질 예보로 "언제 나가면 좋은지" 판단 가능
3. Outdoor Fitness Score에 대기질이 반영되어 실내/야외 운동 추천 정확도 향상
4. 컨디션 분석 시 대기질 데이터를 보정 요소로 활용 가능

## 기술 분석: Open-Meteo Air Quality API

### API 엔드포인트

```
https://air-quality-api.open-meteo.com/v1/air-quality
?latitude={lat}&longitude={lon}
&current=pm10,pm2_5,us_aqi,european_aqi,ozone,nitrogen_dioxide,sulphur_dioxide,carbon_monoxide
&hourly=pm10,pm2_5,us_aqi
&forecast_days=2
```

### 서울 테스트 응답 (2026-03-01)

| 지표 | 현재값 | 단위 |
|------|--------|------|
| PM2.5 | 11.4 | μg/m³ |
| PM10 | 12.1 | μg/m³ |
| US AQI | 83 | index |
| European AQI | 62 | index |
| Ozone | 40.0 | μg/m³ |
| NO₂ | 45.5 | μg/m³ |
| SO₂ | 23.8 | μg/m³ |
| CO | 377.0 | μg/m³ |

### 장점

- **무료, API 키 불필요** — 기존 weather API와 동일 조건
- **좌표 기반** — 기존 `LocationService` 그대로 재활용
- **시간별 예보** — 24-48시간 PM2.5/PM10/AQI 예보 제공
- **글로벌 커버리지** — 한국/일본/미국/유럽 모두 지원

### 제약

- 별도 API 호출 필요 (weather와 air-quality 엔드포인트 분리)
- 업데이트 빈도: 약 1시간 (weather와 유사)
- 일부 지역 데이터 품질 차이 가능

### 한국 기준 대기질 등급

| 등급 | PM2.5 (μg/m³) | PM10 (μg/m³) | 운동 권고 |
|------|---------------|--------------|-----------|
| 좋음 | 0-15 | 0-30 | 야외 운동 적합 |
| 보통 | 16-35 | 31-80 | 야외 운동 가능, 민감군 주의 |
| 나쁨 | 36-75 | 81-150 | 야외 운동 자제, 실내 권장 |
| 매우나쁨 | 76+ | 151+ | 야외 활동 자제, 실내 운동만 |

## Proposed Architecture

### 1. Data Layer

```
DUNE/Data/Weather/
├── OpenMeteoService.swift          (기존)
├── OpenMeteoAirQualityService.swift (신규: 별도 서비스)
└── WeatherProvider.swift           (수정: air quality 통합)
```

**설계 결정: 별도 서비스 vs 기존 서비스 확장**

별도 `OpenMeteoAirQualityService`를 생성한다:
- 엔드포인트가 다름 (`air-quality-api.open-meteo.com` vs `api.open-meteo.com`)
- 독립 캐싱 가능 (날씨는 stale이지만 대기질은 fresh일 수 있음)
- 실패 시 날씨 데이터는 정상 표시 (partial failure 허용)

### 2. Domain Layer

```swift
// 신규 모델
struct AirQualitySnapshot: Sendable, Hashable {
    let pm2_5: Double          // μg/m³
    let pm10: Double           // μg/m³
    let usAQI: Int             // 0-500
    let europeanAQI: Int       // 0-500+
    let ozone: Double?         // μg/m³
    let nitrogenDioxide: Double? // μg/m³
    let sulphurDioxide: Double?  // μg/m³
    let carbonMonoxide: Double?  // μg/m³
    let fetchedAt: Date

    let hourlyForecast: [HourlyAirQuality]

    struct HourlyAirQuality: Sendable, Hashable, Identifiable {
        var id: Date { hour }
        let hour: Date
        let pm2_5: Double
        let pm10: Double
        let usAQI: Int
    }

    var isStale: Bool { ... }

    // 한국 기준 등급
    var pm25Level: AirQualityLevel { ... }
    var pm10Level: AirQualityLevel { ... }
    // 최종 등급 = 둘 중 나쁜 쪽
    var overallLevel: AirQualityLevel { ... }
}

enum AirQualityLevel: Sendable, Hashable, Comparable {
    case good      // 좋음
    case moderate  // 보통
    case unhealthy // 나쁨
    case veryUnhealthy // 매우나쁨
}
```

### 3. WeatherSnapshot 확장

```swift
// WeatherSnapshot에 optional로 대기질 추가
struct WeatherSnapshot {
    // ... 기존 필드 ...
    let airQuality: AirQualitySnapshot?  // nil = 데이터 미사용/실패

    // HourlyWeather에도 optional 추가
    struct HourlyWeather {
        // ... 기존 필드 ...
        let airQualityLevel: AirQualityLevel?
    }
}
```

### 4. Outdoor Fitness Score 보정

```swift
// calculateOutdoorScore에 airQuality 파라미터 추가
static func calculateOutdoorScore(
    feelsLike: Double,
    uvIndex: Int,
    humidity: Double,
    windSpeed: Double,
    condition: WeatherConditionType,
    airQuality: AirQualityLevel? = nil  // backward compatible
) -> Int {
    var score = 100
    // ... 기존 감점 로직 ...

    // 대기질 감점
    if let aq = airQuality {
        switch aq {
        case .good:           break
        case .moderate:       score -= 10
        case .unhealthy:      score -= 30
        case .veryUnhealthy:  score -= 50
        }
    }

    return max(0, min(100, score))
}
```

### 5. UI 통합

**WeatherCard**: 대기질 배지 추가 (한국 등급 아이콘 + PM2.5 수치 μg/m³)
**WeatherDetailView**:
  - 현재: PM2.5/PM10 μg/m³ + 한국 등급 + US AQI 병기
  - 시간별: PM2.5 차트 (한국 등급 구간 배경색)
  - 세부: Ozone, NO₂ 등 추가 지표 (available이면)
**Dashboard coaching**: "지금 미세먼지가 나쁘니 실내 운동을 추천해요" 메시지

## Constraints

- **API 호출 최소화**: 날씨 + 대기질 = 2개 API 호출, 60분 캐시 유지
- **배터리**: 위치 요청은 기존 `LocationService` 공유 (추가 GPS 요청 없음)
- **Partial failure**: 대기질 API 실패 시 날씨만 표시 (기존 동작 유지)
- **Swift 6 concurrency**: `Sendable` 준수 필수

## Edge Cases

1. **대기질 데이터 없음**: API 실패 or 미지원 지역 → `airQuality: nil`, 기존 score만 사용
2. **극단값**: PM2.5 > 500 → `veryUnhealthy` cap (물리적 상한)
3. **캐시 시간 불일치**: 날씨 fresh + 대기질 stale → 독립 갱신
4. **실내 전용 사용자**: 대기질 정보를 원치 않는 경우 → 설정에서 끄기? (Future)
5. **WeatherKit 미래 전환**: Open-Meteo에서 WeatherKit으로 전환 시 protocol 추상화로 대응

## Scope

### MVP (Must-have)

- [ ] `OpenMeteoAirQualityService` — API 호출 + JSON 파싱 + 캐싱
- [ ] `AirQualitySnapshot` 도메인 모델 (PM2.5, PM10, US AQI, 시간별 예보)
- [ ] `AirQualityLevel` enum (좋음/보통/나쁨/매우나쁨, 한국 기준)
- [ ] `WeatherSnapshot.airQuality` optional 필드 통합
- [ ] `WeatherProvider`에서 날씨+대기질 병렬 fetch (`async let`)
- [ ] `calculateOutdoorScore`에 대기질 감점 반영
- [ ] `isFavorableOutdoor`에 대기질 조건 추가
- [ ] `bestOutdoorHour`에 대기질 반영
- [ ] WeatherCard에 대기질 배지 (등급 아이콘 + PM2.5 수치)
- [ ] WeatherDetailView에 시간별 PM2.5 차트
- [ ] Localization: en/ko/ja 3개 언어 대기질 등급명
- [ ] Unit tests: `AirQualitySnapshot` 등급 계산, score 감점 로직

### Nice-to-have (Future)

- 대기질 push notification (나쁨 이상 시 알림)
- 일별 대기질 예보 차트 (7일)
- 컨디션 분석에서 대기질 보정 (나쁜 날 HRV 하락 허용 범위)
- Ozone, NO₂ 등 세부 지표 표시
- 대기질 히스토리 저장 (SwiftData)
- 대기질 기반 "오늘의 운동 추천" 코칭 카드
- 설정: 대기질 표시 on/off

## Resolved Questions

1. **AQI 기준** (결정됨): PM2.5/PM10 μg/m³ 직접 표시 + 한국 환경부 등급이 primary, US AQI 병기
   - WeatherCard 배지: 한국 등급 (좋음/보통/나쁨/매우나쁨) + PM2.5 수치
   - WeatherDetailView: PM2.5, PM10 μg/m³ + US AQI 숫자 함께 표시
   - 등급 판정 로직은 한국 기준, UI에 AQI 수치도 보여줘서 글로벌 사용자 대응
2. **WeatherSnapshot에 직접 포함 vs 별도 모델**: snapshot이 커지는 trade-off
   → 제안: `WeatherSnapshot.airQuality: AirQualitySnapshot?`으로 optional 포함
3. **API 동시 호출 전략**: 날씨와 대기질을 항상 같이? 아니면 lazy?
   → 제안: `async let` 병렬 호출, 대기질 실패 시 날씨만 반환

## Next Steps

- [ ] `/plan air-quality-integration` 으로 구현 계획 생성
- [ ] 계획서에 Affected Files 테이블 + 구현 순서 포함
