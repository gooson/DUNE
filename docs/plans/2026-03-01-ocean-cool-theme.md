---
tags: [theme, ocean, wave, design-system, animation, ui, watch]
date: 2026-03-01
category: plan
status: draft
---

# Ocean Cool Theme — Implementation Plan

## Summary

Tier 3 Premium Ocean Cool 테마 + 전체 UI 색상 테마 전환 구현.
OceanWaveShape (비대칭 파형) + 4-레이어 Parallax + Swell 변조 + 모든 DS 토큰 테마화.

## Decision Log

1. Score gradient → Ocean 팔레트화 ✓
2. Weather 반응형 파도 → Ocean 테마에서도 유지 ✓
3. Watch 테마 적용 ✓
4. 메트릭 고유 색상 → Ocean 팔레트로 전환 ✓ (테마 독립 아님)

## Affected Files

### New Files

| File | Purpose |
|------|---------|
| `DUNE/Domain/Models/AppTheme.swift` | AppTheme enum (desertWarm, oceanCool) |
| `DUNE/Presentation/Shared/Components/OceanWaveShape.swift` | 비대칭 파형 Shape |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | Tab/Detail/Sheet 4-레이어 합성 |
| `DUNE/Resources/Assets.xcassets/Colors/Ocean*` | Ocean 색상 세트 (~25항목) |
| `DUNEWatch/Resources/Assets.xcassets/Colors/Ocean*` | Watch Ocean 색상 세트 (~15항목) |
| `DUNETests/AppThemeTests.swift` | 테마 로직 유닛 테스트 |

### Modified Files — Core Infrastructure

| File | Change |
|------|--------|
| `DUNE/Presentation/Shared/DesignSystem.swift` | 그라데이션/색상을 theme-aware computed로 변환 |
| `DUNEWatch/DesignSystem.swift` | Watch DS 테마 대응 |
| `DUNE/Presentation/Shared/Components/WavePreset.swift` | AppTheme environment key 추가 |
| `DUNE/Presentation/Shared/Components/WaveShape.swift` | TabWaveBackground에 테마 분기 추가 |
| `DUNE/App/ContentView.swift` | 테마 기반 waveColor/tint 설정 |
| `DUNE/Presentation/Settings/Components/ThemePickerSection.swift` | 실제 선택 기능 활성화 |
| `DUNE/Presentation/Settings/SettingsView.swift` | 테마 저장/로드 |

### Modified Files — Weather

| File | Change |
|------|--------|
| `DUNE/Presentation/Shared/Extensions/WeatherConditionType+View.swift` | waveColor/iconColor 테마 대응 |
| `DUNE/Presentation/Shared/Extensions/WeatherAtmosphere+View.swift` | gradientColors 테마 대응 |

### Modified Files — Watch Sync

| File | Change |
|------|--------|
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | 테마 sync 추가 |
| `DUNEWatch/WatchConnectivityManager.swift` | 테마 수신/적용 |

### Modified Files — UI Color Propagation (높은 영향)

| File | Change |
|------|--------|
| `DUNE/Presentation/Shared/Components/GlassCard.swift` | warmGlow → theme.accent |
| `DUNE/Presentation/Shared/Components/SectionGroup.swift` | sectionAccent 테마화 |
| `DUNE/Presentation/Dashboard/Components/HeroScoreCard.swift` | heroText gradient 테마화 |
| `DUNE/Presentation/Dashboard/Components/DetailScoreHero.swift` | heroText gradient 테마화 |
| 차트 컴포넌트 11개 | warmGlow 참조를 테마 색상으로 교체 |

## Implementation Steps

### Step 1: AppTheme Infrastructure (Domain + Presentation)

1.1. `AppTheme.swift` 생성 (Domain layer — Foundation only)
```swift
enum AppTheme: String, CaseIterable, Codable, Sendable {
    case desertWarm
    case oceanCool
}
```

1.2. `WavePreset.swift`에 AppTheme environment key 추가
```swift
private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .desertWarm
}
extension EnvironmentValues {
    var appTheme: AppTheme { get/set }
}
```

1.3. `AppTheme` color resolver extension (Presentation layer)
- `AppTheme+View.swift` in `Presentation/Shared/Extensions/`
- 각 테마별: accentColor, tabColors, desertBronze equivalent, etc.

