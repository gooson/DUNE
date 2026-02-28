---
tags: [weather, weatherkit, today-tab, visual, coaching]
date: 2026-02-28
category: plan
status: draft
---

# Plan: Today 탭 날씨 표현 및 활용

## Overview

Today 탭에 WeatherKit 기반 실시간 날씨를 통합한다. 3가지 축: (1) WeatherCard, (2) 날씨 반응형 웨이브 배경, (3) 날씨 기반 코칭.

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `Domain/Models/WeatherSnapshot.swift` | **NEW** | 날씨 Domain DTO |
| `Domain/Models/WeatherConditionType.swift` | **NEW** | 날씨 조건 enum |
| `Domain/Models/WeatherAtmosphere.swift` | **NEW** | 배경 파라미터 struct |
| `Domain/UseCases/CoachingEngine.swift` | **EDIT** | 날씨 트리거 추가 |
| `Domain/Models/CoachingInsight.swift` | **EDIT** | `weather` InsightCategory 추가 |
| `Data/Weather/WeatherDataService.swift` | **NEW** | WeatherKit 래핑 서비스 |
| `Data/Weather/LocationService.swift` | **NEW** | CLLocation 래핑 |
| `Data/Weather/WeatherCache.swift` | **NEW** | 15분 TTL 캐시 |
| `Presentation/Dashboard/DashboardViewModel.swift` | **EDIT** | 날씨 데이터 로드 + atmosphere 계산 |
| `Presentation/Dashboard/DashboardView.swift` | **EDIT** | WeatherCard 배치 + atmosphere 전달 |
| `Presentation/Dashboard/Components/WeatherCard.swift` | **NEW** | 날씨 카드 뷰 |
| `Presentation/Shared/Extensions/WeatherConditionType+View.swift` | **NEW** | 아이콘, 색상 매핑 |
| `Presentation/Shared/Extensions/WeatherAtmosphere+View.swift` | **NEW** | 배경 색상/파라미터 매핑 |
| `Presentation/Shared/Extensions/InsightCategory+View.swift` | **EDIT** | weather 카테고리 색상 |
| `Presentation/Shared/Components/WavePreset.swift` | **EDIT** | WeatherAtmosphere EnvironmentKey 추가 |
| `Presentation/Shared/Components/WaveShape.swift` | **EDIT** | TabWaveBackground가 atmosphere 읽기 |
| `Presentation/Shared/DesignSystem.swift` | **EDIT** | 날씨 색상 토큰 추가 |
| `App/ContentView.swift` | **EDIT** | atmosphere environment 전달 |
| `Resources/Assets.xcassets/Colors/` | **EDIT** | 새 colorset 추가 |
| `DUNE/project.yml` | **EDIT** | WeatherKit + CoreLocation 권한 |
| `Resources/DUNE.entitlements` | **EDIT** | WeatherKit entitlement |
| `DUNETests/WeatherCoachingTests.swift` | **NEW** | 날씨 코칭 테스트 |
| `DUNETests/WeatherAtmosphereTests.swift` | **NEW** | 배경 매핑 테스트 |
| `DUNETests/WeatherCacheTests.swift` | **NEW** | 캐시 TTL 테스트 |

## Implementation Steps

### Step 1: Domain Models (순수 struct, Foundation only)

**1.1 WeatherConditionType.swift**

```swift
import Foundation

enum WeatherConditionType: String, Sendable, Hashable, CaseIterable {
    case clear
    case partlyCloudy
    case cloudy
    case rain
    case heavyRain
    case snow
    case sleet
    case wind
    case fog
    case haze
    case thunderstorm
    case hot       // 체감온도 35°C+
    case freezing  // 체감온도 0°C-
}
```

**1.2 WeatherSnapshot.swift**

```swift
import Foundation

struct WeatherSnapshot: Sendable, Hashable {
    let temperature: Double        // celsius
    let feelsLike: Double          // celsius
    let condition: WeatherConditionType
    let humidity: Double           // 0-1
    let uvIndex: Int               // 0-15
    let windSpeed: Double          // km/h
    let isDaytime: Bool
    let fetchedAt: Date
    let hourlyForecast: [HourlyWeather]

    struct HourlyWeather: Sendable, Hashable, Identifiable {
        let id = UUID()
        let hour: Date
        let temperature: Double
        let condition: WeatherConditionType
    }

    var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 15 * 60 // 15min
    }
}
```

**1.3 WeatherAtmosphere.swift**

