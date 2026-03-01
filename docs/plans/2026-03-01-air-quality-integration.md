---
tags: [weather, air-quality, pm2.5, pm10, aqi, open-meteo, outdoor-fitness]
date: 2026-03-01
category: plan
status: approved
---

# Plan: 대기질(미세먼지) 정보 통합

## Overview

Open-Meteo Air Quality API를 활용하여 PM2.5/PM10/AQI 대기질 정보를 기존 날씨 시스템에 통합.
한국 환경부 등급 primary + US AQI 병기. Outdoor Fitness Score에 대기질 감점 반영.

## Affected Files

### 신규 파일

| 파일 | 레이어 | 설명 |
|------|--------|------|
| `DUNE/Data/Weather/OpenMeteoAirQualityService.swift` | Data | Air Quality API 호출 + JSON 파싱 + 캐싱 |
| `DUNE/Domain/Models/AirQualitySnapshot.swift` | Domain | 대기질 도메인 모델 + 등급 계산 |
| `DUNE/Domain/Models/AirQualityLevel.swift` | Domain | 4단계 등급 enum |
| `DUNE/Presentation/Shared/Extensions/AirQualityLevel+View.swift` | Presentation | SF Symbol, 색상, 라벨 매핑 |
| `DUNETests/AirQualitySnapshotTests.swift` | Test | 등급 계산 + 경계값 테스트 |
| `DUNETests/OpenMeteoAirQualityServiceTests.swift` | Test | JSON 파싱 + 매핑 테스트 |
| `DUNETests/OutdoorFitnessScoreAirQualityTests.swift` | Test | 대기질 반영 점수 테스트 |

### 수정 파일

| 파일 | 변경 내용 |
|------|-----------|
| `DUNE/Data/Weather/WeatherProvider.swift` | `AirQualityFetching` 프로토콜 추가, 병렬 fetch |
| `DUNE/Domain/Models/WeatherSnapshot.swift` | `airQuality: AirQualitySnapshot?` 필드 추가, score에 대기질 반영 |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | 대기질 데이터 로드 통합 |
| `DUNE/Presentation/Dashboard/Components/WeatherCard.swift` | 대기질 배지 추가 |
| `DUNE/Presentation/Dashboard/WeatherDetailView.swift` | 대기질 섹션 + 시간별 차트 |
| `DUNE/Resources/Localizable.xcstrings` | en/ko/ja 대기질 관련 문자열 |
| `DUNETests/OutdoorFitnessScoreTests.swift` | 기존 테스트에 airQuality=nil 호환 확인 |

## Implementation Steps

### Step 1: Domain Models (Foundation)

1. `AirQualityLevel.swift` — 4단계 enum (good/moderate/unhealthy/veryUnhealthy)
2. `AirQualitySnapshot.swift` — 도메인 모델 + 등급 계산 로직
   - PM2.5/PM10 한국 기준 등급 판정
   - overallLevel = 둘 중 나쁜 쪽
   - isStale (60분)
   - HourlyAirQuality 배열

### Step 2: Data Service

3. `OpenMeteoAirQualityService.swift` — API 호출 + JSON 파싱
   - 엔드포인트: `air-quality-api.open-meteo.com/v1/air-quality`
   - 필드: pm10, pm2_5, us_aqi, european_aqi, ozone, nitrogen_dioxide, sulphur_dioxide, carbon_monoxide
   - 시간별: pm10, pm2_5, us_aqi (24시간)
   - NSLock 캐싱 (기존 OpenMeteoService 패턴)
   - 값 범위 clamping (PM2.5: 0-1000, PM10: 0-1000, AQI: 0-500)

### Step 3: Provider 통합

4. `WeatherProvider.swift` 수정
   - `AirQualityFetching` 프로토콜 추가
   - `fetchCurrentWeather()` 내에서 `async let` 병렬 호출
   - 대기질 실패 시 날씨만 반환 (partial failure)

### Step 4: WeatherSnapshot 확장

5. `WeatherSnapshot.swift` 수정
   - `airQuality: AirQualitySnapshot?` optional 필드 추가
   - `calculateOutdoorScore`에 `airQuality: AirQualityLevel?` 파라미터 추가 (기본값 nil)
   - `isFavorableOutdoor`에 대기질 조건 추가
   - `bestOutdoorHour` 계산에 시간별 대기질 반영

### Step 5: Presentation — View Extensions

6. `AirQualityLevel+View.swift` — SF Symbol, 색상, displayName

### Step 6: Presentation — UI 통합

7. `WeatherCard.swift` — 대기질 배지 추가
8. `WeatherDetailView.swift` — 대기질 섹션 추가
   - 현재 PM2.5/PM10 수치 + 한국 등급 + US AQI
   - 시간별 PM2.5 차트

### Step 7: Localization

9. `Localizable.xcstrings` — en/ko/ja 대기질 문자열 추가

### Step 8: Tests

10. `AirQualitySnapshotTests.swift` — 등급 계산, 경계값, overallLevel
11. `OpenMeteoAirQualityServiceTests.swift` — JSON 파싱, 매핑
12. `OutdoorFitnessScoreAirQualityTests.swift` — 대기질 감점 로직
13. 기존 `OutdoorFitnessScoreTests.swift` — airQuality=nil 호환 확인

### Step 9: Build + Verify

14. `scripts/build-ios.sh` 빌드 통과 확인
15. 유닛 테스트 통과 확인

## Design Decisions

- **별도 서비스**: 엔드포인트 다름 + partial failure 허용
- **한국 기준 primary + US AQI 병기**: PM2.5/PM10 μg/m³ + 등급 + AQI 숫자
- **backward compatible**: `airQuality: nil`이면 기존 점수 로직 유지
- **대기질 감점**: good=0, moderate=-10, unhealthy=-30, veryUnhealthy=-50
