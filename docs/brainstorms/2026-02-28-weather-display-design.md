---
tags: [weather, today-tab, weatherkit, visual, coaching, desert-theme]
date: 2026-02-28
category: brainstorm
status: draft
---

# Brainstorm: Today 탭 날씨 표현 및 활용

## Problem Statement

DUNE 앱의 Today 탭은 건강 지표(HRV, RHR, 수면, 운동)와 컨디션 점수를 보여주지만, **현재 환경 상태(날씨)**를 전혀 반영하지 않는다. 사용자가 오늘의 운동 계획을 세울 때 날씨는 핵심 변수인데, 이를 별도 앱에서 확인해야 한다. 또한 Desert Horizon 테마의 "사막 하늘" 컨셉은 날씨와 자연스럽게 연결되므로, 날씨를 시각적으로 통합하면 앱의 아이덴티티가 강화된다.

## Target Users

- 매일 아침 컨디션과 운동 계획을 함께 확인하는 사용자
- 실외 운동(러닝, 자전거, 하이킹)이 주요 활동인 사용자
- 앱의 비주얼 경험을 중시하는 사용자

## Success Criteria

1. Today 탭을 열었을 때 현재 날씨 상태를 3초 이내 인식 가능
2. 날씨에 따라 배경/웨이브 색상이 자연스럽게 변화하여 "살아있는 앱" 느낌
3. 코칭 메시지가 날씨 컨텍스트를 반영 (예: "오늘 33°C — 실내 운동 추천")
4. WeatherKit 권한 없거나 실패해도 기존 UX가 손상되지 않음 (graceful degradation)

## Proposed Approach

### 1. Weather Card — 환경 정보 카드

Hero 섹션 바로 아래, Coaching 카드 위에 **WeatherCard** 배치. 기존 VitalCard 스타일과 통합되되 full-width (1열) 레이아웃.

```
┌──────────────────────────────────┐
│  ☀️ 27°  Mostly Clear           │
│  Humidity 45%  UV 6 (High)      │
│  "Great weather for outdoor run"│
│  ── Hourly: 🌤26 🌤28 ⛅27 ──  │
└──────────────────────────────────┘
```

**표시 정보 (MVP)**:
- 현재 기온 + 체감 온도
- 날씨 상태 아이콘 + 설명 (WeatherKit `WeatherCondition`)
- 습도, UV 지수
- 향후 6시간 간이 예보 (아이콘 + 온도)
- 날씨 기반 한 줄 코멘트

**상호작용**:
- 탭하면 상세 날씨 뷰 (시간대별, 일주일 예보)
- 길게 누르면 context menu: "View Hourly Forecast", "Open Weather App"

### 2. Atmospheric Background — 날씨 반응형 배경

기존 `TabWaveBackground`를 확장하여 날씨 상태에 따라 **색상 팔레트 + 웨이브 파라미터**를 동적으로 변경.

#### 색상 매핑 (Desert Horizon 확장)

| 날씨 상태 | 웨이브 색상 | 그라디언트 톤 | 컨셉 |
|-----------|-----------|-------------|------|
| Clear (맑음) | `warmGlow` (기본) | desertBronze → warmGlow | 사막의 맑은 하늘 |
| Cloudy (흐림) | `desertDusk` | desertDusk → sandMuted | 모래 위 구름 그림자 |
| Rain (비) | 새 토큰 `oasisRain` | desertDusk → oasisTeal (dimmed) | 사막의 비 — 오아시스 |
| Snow (눈) | 새 토큰 `frostSand` | sandMuted → white (low sat) | 모래 위 서리 |
| Hot (35°C+) | `warmGlow` (intensified) | desertBronze → warmGlow (hot) | 강렬한 사막 태양 |
| Cold (0°C-) | `desertDusk` (cooled) | desertDusk → frost blue | 겨울 사막 새벽 |
| Wind (강풍) | `sandMuted` (fast wave) | sandMuted → desertDusk | 모래바람 |
| Night (일몰 후) | `desertDusk` (dark) | deep indigo → desertDusk | 사막의 밤하늘 |

