---
tags: [weather, outdoor-fitness, detail-view, open-meteo, scoring, swiftui]
category: architecture
date: 2026-03-01
severity: important
related_files:
  - DUNE/Domain/Models/WeatherSnapshot.swift
  - DUNE/Domain/Models/OutdoorFitnessLevel.swift
  - DUNE/Data/Weather/OpenMeteoService.swift
  - DUNE/Presentation/Dashboard/WeatherDetailView.swift
  - DUNE/Presentation/Dashboard/Components/WeatherCard.swift
  - DUNE/Presentation/Shared/Extensions/AppTheme+View.swift
related_solutions: []
---

# Solution: Weather Detail Page with Outdoor Fitness Scoring

## Problem

Dashboard 날씨 영역이 단순 현재 날씨만 표시하여 정보 가치가 낮았고, 야외 운동 적합도 판단을 사용자에게 전적으로 맡겨야 했음.

### Symptoms

- 날씨 카드에 6시간 예보가 밀집되어 가독성 저하
- 야외 운동 가능 여부를 사용자가 직접 판단해야 함
- 시간별/일별 예보가 없어 운동 계획 수립 불가
- 날씨 숫자(온도 등)에 테마 색상 미적용

### Root Cause

초기 구현 시 현재 날씨만 표시하는 최소 기능으로 설계됨. Open-Meteo API가 hourly/daily forecast를 지원하지만 활용하지 않았음.

## Solution

3계층(Domain → Data → Presentation) 확장으로 날씨 상세 페이지와 야외 운동 적합도 시스템 구축.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| WeatherSnapshot.swift | DailyForecast struct, expanded HourlyWeather, outdoor score algorithm | Domain 모델 확장 |
| OutdoorFitnessLevel.swift | 새 파일: 점수 기반 레벨 분류 enum | Correction #149 (4파일+ 참조 enum 분리) |
| OpenMeteoService.swift | hourly 확장 + daily forecast 파싱, bounds guard | API 확장 + 안전성 |
| WeatherCard.swift | 정보 밀도 축소, 적합도 뱃지 추가, 탭 지원 | UX 개선 |
| WeatherDetailView.swift | 새 파일: hero + score + grid + hourly + daily + best time | 상세 정보 제공 |
| AppTheme+View.swift | outdoorFitnessColor(for:) 추가 | 테마 통합 |

### Key Code

**Outdoor Fitness Score Algorithm** (0-100 감점 방식):

```swift
static func calculateOutdoorScore(
    feelsLike: Double, uvIndex: Int, humidity: Double,
    windSpeed: Double, condition: WeatherConditionType
) -> Int {
    var score = 100
    // Temperature: ideal 15-25°C, 3pts/°C penalty
    // UV: 6-7 → -5, 8-10 → -15, 11+ → -25
    // Humidity: outside 30-60%, 3pts/5% penalty
    // Wind: 20-40 → -10, 40+ → -25
    // Condition: thunderstorm -60, heavyRain -50, snow/sleet -40, rain -30
    return max(0, min(100, score))
}
```

**Performance Pattern** — WeatherDetailView init에서 pre-compute:

```swift
// Pre-compute in init to avoid O(N²) or expensive recomputation in body
private let dailyTempMin: Double
private let dailyTempMax: Double
private let bestHourData: BestHourInfo?

init(snapshot: WeatherSnapshot) {
    self.dailyTempMin = snapshot.dailyForecast.map(\.temperatureMin).min() ?? 0
    self.dailyTempMax = snapshot.dailyForecast.map(\.temperatureMax).max() ?? 0
    if let best = snapshot.bestOutdoorHour {
        let score = WeatherSnapshot.calculateOutdoorScore(for: best)
        self.bestHourData = BestHourInfo(hour: best, score: score, level: ...)
    }
}
```

**Array Bounds Guard** (API 응답 불일치 방어):

```swift
hourlyItems = (0..<min(24, count)).compactMap { i in
    guard i < hourly.temperature_2m.count,
          i < hourly.weather_code.count else { return nil }
    // ...
}
```

### API Integration

Open-Meteo single-call로 3가지 데이터 동시 수신:
- `current`: 현재 날씨 (기존)
- `hourly`: 24시간 예보 (신규, `forecast_hours=24`)
- `daily`: 7일 예보 (신규, `forecast_days=7`)

일별 날짜는 `TimeZone.current`로 파싱하여 "Today"/"Tomorrow" 레이블 정확도 보장.

## Prevention

### Checklist Addition

- [ ] API 응답 배열 확장 시 mandatory field 접근에 bounds guard 추가
- [ ] Detail View에서 computed property가 O(N) 이상이면 init에서 pre-compute
- [ ] 날짜 파싱 시 timezone을 용도에 맞게 설정 (UTC vs local)

### Rule Addition

기존 rules로 충분히 커버됨:
- `performance-patterns.md`: body 내 금지 패턴, computed property 캐싱
- `input-validation.md`: 수학 함수 방어 (isFinite guard)
- `swiftui-patterns.md`: Calendar 연산 → init에서 사전 계산

## Lessons Learned

1. **감점 방식 스코어링**이 가중치 방식보다 디버깅과 설명이 용이 — 각 요인의 감점 폭을 독립적으로 테스트 가능
2. **API 응답의 mandatory vs optional array**를 명확히 구분하여 bounds guard 필요 여부 판단
3. **일별 날짜 파싱 timezone**: UTC 파싱 시 극단적 timezone에서 "Today" 판정 오류 발생 가능
4. **Pre-compute 패턴**: SwiftUI body에서 O(N) 이상 연산은 init으로 이동 + 결과를 let으로 저장