```swift
import Foundation

struct WeatherAtmosphere: Sendable, Hashable {
    let condition: WeatherConditionType
    let isDaytime: Bool
    let intensity: Double  // 0-1 (비/눈 강도)

    static let `default` = WeatherAtmosphere(
        condition: .clear, isDaytime: true, intensity: 0
    )
}
```

### Step 2: Data Layer — WeatherKit + Location

**2.1 LocationService.swift**

```swift
import Foundation
import CoreLocation

@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var currentLocation: CLLocation?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    func requestPermission() { manager.requestWhenInUseAuthorization() }
    // significantLocationChange로 배터리 절약
}
```

**2.2 WeatherDataService.swift**

```swift
import Foundation
import WeatherKit
import CoreLocation

protocol WeatherFetching: Sendable {
    func fetchWeather(for location: CLLocation) async throws -> WeatherSnapshot
}

final class WeatherDataService: WeatherFetching {
    private let weatherService = WeatherService.shared
    private let cache = WeatherCache()

    func fetchWeather(for location: CLLocation) async throws -> WeatherSnapshot {
        if let cached = cache.get(), !cached.isStale { return cached }
        let weather = try await weatherService.weather(for: location, including: .current, .hourly)
        let snapshot = mapToSnapshot(current: weather.0, hourly: weather.1)
        cache.set(snapshot)
        return snapshot
    }
}
```

**2.3 WeatherCache.swift**

```swift
import Foundation

final class WeatherCache: @unchecked Sendable {
    private var cached: WeatherSnapshot?
    private let lock = NSLock()

    func get() -> WeatherSnapshot? { lock.withLock { cached } }
    func set(_ snapshot: WeatherSnapshot) { lock.withLock { cached = snapshot } }
    func invalidate() { lock.withLock { cached = nil } }
}
```

### Step 3: Coaching — 날씨 트리거

**3.1 CoachingInput 확장**

```swift
struct CoachingInput: Sendable {
    // ... 기존 필드
    let weather: WeatherSnapshot?  // NEW
}
```

**3.2 InsightCategory 확장**

```swift
enum InsightCategory: String, Sendable, Hashable {
    // ... 기존
    case weather  // NEW
}
```

**3.3 CoachingEngine에 evaluateWeatherTriggers() 추가**

| Priority | 조건 | 메시지 |
|----------|------|--------|
| P2 (high) | 체감 35°C+ | "극심한 더위 — 실내 운동이나 이른 아침 세션 고려" |
| P2 (high) | 체감 0°C- | "한파 주의 — 워밍업을 충분히, 부상 위험 증가" |
| P3 (medium) | UV 8+ | "자외선 매우 높음 — 자외선 차단제와 수분 보충 필수" |
| P4 (standard) | 비/눈 | "오늘 비 예보 — 실내 근력 운동이 좋은 날" |
| P4 (standard) | 습도 80%+ | "높은 습도 — 강도를 낮추고 수분 보충에 집중" |
| P5 (low) | 맑음 + 적당 | "야외 운동하기 좋은 날씨 — 러닝이나 산책 추천" |

### Step 4: Presentation — WeatherCard

**4.1 WeatherCard.swift**

full-width InlineCard 스타일. Hero 아래, Coaching 위에 배치.

표시:
- SF Symbol + 기온 + 체감 (한 줄)
- 상태 설명 + 습도% + UV 지수
- 6시간 예보 (수평 스크롤, 아이콘+온도)

**4.2 WeatherConditionType+View.swift**

```swift
extension WeatherConditionType {
    var sfSymbol: String { ... }   // cloud.sun.fill 등
    var label: String { ... }      // "맑음" 등
    var waveColor: Color { ... }   // DS.Color 매핑
}
```

**4.3 WeatherAtmosphere+View.swift**

```swift
extension WeatherAtmosphere {
    var waveColor: Color { ... }
    var waveAmplitude: CGFloat { ... }
    var waveFrequency: CGFloat { ... }
    var waveOpacity: Double { ... }
    var gradientColors: [Color] { ... }
}
```

### Step 5: 배경 통합 — Wave Atmosphere

**5.1 WavePreset.swift에 EnvironmentKey 추가**

```swift
private struct WeatherAtmosphereKey: EnvironmentKey {
    static let defaultValue: WeatherAtmosphere = .default
}

extension EnvironmentValues {
    var weatherAtmosphere: WeatherAtmosphere { ... }
}
```

