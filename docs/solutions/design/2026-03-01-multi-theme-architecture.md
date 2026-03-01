---
tags: [theme, design-system, environment, xcassets, watch-sync, ocean-cool]
date: 2026-03-01
category: solution
status: implemented
---

# Multi-Theme Architecture (Ocean Cool Theme)

## Problem

앱 전체에 걸친 시각적 테마 전환 시스템이 필요. 하드코딩된 Desert Warm 색상을 테마 기반으로 전환하면서 성능(static 캐싱), 레이어 경계(Domain에 SwiftUI 금지), Watch 동기화를 모두 유지해야 함.

## Solution

### 1. Domain Model (Foundation only)

```swift
// DUNE/Domain/Models/AppTheme.swift
enum AppTheme: String, CaseIterable, Codable, Sendable {
    case desertWarm
    case oceanCool
}
```

- Foundation만 import → 레이어 경계 준수
- `String` rawValue → `@AppStorage` 자동 지원 (iOS 17.4+)
- `Codable` + `Sendable` → WatchConnectivity/CloudKit 호환

### 2. Environment 전파

```swift
// iOS: WavePreset.swift에 EnvironmentKey 추가
private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .desertWarm
}

// Watch: AppTheme+WatchView.swift에 별도 EnvironmentKey
private struct WatchAppThemeKey: EnvironmentKey { ... }
```

- iOS/Watch 별도 EnvironmentKey (다른 target → 충돌 없음)
- App 루트에서 `.environment(\.appTheme, selectedTheme)` 1회 주입
- 모든 자식 View는 `@Environment(\.appTheme)` 읽기만

### 3. 색상 해석 패턴 (AppTheme+View.swift)

```swift
extension AppTheme {
    var accentColor: Color {
        switch self {
        case .desertWarm: DS.Color.warmGlow      // 기존 DS 토큰
        case .oceanCool:  Color("OceanAccent")    // xcassets
        }
    }
}
```

- iOS: `AppTheme+View.swift` (278줄, ~30개 색상 속성)
- Watch: `AppTheme+WatchView.swift` (163줄, ~20개 색상 속성)
- xcassets 색상은 `Colors/` 하위 배치 (correction #119)
- light/dark 변형은 appearances로 구분 (correction #120)

### 4. Static Gradient 캐싱 (per-theme)

```swift
private enum GradientCache {
    static let desertGradient = LinearGradient(...)
    static let oceanGradient = LinearGradient(...)
    static func gradient(for theme: AppTheme) -> LinearGradient {
        switch theme {
        case .desertWarm: desertGradient
        case .oceanCool:  oceanGradient
        }
    }
}
```

- GlassCard, HeroScoreCard, ProgressRingView, ConditionHeroView에 적용
- `static let` 쌍 → `static func(for:)` 디스패치
- body에서 computed 매번 생성 금지 (correction #83)

### 5. Wave Background 라우팅

```swift
struct TabWaveBackground: View {
    @Environment(\.appTheme) private var theme
    var body: some View {
        switch theme {
        case .desertWarm: DesertTabWaveContent()   // 기존 sine wave
        case .oceanCool:  OceanTabWaveBackground() // 4-layer parallax
        }
    }
}
```

- Tab/Detail/Sheet 3개 레벨 모두 동일 패턴
- Desert: 기존 WaveShape (sine)
- Ocean: OceanWaveShape (harmonic enrichment) × 4 layers

### 6. Watch 테마 동기화

```swift
// iOS → Watch 전송 (WatchSessionManager)
let context = ["appTheme": themeRawValue, ...]
try WCSession.default.updateApplicationContext(context)

// Watch 수신 (WatchConnectivityManager)
if let themeRaw = parsed.appTheme, !themeRaw.isEmpty {
    syncedThemeRawValue = themeRaw
}

// Watch App에서 해석
AppTheme(rawValue: connectivity.syncedThemeRawValue) ?? .desertWarm
```

- applicationContext + sendMessage 양쪽 경로
- `ParsedWatchMessage`/`ParsedWatchContext`에 optional `appTheme` 필드 추가
- Watch는 자체 `@AppStorage` 없음 → 항상 iPhone에서 동기화

### 7. Non-View 컨텍스트 (enum 등)

```swift
// enum은 @Environment 접근 불가 → func(for:) 패턴
func color(for theme: AppTheme) -> Color {
    switch self {
    case .routine: return theme.accentColor
    ...
    }
}
// View에서: card.section.color(for: theme)
```

## Prevention

- 새 테마 추가 시: `AppTheme` case 추가 → `AppTheme+View.swift` + `AppTheme+WatchView.swift` switch 확장 → xcassets 색상 세트 추가
- exhaustive switch 강제로 누락 방지
- 새 색상 추가 시 iOS/Watch 양쪽 체크리스트 필수

## Key Files

| File | Role |
|------|------|
| `Domain/Models/AppTheme.swift` | Theme enum (shared) |
| `Presentation/Shared/Extensions/AppTheme+View.swift` | iOS 색상 해석 |
| `Presentation/Shared/Components/WavePreset.swift` | EnvironmentKey |
| `Presentation/Shared/Components/OceanWaveShape.swift` | 해양파 Shape |
| `Presentation/Shared/Components/OceanWaveBackground.swift` | 4-layer 배경 |
| `Presentation/Settings/Components/ThemePickerSection.swift` | 테마 선택 UI |
| `Data/WatchConnectivity/WatchSessionManager.swift` | iOS→Watch 전송 |
| `DUNEWatch/WatchConnectivityManager.swift` | Watch 수신 |
| `DUNEWatch/Views/Extensions/AppTheme+WatchView.swift` | Watch 색상 해석 |
