---
tags: [theme, arctic-dawn, glacier, aurora, design-system, watch-parity]
date: 2026-03-03
category: solution
status: implemented
related_files:
  - DUNE/Domain/Models/AppTheme.swift
  - DUNE/Presentation/Shared/Extensions/AppTheme+View.swift
  - DUNE/Presentation/Shared/Components/OceanWaveBackground.swift
  - DUNE/Presentation/Shared/Components/WaveShape.swift
  - DUNE/Presentation/Shared/Components/GlassCard.swift
  - DUNE/Presentation/Shared/Components/SectionGroup.swift
  - DUNE/Presentation/Shared/Components/ProgressRingView.swift
  - DUNEWatch/Views/WatchWaveBackground.swift
  - Shared/Resources/Colors.xcassets
  - DUNETests/AppThemeTests.swift
  - DUNETests/WaveShapeTests.swift
---

# Arctic Dawn Theme (Glacier + Aurora)

## Problem

기존 테마(Desert/Ocean/Forest/Sakura)와 감성적으로 확실히 구분되는 신규 테마가 필요했다.  
요구사항은 다음 3가지를 동시에 만족하는 것이었다.

1. 빙하 + 오로라 무드의 즉시 인지 가능한 차별성
2. iOS + watchOS 동시 적용
3. 색상 토큰뿐 아니라 배경/카드/링까지 전면 반영

## Solution

### 1) AppTheme 확장

- `AppTheme`에 `.arcticDawn` 추가 (`rawValue: "arcticDawn"`)
- prefix resolver에 `Arctic` 매핑 추가
- `displayName`에 `"Arctic Dawn"` 추가

### 2) Arctic 토큰 27종 추가

`Shared/Resources/Colors.xcassets`에 `Arctic*` colorset 27개를 추가했다.

- Brand: Accent/Bronze/Dusk/Sand/CardBackground
- Wave: Deep/Aurora/Frost
- Score: Excellent/Good/Fair/Tired/Warning
- Metric: HRV/RHR/HeartRate/Sleep/Activity/Steps/Body
- Tab: Train/Wellness/Life
- Weather: Rain/Snow/Cloudy/Night

### 3) Arctic 전용 배경 구현

- `OceanWaveBackground.swift`에 `ArcticRibbonShape` / `ArcticRibbonOverlayView` 추가
- `ArcticTabWaveBackground`, `ArcticDetailWaveBackground`, `ArcticSheetWaveBackground` 구현
- `WaveShape.swift` dispatch에 `.arcticDawn` 연결

### 4) 공통 컴포넌트 시각 반영

- `GlassCard.swift`: Arctic surface/border/separator gradient 추가
- `SectionGroup.swift`: Arctic section surface/top bloom/border 분기 추가
- `ProgressRingView.swift`: Arctic accent 시작점 gradient 분기 추가

### 5) watchOS 동시 반영

- `WatchWaveBackground.swift`에 Arctic 전용 aurora band 오버레이 추가
- Sakura 전용 로직과 충돌 없이 Arctic 모션을 분기 처리

### 6) 테스트 확장

- `AppThemeTests`: case 수(5), rawValue/prefix/themedAssetName 검증 업데이트
- `WaveShapeTests`: `ArcticRibbonShape` geometry/animatableData 테스트 추가

## Prevention

- 신규 테마 추가 시 체크리스트 고정:
1. `AppTheme` case + rawValue + prefix + displayName
2. Theme token 세트(brand/score/metric/tab/weather/card/wave) 일괄 추가
3. `WaveShape` dispatch + watch 배경 분기 반영
4. 공통 컴포넌트(`GlassCard`, `SectionGroup`, `ProgressRing`) 분기 반영
5. `AppThemeTests` + theme-specific shape tests 업데이트
6. Localizable 키(iOS/watch) 동시 반영

## Verification

- 성공:
  - `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNE -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'`
  - `xcodebuild test -quiet -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNETests/AppThemeTests -only-testing DUNETests/WaveShapeTests`