**5.2 TabWaveBackground 수정**

`@Environment(\.weatherAtmosphere)` 읽어서 색상/파라미터 오버라이드.
Today 탭에서만 적용 (`wavePreset == .today` 체크).

**5.3 ContentView에서 atmosphere 전달**

DashboardViewModel의 `weatherAtmosphere`를 `.environment(\.weatherAtmosphere, ...)` 로 전달.

### Step 6: Design System 토큰

**6.1 새 Color Assets**

| Name | Light RGB | Dark RGB | Purpose |
|------|-----------|----------|---------|
| WeatherRain | (0.40, 0.65, 0.72) | (0.35, 0.58, 0.68) | 비 — 사막 오아시스 |
| WeatherSnow | (0.75, 0.73, 0.68) | (0.65, 0.63, 0.60) | 눈 — 모래 위 서리 |
| WeatherCloudy | (0.52, 0.55, 0.60) | (0.42, 0.48, 0.56) | 흐림 — desertDusk 계열 |
| WeatherNight | (0.25, 0.27, 0.38) | (0.18, 0.20, 0.30) | 밤 — 사막 밤하늘 |

**6.2 DS.Color에 추가**

```swift
static let weatherRain   = SwiftUI.Color("WeatherRain")
static let weatherSnow   = SwiftUI.Color("WeatherSnow")
static let weatherCloudy = SwiftUI.Color("WeatherCloudy")
static let weatherNight  = SwiftUI.Color("WeatherNight")
```

**6.3 DS.Animation에 추가**

```swift
static let atmosphereTransition = SwiftUI.Animation.easeInOut(duration: 1.5)
```

### Step 7: DashboardViewModel 통합

```swift
// New properties
private(set) var weatherSnapshot: WeatherSnapshot?
private(set) var weatherAtmosphere: WeatherAtmosphere = .default
private(set) var weatherError: String?

// New service
private let weatherService: WeatherFetching
private let locationService: LocationService

// loadData() 내에 추가
async let weatherTask = safeWeatherFetch()
```

### Step 8: project.yml / entitlements 수정

**project.yml**:
```yaml
INFOPLIST_KEY_NSLocationWhenInUseUsageDescription: "DUNE uses your location to show current weather and outdoor exercise recommendations."
```

**DUNE.entitlements**:
```xml
<key>com.apple.developer.weatherkit</key>
<true/>
```

**dependencies**:
```yaml
- sdk: WeatherKit.framework
- sdk: CoreLocation.framework
```

### Step 9: 테스트

**WeatherCoachingTests.swift**:
- 폭염 시 P2 recovery insight 생성
- 한파 시 P2 recovery insight 생성
- UV 8+ 시 P3 insight 생성
- 비 시 P4 indoor 추천
- 맑음+적당기온 시 P5 outdoor 추천
- 날씨 nil 시 기존 동작 변경 없음

**WeatherAtmosphereTests.swift**:
- clear+daytime → warmGlow
- rain → weatherRain
- snow → weatherSnow
- cloudy → weatherCloudy
- night → weatherNight
- default → clear+daytime

**WeatherCacheTests.swift**:
- 15분 이내 → not stale
- 15분 초과 → stale
- set → get 동일 값
- invalidate → nil

## Correction Log 준수 사항

- #1: Domain에 SwiftUI import 금지 → WeatherConditionType+View.swift로 분리
- #7: ViewModel에 import SwiftUI 금지 → Observation만 사용
- #42: 도메인 서비스 자체 입력 범위 검증 → temperature(-50~60°C), UV(0-15) 등
- #62: Domain에 인프라 문자열 금지 → WeatherKit 타입을 Data에서 WeatherConditionType으로 변환
- #80: Formatter 캐싱 → 불필요 (String interpolation 사용)
- #93: switch에 default 금지 → WeatherConditionType exhaustive
- #119: xcassets 색상은 Colors/ 하위 → WeatherRain.colorset 등
- #127: 다크 모드 opacity 최소 0.06
- #177: DS 색상은 xcassets 패턴 사용 → Color(red:green:blue:) 금지

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| WeatherKit API 호출 실패 | 15분 캐시 + graceful degradation (카드 미표시, 기본 배경) |
| 위치 권한 거부 | 날씨 섹션 미표시, 기존 UX 유지 |
| 배터리 소모 | significantLocationChange + 15분 캐싱 |
| 날씨 전환 시 배경 깜빡임 | atmosphereTransition 1.5초 easeInOut |
