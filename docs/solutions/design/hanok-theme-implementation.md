---
tags: [theme, hanok, design-system, wave-background, colorset]
date: 2026-03-04
category: solution
status: implemented
---

# 한옥(Hanok) 테마 구현 + Arctic/Solar 보완

## Problem

새로운 문화/지역 기반 테마(한옥)를 추가하고, 기존 Arctic Dawn/Solar Pop 테마의 누락된 wave background 구현을 보완해야 했음.

## Solution

### 1. 테마 추가 체크리스트 (새 테마 추가 시 필수 수정 파일)

| 파일 | 수정 내용 |
|------|----------|
| `Domain/Models/AppTheme.swift` | enum case 추가 |
| `Presentation/Shared/Extensions/AppTheme+View.swift` | assetPrefix, displayName, usesGlassBorder, wave-specific colors |
| `Presentation/Shared/Components/WaveShape.swift` | TabWaveBackground, DetailWaveBackground, SheetWaveBackground 3개 switch |
| `Presentation/Shared/Components/GlassCard.swift` | 모든 switch (heroBorder, darkBorder, bottomSeparator, surface, bloom, border) |
| `Presentation/Shared/Components/SectionGroup.swift` | borderWidth, sectionSurfaceGradient, sectionTopBloom, sectionBorderGradient |
| `Presentation/Shared/Components/ProgressRingView.swift` | accentGradientStops |
| `Resources/Localizable.xcstrings` | displayName 번역 (en/ko/ja) |
| `DUNEWatch/Resources/Localizable.xcstrings` | Watch displayName 번역 |
| `Shared/Resources/Colors.xcassets/` | 27개 colorset (Accent, Bronze, Dusk, Sand, Tab×3, Score×5, Metric×7, Weather×4, CardBackground + theme-specific) |

### 2. Wave Background 패턴

각 테마는 3단계 wave background 제공:
- **Tab** (TabWaveBackground): 3레이어, preset별 intensityScale, weather 대응
- **Detail** (DetailWaveBackground): 2레이어, 단순화
- **Sheet** (SheetWaveBackground): 1레이어, 최소

Custom Shape 사용 테마(Hanok)는 `WaveOverlayView` 대신 전용 View 구현.

### 3. Glass Border 분류

`usesGlassBorder` computed property로 glass-style 카드 보더 사용 여부를 단일 소스로 관리:
```swift
var usesGlassBorder: Bool {
    switch self {
    case .sakuraCalm, .arcticDawn, .solarPop, .hanok: true
    case .desertWarm, .oceanCool, .forestGreen: false
    }
}
```
OR-chain 반복 대신 이 프로퍼티를 사용.

### 4. Custom Shape 최적화

- `eaveShape` computed property를 body 상단에서 `let shape = eaveShape`로 캐싱하여 triple allocation 방지
- `.onAppear` + `.task` 중복 금지 — `.task`만 사용 (`.repeatForever` 애니메이션)
- Pre-rendered UIImage 텍스처(`HanjiTextureView`)는 `static let`으로 1회 생성

### 5. 색상 체계 (오방색 매핑)

한옥 테마는 한국 전통 오방색(五方色)을 건강 메트릭에 매핑:
- 적(赤) → Heart Rate (MetricHeartRate)
- 청(靑) → HRV (MetricHRV)
- 황(黃) → Accent, Bronze
- 백(白) → CardBackground, Mist
- 흑(黑) → Sleep metric

## Prevention

- 새 테마 추가 시 위 체크리스트의 모든 파일을 확인
- `CaseIterable` 기반 exhaustive switch가 누락을 컴파일 타임에 감지
- Glass border 판단은 `usesGlassBorder` 단일 소스 사용, OR-chain 금지
- Wave background는 반드시 Tab/Detail/Sheet 3종 세트로 구현
