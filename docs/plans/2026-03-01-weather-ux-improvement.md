---
tags: [weather, ux, dashboard, outdoor-exercise, theme, detail-page]
date: 2026-03-01
category: plan
status: draft
---

# Plan: Today 날씨 영역 UX 개선

## Overview

Dashboard의 날씨 카드를 리디자인하고, 날씨 상세페이지를 추가하며, 야외운동 적합도 시스템을 구축한다.

## Implementation Steps

### Step 1: Domain Layer — WeatherSnapshot 확장

**파일**: `DUNE/Domain/Models/WeatherSnapshot.swift`

1. `DailyForecast` 중첩 struct 추가:
   - `date: Date`, `temperatureMax: Double`, `temperatureMin: Double`
   - `condition: WeatherConditionType`, `precipitationProbability: Int`, `uvIndexMax: Int`

2. `HourlyWeather`에 필드 추가:
   - `feelsLike: Double`, `humidity: Double`, `uvIndex: Int`, `windSpeed: Double`
   - `precipitationProbability: Int`

3. `dailyForecast: [DailyForecast]` 프로퍼티 추가

4. `outdoorFitnessScore: Int` computed property 추가 (0-100):
   - 기본 100점에서 감점 방식
   - 온도(체감) 15-25°C 이상적, 범위 밖 1°C당 -3
   - UV 6-7: -5, 8-10: -15, 11+: -25
   - 습도 30-60% 이상적, 범위 밖 5%당 -3
   - 풍속 20-40: -10, 40+: -25
   - 강수 조건별: rain -30, heavyRain -50, thunderstorm -60, snow/sleet -40

5. `OutdoorFitnessLevel` enum 추가:
   - `.great` (80-100), `.okay` (60-79), `.caution` (40-59), `.indoor` (0-39)
   - `var displayName: String`, `var systemImage: String`

6. `bestOutdoorHour` computed property: hourlyForecast 중 적합도 최고 시간대 반환

### Step 2: Data Layer — OpenMeteoService 확장

**파일**: `DUNE/Data/Weather/OpenMeteoService.swift`

1. API URL 변경:
   - `forecast_hours=6` → `forecast_hours=24`
   - `hourly` 필드 추가: `apparent_temperature,relative_humidity_2m,uv_index,wind_speed_10m,precipitation_probability`
   - `daily` 파라미터 추가: `weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,uv_index_max`
   - `forecast_days=7` 추가

2. `OpenMeteoResponse`에 `DailyData` struct 추가:
   - `time: [String]`, `weather_code: [Int]`, `temperature_2m_max: [Double]`, `temperature_2m_min: [Double]`
   - `precipitation_probability_max: [Int]`, `uv_index_max: [Double]`

3. `HourlyData` 필드 확장:
   - `apparent_temperature: [Double]`, `relative_humidity_2m: [Double]`
   - `uv_index: [Double]`, `wind_speed_10m: [Double]`, `precipitation_probability: [Int]`

4. `mapToSnapshot` 확장:
   - hourly prefix 6 → 24
   - HourlyWeather 매핑에 새 필드 포함
   - daily 데이터 파싱 + DailyForecast 매핑

5. 날짜 전용 파서 추가 (`DateParsing`):
   - `"yyyy-MM-dd"` 포맷 (daily time은 날짜만)

### Step 3: WeatherCard 리디자인

**파일**: `DUNE/Presentation/Dashboard/Components/WeatherCard.swift`

1. 기존 레이아웃 → 간결한 레이아웃:
   ```
   [아이콘]  23°C  맑음     🏃 야외운동 좋아요  [>]
             체감 19°
   ```
   - 큰 아이콘 + 온도 + condition label
   - 체감온도 (3°C+ 차이 시)
   - 야외운동 적합도 뱃지 (OutdoorFitnessLevel 기반)
   - chevron.right 아이콘 (탭 가능 힌트)

2. 6시간 예보 섹션 제거 (상세페이지로 이동)

3. 모든 색상을 theme-aware로:
   - 온도: primary text
   - condition label: `theme.sandColor` (secondary)
   - 적합도 뱃지: level별 색상 (theme의 score 색상 활용)
   - 아이콘: `snapshot.condition.iconColor(for: theme)` (이미 존재)

### Step 4: Dashboard 네비게이션 연결

**파일**: `DUNE/Presentation/Dashboard/DashboardView.swift`

1. WeatherCard를 `NavigationLink(value:)`로 감싸기:
   - navigation value: `WeatherSnapshot` (이미 Hashable)

2. `.navigationDestination(for: WeatherSnapshot.self)` 추가:
   - `WeatherDetailView(snapshot: snapshot)` 연결

### Step 5: WeatherDetailView 구축

**새 파일**: `DUNE/Presentation/Dashboard/WeatherDetailView.swift`