#### 웨이브 파라미터 변경

| 조건 | amplitude | frequency | phase speed | opacity |
|------|-----------|-----------|-------------|---------|
| 맑음 (기본) | 0.03 | 2 | 6s | 0.04 |
| 비 | 0.05 | 3 | 4s | 0.08 |
| 눈 | 0.02 | 1.5 | 8s | 0.06 |
| 강풍 | 0.06 | 4 | 3s | 0.06 |
| 폭풍 | 0.07 | 5 | 2s | 0.10 |

#### 선택적: Particle Effect (Future)

- 비: 얇은 수직 라인 파티클 (top → bottom)
- 눈: 작은 원형 파티클 (drift)
- 맑음/밤: 미세한 별 반짝임

**성능 고려**: `Canvas` + `TimelineView(.animation)` 사용. `accessibilityReduceMotion` 존중. 파티클 수 최대 30개.

### 3. Weather-Aware Coaching — 날씨 연동 코칭

기존 `CoachingEngine`을 확장하여 날씨 컨텍스트를 코칭 인사이트에 반영.

#### 코칭 시나리오

| 조건 | 코칭 메시지 예시 | 카테고리 |
|------|----------------|---------|
| 기온 35°C+ | "Extreme heat — consider indoor training or early morning session" | recovery |
| 기온 0°C- | "Cold weather increases injury risk — extend warm-up" | activity |
| UV 8+ | "Very high UV — wear sunscreen and stay hydrated" | recovery |
| 비/눈 | "Rain today — perfect day for strength training indoors" | activity |
| 습도 80%+ | "High humidity reduces cooling — lower intensity recommended" | recovery |
| 맑음 + 적당 기온 | "Great weather for an outdoor run — your condition is Good" | activity |
| 미세먼지 나쁨 | "Poor air quality — consider indoor exercise" | recovery |

#### 통합 방법

```
WeatherData → WeatherCoachingRule → CoachingInsight
                                        ↓
                     기존 CoachingEngine에 합류 (priority 기반 정렬)
```

날씨 코칭은 **안전 관련**(폭염, 한파, UV)이 높은 priority, **편의 관련**(비, 습도)이 낮은 priority.

### 4. Data Source Strategy

#### WeatherKit (Primary)

```swift
// Data/Weather/WeatherService.swift
import WeatherKit

final class WeatherDataService {
    private let weatherService = WeatherService.shared

    func fetchCurrentWeather(for location: CLLocation) async throws -> CurrentWeather
    func fetchHourlyForecast(for location: CLLocation) async throws -> [HourWeather]
    func fetchDailyForecast(for location: CLLocation) async throws -> [DayWeather]
}
```

- **위치 권한**: `CLLocationManager.requestWhenInUseAuthorization()`
- **캐싱**: 15분 TTL. 앱 foreground 복귀 시 stale check
- **비용**: Apple Developer 기본 무료 50만 콜/월 (개인 사용 충분)

#### HealthKit Metadata (Secondary)

기존 `WorkoutQueryService.extractWeather()` 활용. 운동 상세 뷰에서 "운동 당시 날씨" 표시 유지.

#### Fallback Strategy

```
WeatherKit available → 실시간 날씨 표시
WeatherKit unavailable → 카드 미표시, 배경 기본값(warmGlow)
Location denied → "Enable Location for weather" 안내 카드
Network error → 캐시된 데이터 표시 + "Updated X ago" 라벨
```

## Constraints

### 기술적 제약
- **iOS 26+ WeatherKit**: 네이티브 지원, 추가 SDK 불필요
- **위치 권한**: `CLLocationManager` — 앱에서 아직 미사용이므로 새로 추가 필요
- **API 호출 제한**: WeatherKit 무료 50만 콜/월 — 15분 캐싱으로 충분
- **배터리**: 위치 업데이트 + WeatherKit 호출 빈도 최소화 (`significantLocationChange` 사용)

