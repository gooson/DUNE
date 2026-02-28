---
tags: [weather, api, fallback, open-meteo, weatherkit]
date: 2026-02-28
category: brainstorm
status: draft
---

# Brainstorm: WeatherKit Fallback — Open-Meteo 도입

## Problem Statement

현재 앱은 Apple WeatherKit만 사용하여 날씨 데이터를 가져온다. WeatherKit 실패 시(서버 장애, 네트워크 이슈, rate limit) 날씨 정보가 완전히 누락되어 WeatherCard가 placeholder로 대체되고, CoachingEngine의 날씨 기반 인사이트가 비활성화된다.

**핵심 문제**: 단일 날씨 소스 의존으로 인한 데이터 가용성 리스크

## Target Users

- DUNE 앱 사용자 전원
- 특히 날씨 기반 운동 추천(실외 운동 적합성, 자외선 경고 등)에 의존하는 사용자

## Success Criteria

1. WeatherKit 실패 시 Open-Meteo로 자동 fallback하여 날씨 데이터 표시
2. fallback 데이터가 WeatherKit과 동일한 데이터 포인트 커버 (기온, 체감온도, 습도, UV, 풍속, 날씨 상태, 6시간 시간별 예보)
3. 기존 하위 레이어(ViewModel, View, CoachingEngine) 변경 없음
4. 사용자가 fallback 여부를 의식하지 않을 정도의 매끄러운 전환

## API 후보 조사 결과

### 최종 비교표

| | **WeatherKit** (현재) | **Open-Meteo** ★ | **OpenWeatherMap** | **Tomorrow.io** | **7Timer** |
|---|---|---|---|---|---|
| 무료 호출량 | 500K/월 | 10K/일 (≈300K/월) | 1K/일 (≈30K/월) | 500/일 | 무제한 |
| API Key | 불필요 (native) | **불필요** | 필요 | 필요 | 불필요 |
| 정확도 | ★★★★★ | ★★★★~★★★★★ | ★★★~★★★★ | ★★★★ | ★★ |
| 데이터 소스 | Apple (KMA 포함) | ECMWF+GFS+ICON | 자체 모델+관측소 | AI 기반 | GFS만 |
| UV/체감온도/시간예보 | 전부 지원 | 전부 지원 | 전부 지원 | 전부 지원 | 미지원 |
| 응답 속도 | 최고 (OS 내장) | ~100ms | ~200ms | ~200ms | ~500ms |
| 한국 정확도 | 최상 (KMA 직접) | 우수 (ECMWF 9km) | 보통 | 보통 | 낮음 |
| 라이선스 | Apple Dev Program | CC BY 4.0 출처표기 | 무료 계약 | 무료 계약 | 공개 |
| 추가 의존성 | 없음 | 없음 (REST) | 없음 | 없음 | 없음 |

### Open-Meteo 선정 근거

1. **API Key 불필요**: 앱 바이너리에 시크릿 노출 없음 (보안)
2. **높은 정확도**: ECMWF (세계 최고 정확도 모델) + GFS + ICON 다중 모델 활용
3. **넉넉한 무료 티어**: 10,000/일, 5,000/시간, 600/분
4. **완전한 데이터 커버리지**: 앱에서 사용하는 모든 데이터 포인트 제공
5. **추가 의존성 없음**: URLSession + Codable로 직접 호출 (SPM 패키지 불필요)
6. **오픈소스**: 서비스 신뢰성 + 커뮤니티 검증

### Open-Meteo 제약사항

- **라이선스**: 상업 사용 시 CC BY 4.0 출처표기 필수 → 설정 화면 크레딧에 표기
- **한국 특화 모델 부재**: KMA 직접 데이터 없음 (ECMWF 9km 해상도로 대체)
- **서비스 SLA 없음**: 무료 tier에 uptime 보장 없음 (하지만 fallback이므로 OK)

## Proposed Approach

### 아키텍처

```
WeatherFetching protocol
    ├── WeatherKitDataService (primary)
    └── OpenMeteoDataService (fallback)  ← NEW
         ↓
WeatherProvider (tries primary → fallback)
    ↓
DashboardViewModel (unchanged)
    ├→ WeatherCard (unchanged)
    ├→ CoachingEngine (unchanged)
    └→ TabWaveBackground (unchanged)
```

### 핵심 변경 파일

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Data/Weather/OpenMeteoDataService.swift` | **NEW** — Open-Meteo REST API 호출 + WeatherSnapshot 변환 |
| `DUNE/Data/Weather/OpenMeteoModels.swift` | **NEW** — Codable response models + WMO code → WeatherConditionType 매핑 |
| `DUNE/Data/Weather/WeatherProvider.swift` | **MODIFY** — fallback 로직 추가 (try primary catch → try fallback) |
| Settings View | **MODIFY** — 크레딧에 "Weather fallback: Open-Meteo.com (CC BY 4.0)" 추가 |

### Open-Meteo API 호출 예시

```
GET https://api.open-meteo.com/v1/forecast?
  latitude=37.5665&longitude=126.978&
  current=temperature_2m,apparent_temperature,relative_humidity_2m,
          weather_code,wind_speed_10m,uv_index,is_day&
  hourly=temperature_2m,weather_code,is_day&
  forecast_hours=6&
  timezone=auto