### Step 2: Ocean Color Assets (xcassets)

2.1. iOS Assets (~25 색상):
- OceanAccent, OceanBronze, OceanDusk, OceanSand
- OceanDeep, OceanMid, OceanSurface, OceanFoam, OceanMist
- OceanTabTrain, OceanTabWellness, OceanTabLife
- OceanScoreExcellent/Good/Fair/Tired/Warning
- OceanMetricHRV/RHR/HeartRate/Sleep/Activity/Steps/Body
- OceanCardBackground
- OceanWeatherRain/Snow/Cloudy/Night

2.2. Watch Assets (~15 색상): iOS subset

### Step 3: OceanWaveShape

3.1. 새 Shape — 비대칭 파형
```swift
struct OceanWaveShape: Shape {
    let amplitude: CGFloat
    let frequency: CGFloat
    var phase: CGFloat  // animatable
    let verticalOffset: CGFloat
    let steepness: CGFloat  // 0.0~0.5
    let harmonicOffset: CGFloat
    // y = A * [sin(θ+phase) + steepness * sin(2θ+phase+harmonicOffset)]
}
```

3.2. 유닛 테스트 — boundary steepness values, path non-empty

### Step 4: Ocean Wave Backgrounds

4.1. `OceanWaveOverlayView` — driftDuration, direction 파라미터 추가
4.2. `OceanTabWaveBackground` — 4-레이어 합성 + Swell
4.3. `OceanDetailWaveBackground` — 3-레이어 (축소)
4.4. `OceanSheetWaveBackground` — 2-레이어 (최소)
4.5. DS.Animation에 ocean drift durations 추가

### Step 5: TabWaveBackground 테마 분기

5.1. 기존 TabWaveBackground → theme에 따라 Desert/Ocean 선택
```swift
@Environment(\.appTheme) private var theme
switch theme {
case .desertWarm: DesertWaveContent(...)
case .oceanCool: OceanWaveContent(...)
}
```
5.2. Detail/Sheet도 동일 패턴

### Step 6: DesignSystem 테마화

6.1. DS.Gradient → AppTheme 파라미터 받도록 변환
```swift
static func heroText(for theme: AppTheme) -> LinearGradient { ... }
```
또는 `DS.Gradient`를 theme-aware computed로:
```swift
static var heroText: LinearGradient {
    // 현재 theme은 전달 불가 (static context)
    // → 함수 시그니처로 변환 필요
}
```

6.2. 그라데이션 사용처에서 `@Environment(\.appTheme)` 읽어서 전달

### Step 7: Weather 테마 대응

7.1. `WeatherConditionType+View.swift` — waveColor/iconColor에 theme 파라미터
```swift
func waveColor(for theme: AppTheme) -> Color {
    switch (self, theme) {
    case (.clear, .desertWarm): DS.Color.warmGlow
    case (.clear, .oceanCool): Color("OceanAccent")
    // ...
    }
}
```

7.2. `WeatherAtmosphere+View.swift` — gradientColors 테마 대응

### Step 8: ContentView + Settings 통합

8.1. ContentView에서 `@AppStorage("com.dune.app.theme")` 읽기
8.2. `.environment(\.appTheme, selectedTheme)` 전역 설정
8.3. waveColor를 `theme.tabTodayColor` 등으로 교체
8.4. `.tint()` modifier를 `theme.accentColor`로 교체
8.5. ThemePickerSection — 실제 선택/저장 기능

### Step 9: UI Color Propagation

9.1. GlassCard, SectionGroup 등 핵심 컴포넌트 테마 대응
9.2. 차트 컴포넌트 warmGlow → theme accent
9.3. Score 색상 매핑
9.4. Metric 색상 매핑

### Step 10: Watch Sync

10.1. WatchSessionManager — 테마를 applicationContext에 포함
10.2. WatchConnectivityManager — 테마 수신/저장
10.3. Watch DesignSystem 테마 대응

### Step 11: Tests

11.1. AppTheme enum tests (codable, all cases)
11.2. OceanWaveShape path tests
11.3. Theme color resolver tests
11.4. Weather × Theme combination tests

### Step 12: Build Verification

12.1. `scripts/build-ios.sh` 실행
12.2. `xcodebuild test` 실행
