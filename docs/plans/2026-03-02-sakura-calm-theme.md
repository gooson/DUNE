---
tags: [theme, sakura, design-system, animation, wellness]
date: 2026-03-02
category: plan
status: approved
---

# Plan: Sakura Calm Theme 구현

## Summary

Sakura Calm 테마를 신규 추가합니다.  
소프트 핑크 + 아이보리 베이스에 딥 그린 포인트를 사용해 휴식/웰니스 무드의 고급스러운 비주얼을 제공하고, iOS + watchOS 모두에서 색상/배경/차트/카드/설정 UI를 일관되게 테마화합니다.

## Affected Files

### New Files

| File | Purpose |
|------|---------|
| `DUNE/Presentation/Shared/Components/SakuraPetalShape.swift` | Sakura 전용 petal silhouette shape |
| `DUNE/Presentation/Shared/Components/SakuraWaveBackground.swift` | Tab/Detail/Sheet Sakura 배경 3종 |
| `DUNETests/SakuraPetalShapeTests.swift` | shape geometry + animatable 검증 |
| 27 colorset dirs | Shared Sakura 색상 에셋 |

### Modified Files

| File | Change |
|------|--------|
| `DUNE/Domain/Models/AppTheme.swift` | `.sakuraCalm` case 추가 |
| `DUNE/Presentation/Shared/Extensions/AppTheme+View.swift` | Sakura 색상 매핑 추가 |
| `DUNE/Presentation/Shared/Components/WaveShape.swift` | Tab/Detail/Sheet dispatch에 `.sakuraCalm` 분기 |
| `DUNE/Presentation/Settings/Components/ThemePickerSection.swift` | Sakura swatch/표시명 반영 |
| `DUNE/Presentation/Shared/Components/GlassCard.swift` | Sakura border gradient 캐시 추가 |
| `DUNE/Presentation/Shared/Components/ProgressRingView.swift` | Sakura ring gradient 시작점 추가 |
| `DUNEWatch/Views/Extensions/AppTheme+WatchView.swift` | Sakura 색상 매핑 + 표시명 추가 |
| `DUNETests/AppThemeTests.swift` | 케이스 수/rawValue 검증 갱신 |

## Implementation Steps

### Step 1: Theme enum 확장

- `AppTheme`에 `.sakuraCalm = "sakuraCalm"` 추가
- 기존 switch 기반 exhaustive 분기에서 컴파일 타임 누락 검출

### Step 2: Sakura Shared Color Assets 추가 (27 colorsets)

`Shared/Resources/Colors.xcassets` 하위에 `Sakura*` 색상 세트 추가:

- Brand: `SakuraAccent`, `SakuraBronze`, `SakuraDusk`, `SakuraSand`, `SakuraCardBackground`
- Wave: `SakuraPetal`, `SakuraIvory`, `SakuraLeaf`
- Score: `SakuraScoreExcellent`, `SakuraScoreGood`, `SakuraScoreFair`, `SakuraScoreTired`, `SakuraScoreWarning`
- Metric: `SakuraMetricHRV`, `SakuraMetricRHR`, `SakuraMetricHeartRate`, `SakuraMetricSleep`, `SakuraMetricActivity`, `SakuraMetricSteps`, `SakuraMetricBody`
- Tab: `SakuraTabTrain`, `SakuraTabWellness`, `SakuraTabLife`
- Weather: `SakuraWeatherRain`, `SakuraWeatherSnow`, `SakuraWeatherCloudy`, `SakuraWeatherNight`

### Step 3: AppTheme+View / WatchView 매핑 확장

- iOS/Watch 모두 `accent/bronze/dusk/sand/tab/metric/displayName`에 Sakura 케이스 추가
- iOS는 score/weather/card 매핑도 추가

### Step 4: Sakura 전용 배경 구현

- `SakuraPetalShape`: 부드러운 능선 + petal pulse 기반 실루엣
- `SakuraWaveBackground`:
  - Tab: 3-layer parallax (Ivory haze / Petal band / Leaf accent)
  - Detail: 2-layer
  - Sheet: 1-layer + soft gradient
- 기존 `TabWaveBackground` dispatch에 `.sakuraCalm` 연결

### Step 5: ThemePicker / Card / Ring 확장

- `ThemePickerSection` swatch + 표시명 추가
- `GlassCard` gradient cache에 Sakura 추가
- `ProgressRingView` accent gradient 시작색에 Sakura 추가

### Step 6: 테스트 추가/수정

- `AppThemeTests`: case 수 4개 및 rawValue 검증 갱신
- `SakuraPetalShapeTests` 신규 추가:
  - path non-empty / zero rect empty
  - animatableData phase
  - petalDensity 변화에 따른 silhouette 변화

### Step 7: 검증

- 대상 테스트 실행:
  - `DUNETests/AppThemeTests`
  - `DUNETests/SakuraPetalShapeTests`
- 가능 시 iOS 테스트 스킴 전체 빌드/테스트 실행

## Risks / Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| 테마 분기 누락으로 컴파일 실패 | 높음 | AppTheme switch exhaustive 컴파일 에러로 즉시 수정 |
| 다크모드 대비 저하 | 중간 | SakuraDusk/SakuraLeaf를 깊은 톤으로 배치, 다크 변형 별도 제공 |
| 배경 애니메이션 성능 저하 | 중간 | 120샘플 고정 + 정적 노이즈 오버레이 재사용 + reduceMotion 준수 |