### 디자인 제약
- Desert Horizon 테마와의 일관성 유지 (날씨 색상이 사막 팔레트에서 벗어나지 않아야 함)
- 웨이브 배경 변경은 부드러운 transition 필수 (급격한 색상 전환 금지)
- Correction #127: 다크 모드 배경 gradient opacity 최소 0.06
- Correction #128: 반복 UnitPoint/opacity는 DS 토큰으로 추출

### Layer Boundary 제약
- Domain 레이어에 `WeatherKit` import 금지 → Domain 모델은 순수 struct
- ViewModel에 `CLLocation` 직접 전달 금지 → Service에서 해소 후 Domain DTO 전달
- 날씨 색상(Color)은 Presentation extension (`WeatherCondition+View.swift`)

## Edge Cases

### 데이터 없음
- WeatherKit 미지원 지역 → 카드 미표시, 기본 배경
- 위치 권한 거부 → 안내 카드 1회 표시 후 dismiss 가능
- 네트워크 오프라인 → 마지막 캐시 데이터 + stale 표시

### 시간대 경계
- 일출/일몰 기준 Day/Night 전환 → `SunEvents` API 사용
- 시간대 변경(여행) → `significantLocationChange`로 자동 갱신

### 극단값
- 기온 -40°C ~ +60°C 표시 범위 (HealthKit 검증 패턴 적용)
- UV 지수 0~15 범위
- 풍속 0~200 km/h 범위

### 성능
- WeatherKit 호출 실패 시 배경 전환 중단 → 기본값 유지
- 파티클 효과는 `accessibilityReduceMotion` 존중
- 배경 색상 transition은 `.animation(.easeInOut(duration: 1.5))` — 급격한 전환 방지

## Scope

### MVP (Must-have)
- [ ] WeatherKit + CoreLocation 권한 설정 및 서비스 구현
- [ ] `WeatherCard` — 현재 기온, 상태, 습도, UV, 6시간 예보
- [ ] 날씨 반응형 웨이브 배경 (색상 + 파라미터 변경)
- [ ] 날씨 기반 코칭 인사이트 (안전: 폭염/한파/UV)
- [ ] Graceful degradation (권한 없음, 네트워크 오류)
- [ ] 15분 캐싱 + stale 표시

