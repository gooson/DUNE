---
tags: [theme, sakura, design-system, wave-background, watch-parity]
date: 2026-03-02
category: solution
status: implemented
---

# Sakura Calm Theme (Soft Pink + Ivory + Deep Green)

## Problem

기존 테마(Desert/Ocean/Forest) 외에 감성 중심의 웰니스 무드를 가진 신규 테마가 필요했다.  
요구사항은 다음 3가지를 동시에 만족해야 했다.

1. 소프트 핑크 + 아이보리 + 딥 그린 포인트의 명확한 차별성
2. iOS + watchOS 테마 동기화/표시 일관성
3. 색상 토큰뿐 아니라 배경 애니메이션/카드/링/차트 색까지 전체 범위 적용

## Solution

### 1) AppTheme 확장

- `AppTheme`에 `.sakuraCalm` 추가
- `String rawValue` 기반 저장/동기화 구조 유지 (`sakuraCalm`)

### 2) Theme token 27종 추가 (Shared Colors.xcassets)

`Shared/Resources/Colors.xcassets`에 `Sakura*` colorset 27개 추가:

- Brand: Accent/Bronze/Dusk/Sand/CardBackground
- Wave: Petal/Ivory/Leaf
- Score: Excellent/Good/Fair/Tired/Warning
- Metric: HRV/RHR/HeartRate/Sleep/Activity/Steps/Body
- Tab: Train/Wellness/Life
- Weather: Rain/Snow/Cloudy/Night

공유 Asset Catalog를 사용하므로 iOS/watchOS 모두 동일 토큰을 참조한다.

### 3) iOS/watch 테마 매핑 확장

- `AppTheme+View.swift`: 모든 theme-aware 속성에 `.sakuraCalm` 추가
- `AppTheme+WatchView.swift`: watch에서 사용하는 accent/tab/metric/displayName에 `.sakuraCalm` 추가
- `ThemePickerSection.swift`: Sakura swatch 표시 추가

### 4) Sakura 전용 배경 컴포넌트 추가

신규 파일:

- `SakuraPetalShape.swift`
- `SakuraWaveBackground.swift`

구성:

- `SakuraPetalShape`: 부드러운 저주파 + blossom pulse + edge noise 조합
- `SakuraTabWaveBackground`: 3-layer (ivory haze / petal band / leaf anchor)
- `SakuraDetailWaveBackground`: 2-layer
- `SakuraSheetWaveBackground`: 1-layer

기존 `WaveShape.swift`의 theme dispatch에 `.sakuraCalm` 분기를 연결해 전체 화면 배경 흐름에 자동 통합했다.

### 5) 공통 컴포넌트 시각 일관성 반영

- `GlassCard.swift`: Sakura border gradient 캐시 추가
- `ProgressRingView.swift`: Sakura accent 시작점 gradient 추가

### 6) 테스트 확장

- `AppThemeTests`: 케이스 수(4) 및 rawValue 검증 업데이트
- `SakuraPetalShapeTests` 신규 추가:
  - non-empty/empty path
  - animatableData(phase)
  - petalDensity에 따른 profile 변화

## Prevention

- 새 테마 추가 체크리스트를 고정:
  1. `AppTheme` case + rawValue
  2. iOS/watch 매핑 switch exhaustive 확장
  3. Shared colorset 추가
  4. `WaveShape` dispatch 연결
  5. 공통 카드/링 시각 캐시 반영
  6. `AppThemeTests` + theme-specific shape tests 업데이트

- `xcodegen generate --spec DUNE/project.yml`를 실행해 새 파일이 `project.pbxproj`에 반영되도록 유지.

## Verification

- 성공:
  - `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNE -destination 'generic/platform=iOS Simulator' build`
  - `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'generic/platform=iOS Simulator' build-for-testing`

- 실패(환경 이슈):
  - `xcodebuild test ...` 실행 시 iOS 26.2 시뮬레이터에서 `Mach error -308` / `Invalid device state`로 런타임 테스트 실행 불가