1. 히어로 섹션:
   - 큰 아이콘 + 온도 + condition
   - 체감온도, 습도, UV, 풍속 그리드 (2x2 StandardCard)
   - 야외운동 적합도 점수 + level + 이유 요약

2. 시간별 예보 (24시간):
   - 가로 ScrollView
   - 각 셀: 시간, 아이콘, 온도
   - 현재 시간 하이라이트

3. 주간 예보 (7일):
   - 일별 행: 요일, 아이콘, 최저~최고 온도 바
   - 강수 확률 표시

4. 운동 추천 시간대:
   - bestOutdoorHour 표시
   - 간단한 추천 메시지

5. 배경: `DetailWaveBackground()` (기존 패턴)

### Step 6: 테마 색상 통합

**파일**: `DUNE/Presentation/Shared/Extensions/WeatherConditionType+View.swift`

1. `iconColor` 비테마 accessor 제거하고 View에서 theme 전달 패턴으로 통일
   - WeatherCard에서 `snapshot.condition.iconColor(for: theme)` 사용

**파일**: `DUNE/Presentation/Shared/Extensions/AppTheme+View.swift`

2. 적합도 레벨 색상 매핑 추가 (기존 score 색상 재활용):
   - `.great` → `scoreExcellent`
   - `.okay` → `scoreGood`
   - `.caution` → `scoreTired`
   - `.indoor` → `scoreWarning`

### Step 7: 유닛 테스트

**새 파일**: `DUNETests/OutdoorFitnessScoreTests.swift`

1. 이상적 조건 → 100점
2. 극한 더위 → 낮은 점수
3. 비/눈/뇌우 → 큰 감점
4. 경계값 테스트 (정확히 15°C, 25°C, UV 8 등)
5. bestOutdoorHour 테스트

**기존 파일**: `DUNETests/OpenMeteoServiceTests.swift`

6. daily 파싱 테스트
7. 확장된 hourly 파싱 테스트

### Step 8: Localization

**파일**: `DUNE/Resources/Localizable.xcstrings`

새 문자열 ko/ja 번역 추가:
- "Great for outdoor exercise" / "야외운동하기 좋아요" / "屋外運動に最適"
- "Okay for outdoors" / "야외운동 괜찮아요" / "屋外運動まずまず"
- "Use caution outdoors" / "야외 주의 필요" / "屋外注意"
- "Stay indoors" / "실내 추천" / "室内推奨"
- "Best time" / "베스트 타임" / "ベストタイム"
- "Hourly Forecast" / "시간별 예보" / "時間別予報"
- "7-Day Forecast" / "주간 예보" / "週間予報"
- 기타 상세페이지 라벨

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `Domain/Models/WeatherSnapshot.swift` | 수정 | DailyForecast, HourlyWeather 확장, 적합도 점수 |
| `Data/Weather/OpenMeteoService.swift` | 수정 | 24h hourly + 7day daily API 확장 |
| `Presentation/Dashboard/Components/WeatherCard.swift` | 수정 | 리디자인 (간결화 + 적합도 뱃지) |
| `Presentation/Dashboard/DashboardView.swift` | 수정 | NavigationLink + navigationDestination 추가 |
| `Presentation/Dashboard/WeatherDetailView.swift` | **신규** | 날씨 상세페이지 |
| `Presentation/Shared/Extensions/WeatherConditionType+View.swift` | 수정 | theme 색상 통합 |
| `Presentation/Shared/Extensions/AppTheme+View.swift` | 수정 | 적합도 레벨 색상 |
| `DUNETests/OutdoorFitnessScoreTests.swift` | **신규** | 적합도 점수 테스트 |
| `DUNETests/OpenMeteoServiceTests.swift` | 수정 | daily/hourly 확장 테스트 |
| `DUNE/Resources/Localizable.xcstrings` | 수정 | 번역 추가 |

## Architecture Decisions

1. **적합도 점수 위치**: `WeatherSnapshot` computed property (Domain 레이어)
   - UseCase 분리 불필요: 외부 의존성 없는 순수 계산
   - `HourlyWeather`별 점수도 계산 가능 (시간대별 추천용)

2. **네비게이션 값**: `WeatherSnapshot` 직접 사용
   - 이미 `Hashable` 준수
   - 별도 destination struct 불필요 (ConditionScore 패턴과 동일)

3. **상세페이지 ViewModel 불필요** (MVP):
   - snapshot 데이터만 표시 (추가 fetch 없음)
   - 향후 리프레시 추가 시 ViewModel 도입

4. **WeatherCard에서 `iconColor` 비테마 accessor 유지**:
   - 기존 `iconColor` (non-themed)는 하위 호환성 유지
   - 새 코드는 `iconColor(for: theme)` 사용
