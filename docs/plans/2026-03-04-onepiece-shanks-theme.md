---
tags: [theme, shanks, one-piece, red-hair-pirates, design-system]
date: 2026-03-04
category: plan
status: approved
---

# Plan: 원피스 샹크스 빨간머리해적단 테마 구현

## Summary

기존 6개 테마 시스템에 7번째 테마 `shanksRed` (prefix: "Shanks")를 추가한다.
빨간머리해적단 해적기(두개골+교차검)의 크림슨 레드/골드/다크네이비 색상 체계와
바다 위 해적기를 연상시키는 웨이브 배경을 구현한다.

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `Domain/Models/AppTheme.swift` | Edit | `shanksRed` case 추가 |
| `Presentation/Shared/Extensions/AppTheme+View.swift` | Edit | prefix dispatch + wave colors + displayName |
| `Presentation/Shared/Components/WaveShape.swift` | Edit | Tab/Detail/Sheet dispatch 추가 |
| `Presentation/Shared/Components/ShanksWaveBackground.swift` | New | Wave background 3종 |
| `Shared/Resources/Colors.xcassets/Shanks*.colorset/` | New | 27개 컬러셋 |
| `DUNEWatch/Views/WatchWaveBackground.swift` | Edit | Watch 테마 분기 추가 |
| `DUNETests/AppThemeTests.swift` | Edit | 테스트 업데이트 |
| `DUNE/Resources/Localizable.xcstrings` | Edit | "Shanks Red" ko/ja 번역 |
| `DUNEWatch/Resources/Localizable.xcstrings` | Edit | "Shanks Red" ko/ja 번역 |

## Color Palette (27 assets)

### Primary (4)
- ShanksAccent: #B81C1C / dark: #D42B2B (크림슨 레드)
- ShanksBronze: #C9A84C / dark: #D4B85A (해적기 골드)
- ShanksDusk: #1A1A2E / dark: #252540 (깊은 네이비)
- ShanksSand: #D4C5A9 / dark: #BFB094 (낡은 양피지)

### Card (1)
- ShanksCardBackground: #1C1018 / dark: #221420 (다크 와인)

### Tab (3)
- ShanksTabTrain: #DC3545 / dark: #E84855 (스칼렛)
- ShanksTabWellness: #722F37 / dark: #8A3B44 (와인)
- ShanksTabLife: #C9A84C / dark: #D4B85A (골드)

### Score (5)
- ShanksScoreExcellent: #C9A84C / dark: #D4B85A (골드)
- ShanksScoreGood: #B81C1C / dark: #D42B2B (크림슨)
- ShanksScoreFair: #CC5500 / dark: #E06600 (번트 오렌지)
- ShanksScoreTired: #722F37 / dark: #8A3B44 (다크 와인)
- ShanksScoreWarning: #2D2D3A / dark: #3A3A4A (차콜)

### Metric (7)
- ShanksMetricHRV: #4CAF50 / dark: #5BC760 (그린)
- ShanksMetricRHR: #1A1A2E / dark: #2A2A40 (네이비)
- ShanksMetricHeartRate: #DC3545 / dark: #E84855 (레드)
- ShanksMetricSleep: #2C2C54 / dark: #3C3C64 (딥 인디고)
- ShanksMetricActivity: #C9A84C / dark: #D4B85A (골드)
- ShanksMetricSteps: #8B6F47 / dark: #9C7F57 (앤틱 브론즈)
- ShanksMetricBody: #722F37 / dark: #8A3B44 (와인)

### Weather (4)
- ShanksWeatherRain: #3A3A5C / dark: #4A4A6C (스톰 블루)
- ShanksWeatherSnow: #A0A0B8 / dark: #B0B0C8 (실버)
- ShanksWeatherCloudy: #5A5A72 / dark: #6A6A82 (그레이 블루)
- ShanksWeatherNight: #0D0D14 / dark: #1A1A24 (미드나잇)

### Wave (3)
- ShanksDeep: #0D0D14 / dark: #141420 (해적기 블랙)
- ShanksCore: #8B1A1A / dark: #A02020 (딥 크림슨)
- ShanksGlow: #DC3545 / dark: #E84855 (스칼렛)

## Implementation Steps

1. AppTheme enum에 `shanksRed` case 추가
2. 27개 컬러셋 생성 (Colors.xcassets)
3. AppTheme+View.swift에 prefix + wave colors + displayName 추가
4. ShanksWaveBackground.swift 생성 (DesertDuneOverlayView 기반 + 크림슨 웨이브)
5. WaveShape.swift dispatch 추가
6. WatchWaveBackground.swift 분기 추가
7. AppThemeTests.swift 업데이트
8. Localizable.xcstrings 업데이트 (iOS + Watch)
9. 빌드 검증
