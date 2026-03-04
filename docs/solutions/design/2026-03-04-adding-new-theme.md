---
tags: [theme, design-system, prefix-dispatch, wave-background, exhaustive-switch]
date: 2026-03-04
category: solution
status: implemented
---

# 새 테마 추가 가이드 (Prefix-Based Theme System)

## Problem

기존 6개 테마에 7번째 테마(`shanksRed`)를 추가하면서 발견된 패턴과 체크리스트를 정리한다.

## Solution

### 1. 필수 수정 파일 체크리스트

| # | 파일 | 작업 |
|---|------|------|
| 1 | `Domain/Models/AppTheme.swift` | enum case 추가 |
| 2 | `Shared/Resources/Colors.xcassets/` | 27개 컬러셋 생성 (Prefix 기반) |
| 3 | `Presentation/Shared/Extensions/AppTheme+View.swift` | `assetPrefix`, wave colors, `displayName`, `usesGradientBorder` |
| 4 | `Presentation/Shared/Components/{Theme}WaveBackground.swift` | Tab/Detail/Sheet 3종 |
| 5 | `Presentation/Shared/Components/WaveShape.swift` | Tab/Detail/Sheet dispatch 3곳 |
| 6 | `Presentation/Shared/Components/GlassCard.swift` | static cached colors + gradients, exhaustive switches 9곳 |
| 7 | `Presentation/Shared/Components/ProgressRingView.swift` | static cached color + gradient switch |
| 8 | `Presentation/Shared/Components/SectionGroup.swift` | borderWidth, surface/bloom/border gradients 4곳 |
| 9 | `DUNEWatch/Views/WatchWaveBackground.swift` | boolean flag + gradient/opacity 분기 |
| 10 | `DUNETests/AppThemeTests.swift` | rawValue, allCases count, prefix, themedAssetName |
| 11 | `DUNE/Resources/Localizable.xcstrings` | displayName 번역 (en/ko/ja) |
| 12 | `DUNEWatch/Resources/Localizable.xcstrings` | Watch 번역 동기화 |

### 2. 컬러셋 카테고리 (27개)

- **Primary (4)**: Accent, Bronze, Dusk, Sand
- **Card (1)**: CardBackground
- **Tab (3)**: TabTrain, TabWellness, TabLife
- **Score (5)**: ScoreExcellent, ScoreGood, ScoreFair, ScoreTired, ScoreWarning
- **Metric (7)**: MetricHRV, MetricRHR, MetricHeartRate, MetricSleep, MetricActivity, MetricSteps, MetricBody
- **Weather (4)**: WeatherRain, WeatherSnow, WeatherCloudy, WeatherNight
- **Wave (3)**: Deep, Core, Glow

### 3. 핵심 패턴

#### Prefix-Based Asset Dispatch

```swift
// AppTheme+View.swift
var assetPrefix: String? {
    switch self {
    case .desertWarm: nil  // base theme
    case .shanksRed: "Shanks"  // prefix for all assets
    }
}
```

모든 테마 색상은 `themedColor(defaultAsset:variantSuffix:)` 를 통해 자동 해석된다.
Wave-specific 색상만 직접 `Color("ShanksDeep")` 접근.

#### Exhaustive Switch 강제

`default:` 사용 금지. 새 case 추가 시 컴파일 에러로 누락 방지.
단, Watch의 boolean flag 패턴(`isShanks`)은 컴파일 안전성이 없으므로 주의.

#### `usesGradientBorder` 패턴

테마 그룹 멤버십을 inline OR 체인 대신 computed property로 추출:

```swift
var usesGradientBorder: Bool {
    switch self {
    case .sakuraCalm, .arcticDawn, .solarPop, .shanksRed: true
    case .desertWarm, .oceanCool, .forestGreen: false
    }
}
```

### 4. 검증 방법

1. `grep -rn "\.solarPop" --include="*.swift" | wc -l` → shanksRed 동일 수 확인
2. 빌드 스크립트: `scripts/build-ios.sh`
3. 테스트: `AppThemeTests` — allCases count, rawValue, prefix, themedAssetName

## Prevention

- 새 테마 추가 시 이 체크리스트를 따른다
- Watch boolean flag 패턴을 exhaustive switch로 리팩토링하면 안전성 향상 (TODO)
- xcstrings 편집은 Xcode 또는 포맷 일치 도구 사용 (전체 reformat diff 방지)
