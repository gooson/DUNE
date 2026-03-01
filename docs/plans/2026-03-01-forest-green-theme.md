---
tags: [theme, forest, ukiyo-e, design-system, animation]
date: 2026-03-01
category: plan
status: approved
---

# Plan: Forest Green Theme 구현

## Summary

우키요에 스타일 산/숲 실루엣 배경 + 전체 UI 색상 테마를 추가합니다.

## Affected Files

### New Files

| File | Purpose |
|------|---------|
| `DUNE/Presentation/Shared/Components/ForestWaveBackground.swift` | Tab/Detail/Sheet 배경 3종 |
| `DUNE/Presentation/Shared/Components/ForestSilhouetteShape.swift` | 산/숲 실루엣 Shape + grain overlay |
| 28 colorset dirs (iOS) | Forest 색상 에셋 |
| 15 colorset dirs (watchOS) | Forest 색상 에셋 (Watch) |

### Modified Files

| File | Change |
|------|--------|
| `DUNE/Domain/Models/AppTheme.swift` | `.forestGreen` case 추가 |
| `DUNE/Presentation/Shared/Extensions/AppTheme+View.swift` | Forest 색상 매핑 추가 |
| `DUNE/Presentation/Shared/Components/WaveShape.swift` | Tab/Detail/Sheet dispatch에 `.forestGreen` 분기 |
| `DUNE/Presentation/Settings/Components/ThemePickerSection.swift` | Coming Soon 제거, Forest 활성화 |
| `DUNEWatch/Views/Extensions/AppTheme+WatchView.swift` | Forest 색상 매핑 추가 |
| `DUNEWatch/Views/WatchWaveBackground.swift` | Forest 테마 분기 (optional) |
| `DUNE/Resources/Localizable.xcstrings` | "Forest Green" 번역 추가 |
| `DUNEWatch/Resources/Localizable.xcstrings` | "Forest Green" 번역 추가 |

## Implementation Steps

### Step 1: AppTheme case 추가

`AppTheme.swift`에 `.forestGreen` 추가.

### Step 2: iOS Color Assets (28 colorsets)

`DUNE/Resources/Assets.xcassets/Colors/` 하위에 `Forest` prefix 색상 생성.

#### Brand/Accent (5)
- `ForestAccent` — 금빛 (D4A843 / E0B84D)
- `ForestBronze` — 붉은 단풍 (C73E1D / D44E2D)
- `ForestDusk` — 나무줄기 갈색 (5A3E28 / 6B4E38)
- `ForestSand` — 연한 초록 (8FB996 / 7BA888)
- `ForestCardBackground` — 카드 배경

#### Wave-specific (4)
- `ForestDeep` — 근경 숲 (1A3A2A / 0F2E1F)
- `ForestMid` — 중경 숲 (2D5A3D / 234D32)
- `ForestMist` — 원경 안개 (A8CDB0 / 8FB996)
- `ForestFoam` — 빛/하이라이트 (F0E6C8 / D4CEB0)

#### Score (5)
- `ForestScoreExcellent` — 생동 초록 (4CAF50 / 66BB6A)
- `ForestScoreGood` — 새잎 (8BC34A / A0D468)
- `ForestScoreFair` — 가을잎 금빛 (D4A843 / E0B84D)
- `ForestScoreTired` — 마른잎 주황 (E07B39 / E8934F)
- `ForestScoreWarning` — 낙엽 붉은 (C73E1D / D44E2D)

#### Metric (7)
- `ForestMetricHRV` — (4CAF50 / 66BB6A)
- `ForestMetricRHR` — (2D5A3D / 3D7A52)
- `ForestMetricHeartRate` — (C73E1D / D44E2D)
- `ForestMetricSleep` — (1A3A2A / 2D4A3A)
- `ForestMetricActivity` — (D4A843 / E0B84D)
- `ForestMetricSteps` — (8FB996 / A8CDB0)
- `ForestMetricBody` — (6B4E38 / 8A6A50)

#### Tab (3)
- `ForestTabTrain` — 붉은 단풍 (C73E1D / D44E2D)
- `ForestTabWellness` — 중경 초록 (2D5A3D / 3D7A52)
- `ForestTabLife` — 안개 초록 (8FB996 / A8CDB0)

#### Weather (4)
- `ForestWeatherRain` — 이끼 비 (5A8A6A / 6B9B7B)
- `ForestWeatherSnow` — 서리 잎 (C8D8C0 / B8C8B0)
- `ForestWeatherCloudy` — 안개 숲 (7A9A7A / 6A8A6A)
- `ForestWeatherNight` — 밤 숲 (0F2E1F / 0A1F15)

### Step 3: watchOS Color Assets (15 colorsets)

Brand (4) + Wave (4) + Metric (5) + Tab (2). Score/Weather/Card는 watchOS에서 사용 안 함.

### Step 4: ForestSilhouetteShape 구현

```
파일: ForestSilhouetteShape.swift
- ForestSilhouetteShape: Shape (120 samples, animatable phase)
  - sin(θ) + ruggedness * sin(3θ) + treeDensity * trianglePulse(θ)
  - pre-computed edgeNoise for washi edge effect
- ForestWaveOverlayView: View (단일 레이어 + grain + bokashi)
- UkiyoeGrainView: View (Canvas noise overlay)
```

### Step 5: ForestWaveBackground 구현

```
파일: ForestWaveBackground.swift
- ForestTabWaveBackground: View (3레이어 Far/Mid/Near)
- ForestDetailWaveBackground: View (2레이어 Far/Near, 축소)
- ForestSheetWaveBackground: View (1레이어 Near, 최소)
```

### Step 6: WaveShape.swift 분기 추가

Tab/Detail/Sheet Background의 theme switch에 `.forestGreen` 분기 추가.

### Step 7: AppTheme+View.swift 색상 매핑

모든 computed property에 `.forestGreen` case 추가.

### Step 8: ThemePickerSection 활성화

Coming Soon placeholder 제거, ForEach에서 자동 표시.

### Step 9: watchOS 통합

- `AppTheme+WatchView.swift`에 `.forestGreen` case 추가
- `WatchWaveBackground`는 기존 sine 그대로 사용 (색상만 Forest)

### Step 10: Localization

- iOS/Watch xcstrings에 "Forest Green" 번역 추가 (ko: "포레스트 그린", ja: "フォレストグリーン")

### Step 11: 빌드 검증

`scripts/build-ios.sh` 실행.