```

### WMO Weather Code → WeatherConditionType 매핑

| WMO Code | 설명 | → WeatherConditionType |
|----------|------|----------------------|
| 0 | Clear sky | `.clear` |
| 1 | Mainly clear | `.clear` |
| 2 | Partly cloudy | `.partlyCloudy` |
| 3 | Overcast | `.cloudy` |
| 45, 48 | Fog, depositing rime fog | `.fog` |
| 51-55 | Drizzle (light/moderate/dense) | `.rain` |
| 56-57 | Freezing drizzle | `.sleet` |
| 61, 63 | Rain (slight/moderate) | `.rain` |
| 65 | Heavy rain | `.heavyRain` |
| 66-67 | Freezing rain | `.sleet` |
| 71-77 | Snow (light/moderate/heavy), snow grains | `.snow` |
| 80-81 | Rain showers (slight/moderate) | `.rain` |
| 82 | Violent rain showers | `.heavyRain` |
| 85-86 | Snow showers | `.snow` |
| 95 | Thunderstorm | `.thunderstorm` |
| 96, 99 | Thunderstorm with hail | `.thunderstorm` |

### Fallback 흐름

```swift
func fetchWeather() async throws -> WeatherSnapshot {
    do {
        return try await weatherKitService.fetchCurrentWeather(for: location)
    } catch {
        logger.info("[Weather] WeatherKit failed: \(error), trying Open-Meteo")
        return try await openMeteoService.fetchCurrentWeather(for: location)
    }
}
```

## Constraints

- **기술적**: 추가 SPM 의존성 없이 URLSession + Codable로 구현
- **라이선스**: CC BY 4.0 → 설정 화면 크레딧에 출처 표기
- **성능**: Open-Meteo 호출은 WeatherKit 실패 후에만 발생 (추가 지연 최소화)
- **데이터 일관성**: Open-Meteo 데이터도 기존과 동일한 범위 검증 (clamp) 적용

## Edge Cases

| 시나리오 | 처리 |
|----------|------|
| WeatherKit + Open-Meteo 둘 다 실패 | 기존 WeatherCardPlaceholder 표시 |
| Open-Meteo rate limit 도달 | HTTP 429 → error throw → Placeholder |
| 위치 권한 거부 | fallback 이전에 실패 → 기존 처리 유지 |
| Open-Meteo 응답에 일부 필드 누락 | nil-coalescing으로 개별 필드 fallback |
| WMO code에 없는 값 | `default: .cloudy` (가장 안전한 기본값) |
| 네트워크 완전 오프라인 | 15분 캐시 데이터 사용 → 만료 후 Placeholder |

## Scope

### MVP (Must-have)
- `OpenMeteoDataService` 구현 (current + 6시간 hourly forecast)
- `WeatherProvider` fallback 로직
- WMO weather code → `WeatherConditionType` 매핑
- 기존 동일 수준의 값 범위 검증 (clamp)
- 설정 화면 크레딧 표기
- 유닛 테스트: WMO 매핑, JSON 파싱, fallback 흐름

### Nice-to-have (Future)
- fallback 사용 빈도 로깅 (WeatherKit 안정성 모니터링)
- Open-Meteo 자체 15분 캐시 (WeatherKit과 독립)
- 사용자에게 fallback 소스 표시 (날씨 카드에 작은 아이콘)
- Open-Meteo의 "best_match" 모델 대신 지역별 최적 모델 선택

## Open Questions

- ~~출처 표기 위치~~ → **설정 화면 크레딧** (결정됨)
- ~~fallback 깊이~~ → **Open-Meteo만** (결정됨)
- ~~MVP 범위~~ → **전체 동일 데이터** (결정됨)

## 참고 자료

- [Open-Meteo 공식 사이트](https://open-meteo.com/)
- [Open-Meteo GitHub](https://github.com/open-meteo/open-meteo)
- [Open-Meteo 가격/라이선스](https://open-meteo.com/en/pricing)
- [ECMWF vs GFS 정확도 비교](https://windy.app/blog/ecmwf-vs-gfs-differences-accuracy.html)
- [OpenWeatherMap 가격](https://openweathermap.org/price)
- [WeatherKit 시작하기](https://developer.apple.com/weatherkit/)

## Next Steps

- [ ] `/plan weather-fallback` 로 구현 계획 생성
