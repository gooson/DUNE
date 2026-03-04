---
tags: [theme, hanok, arctic, solar, wave-background, design-system]
date: 2026-03-04
category: plan
status: approved
---

# Plan: 한옥 테마 추가 + Arctic/Solar 배경 보완

## Summary

AppTheme에 `.hanok` case를 추가하고 풀 구현(색상 + 웨이브 배경 3종)을 수행.
Arctic Dawn / Solar Pop의 누락된 Tab/Detail/Sheet 배경을 추가.

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `Domain/Models/AppTheme.swift` | Edit | `.hanok` case 추가, alias 처리 |
| `Presentation/Shared/Extensions/AppTheme+View.swift` | Edit | Hanok 색상 매핑 + displayName |
| `Presentation/Shared/Components/WaveShape.swift` | Edit | dispatcher에 `.hanok` case 추가 |
| `Presentation/Shared/Components/HanokWaveBackground.swift` | Create | Tab/Detail/Sheet 배경 3종 |
| `Presentation/Shared/Components/HanokEaveShape.swift` | Create | 처마 곡선 커스텀 Shape |
| `Presentation/Shared/Components/ArcticWaveBackground.swift` | Create | Tab/Detail/Sheet 배경 3종 |
| `Presentation/Shared/Components/SolarWaveBackground.swift` | Create | Tab/Detail/Sheet 배경 3종 |
| `Shared/Resources/Colors.xcassets/Hanok*.colorset` | Create | ~27개 colorset |
| `Localizable.xcstrings` (iOS) | Edit | "Hanok" displayName en/ko/ja |
| `DUNETests/HanokEaveShapeTests.swift` | Create | Shape 유닛 테스트 |

## Implementation Steps

### Step 1: AppTheme enum 확장
- `.hanok` case 추가 (rawValue: "hanok")
- `resolvedTheme`에 backward-compatible alias 추가
- `assetPrefix` → "Hanok"
- `displayName` → `String(localized: "Hanok")`

### Step 2: Asset Catalog 색상 생성
27개 colorset (Arctic/Solar와 동일 세트):
- HanokAccent, HanokBronze, HanokDusk, HanokSand
- HanokCardBackground
- HanokScoreExcellent/Good/Fair/Tired/Warning
- HanokMetricHRV/RHR/HeartRate/Sleep/Activity/Steps/Body
- HanokTabTrain/Wellness/Life
- HanokWeatherRain/Snow/Cloudy/Night
- HanokDeep, HanokMid, HanokMist (wave-specific)

### Step 3: AppTheme+View 색상 매핑
- Hanok wave-specific colors (file-private in background file)
- displayName 추가

### Step 4: HanokEaveShape 구현
- WaveSamples 재활용
- 기와 곡선: sine 기반 + 처마 끝 상승 (2nd harmonic)
- edge noise: 기와 마루의 미세한 불규칙성

### Step 5: HanokWaveBackground 구현
- Tab: 3레이어 (기와/처마/바람)
- Detail: 2레이어 (한지 물결)
- Sheet: 1레이어 (온돌 숨결)
- HanjiTextureView: pre-rendered UIImage (UkiyoeGrainView 패턴 차용)

### Step 6: ArcticWaveBackground 구현
- Tab: 기존 AppTheme+View의 arctic 색상 활용, WaveShape 기반 오로라 레이어
- Detail: 2레이어 축소판
- Sheet: 1레이어 최소판

### Step 7: SolarWaveBackground 구현
- Tab: solar 색상 활용, WaveShape 기반 열기 레이어
- Detail: 2레이어 축소판
- Sheet: 1레이어 최소판

### Step 8: WaveShape.swift dispatcher 업데이트
- `.hanok` case 추가 (Tab/Detail/Sheet 각각)

### Step 9: Localizable.xcstrings 업데이트
- "Hanok" → ko: "한옥", ja: "韓屋"

### Step 10: 유닛 테스트
- HanokEaveShape path 생성 검증
- 빈 rect, 0 amplitude 등 경계값

### Step 11: 빌드 검증
- `scripts/build-ios.sh`