### Nice-to-have (Future)
- [ ] 파티클 효과 (비, 눈, 별)
- [ ] 상세 날씨 뷰 (NavigationLink destination)
- [ ] 일주일 예보 + 운동 추천 일정
- [ ] 미세먼지/대기질 (AQI) 연동
- [ ] Apple Watch 날씨 complication
- [ ] 날씨 데이터 → 컨디션 점수 보정 (기압 변화 → HRV 영향)
- [ ] 위젯에 날씨 표시

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                    App Layer                     │
│  ContentView → DashboardView                     │
│         ↓ .environment(\.weatherAtmosphere)       │
│  TabWaveBackground reads atmosphere              │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────┐
│              Presentation Layer                  │
│                                                  │
│  WeatherCard ← WeatherCardData (DTO)             │
│  WeatherCoachingCard ← CoachingInsight           │
│  WeatherAtmosphere+View.swift (color mapping)    │
│                                                  │
│  DashboardViewModel                              │
│    ├─ weatherCardData: WeatherCardData?           │
│    ├─ weatherAtmosphere: WeatherAtmosphere        │
│    └─ loadWeather() async                         │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────┐
│                Domain Layer                      │
│                                                  │
│  WeatherSnapshot (struct, Sendable)              │
│    ├─ temperature: Double (celsius)              │
│    ├─ feelsLike: Double                          │
│    ├─ condition: WeatherConditionType (enum)      │
│    ├─ humidity: Double (0-1)                     │
│    ├─ uvIndex: Int                               │
│    ├─ windSpeed: Double (km/h)                   │
│    ├─ isDaytime: Bool                            │
│    └─ hourlyForecast: [HourlyWeather]            │
│                                                  │
│  WeatherConditionType (enum)                     │
│    clear, cloudy, rain, snow, wind, storm, fog   │
│                                                  │
│  WeatherAtmosphere (struct)                      │
│    ├─ waveAmplitude, frequency, phaseSpeed       │
│    ├─ condition: WeatherConditionType             │
│    ├─ isDaytime: Bool                            │
│    └─ intensity: Double (0-1)                    │
│                                                  │
│  WeatherCoachingRule                             │
│    ├─ evaluate(weather: WeatherSnapshot)          │
│    └─ → CoachingInsight?                         │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────┐
│                 Data Layer                       │
│                                                  │
│  WeatherDataService                              │
│    ├─ fetchCurrent(for: CLLocation) async throws │
│    ├─ fetchHourly(for: CLLocation) async throws  │
│    └─ cache: WeatherCache (15min TTL)            │
│                                                  │
│  LocationService                                 │
│    ├─ requestPermission()                        │
│    ├─ currentLocation: CLLocation?               │
│    └─ significantLocationChange stream            │
│                                                  │
│  WeatherKit → WeatherSnapshot 매핑               │
│  CLLocationManager → LocationService             │
└─────────────────────────────────────────────────┘
```

## File Plan (예상)

```
DUNE/
├── Domain/Models/
│   ├── WeatherSnapshot.swift          (Domain DTO)
│   ├── WeatherConditionType.swift     (enum)
│   └── WeatherAtmosphere.swift        (배경 파라미터)
├── Domain/Services/
│   └── WeatherCoachingRule.swift       (코칭 규칙)
├── Data/Weather/
│   ├── WeatherDataService.swift       (WeatherKit 래핑)
│   ├── LocationService.swift          (CLLocation 래핑)
│   └── WeatherCache.swift             (15분 TTL 캐시)
├── Presentation/Dashboard/
│   └── Components/
│       └── WeatherCard.swift          (날씨 카드 뷰)
├── Presentation/Shared/Extensions/
│   ├── WeatherConditionType+View.swift (색상, 아이콘)
│   └── WeatherAtmosphere+View.swift    (배경 색상 매핑)
├── Presentation/Shared/DesignSystem.swift
│   └── + DS.Color.weather* 토큰 추가
└── Resources/Assets.xcassets/Colors/
    ├── OasisRain.colorset/            (비 날씨 색상)
    └── FrostSand.colorset/            (눈 날씨 색상)
```

## DS Token Additions (예상)

```swift
// DS.Color
static let oasisRain = Color("OasisRain")     // 사막의 비 — 차가운 청록
static let frostSand = Color("FrostSand")     // 모래 위 서리 — 연한 아이보리

// DS.Gradient
static let weatherClear = LinearGradient(...)   // 맑음: warmGlow 기본
static let weatherCloudy = LinearGradient(...)  // 흐림: desertDusk 기반
static let weatherRain = LinearGradient(...)    // 비: oasisRain 기반
static let weatherSnow = LinearGradient(...)    // 눈: frostSand 기반

// DS.Animation
static let atmosphereTransition: Animation = .easeInOut(duration: 1.5)
```

## Open Questions

1. **위치 권한 타이밍**: 앱 최초 실행 시 요청? 아니면 Today 탭 첫 방문 시 요청?
2. **Watch 연동**: watchOS에서도 날씨 배경을 반영할 것인지?
3. **기온 단위**: 사용자 설정으로 °C/°F 전환? 아니면 시스템 locale 따름?
4. **파티클 효과**: MVP에 포함? 아니면 v2?
5. **대기질(AQI)**: WeatherKit이 일부 지역에서 제공 — MVP에 포함?

## Next Steps

- [ ] `/plan weather-display-design` 으로 구현 계획 생성
- [ ] WeatherKit entitlement 설정 확인
- [ ] 날씨별 Desert Horizon 색상 팔레트 시각 목업 준비
