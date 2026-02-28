---
tags: [design-system, color, desert-horizon, full-overhaul]
date: 2026-02-28
category: plan
status: draft
source: docs/brainstorms/2026-02-28-desert-horizon-full-redesign.md
---

# Plan: Desert Horizon 전면 디자인 리디자인

## Overview

투데이 링의 Desert Horizon 비주얼 DNA를 앱 전체로 확장하는 전면 리디자인.
xcassets RGB 값 교체(자동 전파) + 코드 레벨 사막화(차트/카드/텍스트/모션).

## Strategy: xcassets-First Approach

핵심 전략: **xcassets colorset의 RGB 값을 교체하면 DS.Color 토큰을 참조하는 98+ 파일에 코드 변경 없이 자동 전파**.
코드 변경은 토큰 추가/삭제, 차트 gradient 패턴, 카드 스타일, 모션에만 필요.

---

## Phase 1: DS 토큰 기반 정비

### 1-1. xcassets Metric Colorset RGB 교체 (9개)

| Colorset | 현재 Light | 교체 Light | 현재 Dark | 교체 Dark | 사막 이름 |
|----------|-----------|-----------|----------|----------|----------|
| MetricHRV | (0.745,0.588,0.353) | (0.76,0.60,0.36) | (0.824,0.667,0.431) | (0.84,0.68,0.44) | Desert Gold |
| MetricRHR | (0.863,0.467,0.373) | (0.80,0.48,0.36) | (0.929,0.549,0.455) | (0.88,0.56,0.44) | Terracotta |
| MetricHeartRate | (0.906,0.298,0.235) | (0.84,0.34,0.28) | (0.957,0.400,0.345) | (0.92,0.42,0.36) | Sunset Crimson |
| MetricSleep | (0.478,0.400,0.745) | (0.42,0.38,0.62) | (0.549,0.510,0.824) | (0.52,0.48,0.72) | Twilight Indigo |
| MetricActivity | (0.337,0.718,0.478) | (0.45,0.60,0.42) | (0.431,0.824,0.588) | (0.53,0.70,0.50) | Desert Sage |
| MetricSteps | (0.275,0.675,0.686) | (0.32,0.58,0.58) | (0.353,0.784,0.784) | (0.40,0.68,0.66) | Oasis Teal |
| MetricBody | (0.804,0.584,0.216) | (0.78,0.58,0.28) | (0.871,0.651,0.302) | (0.86,0.66,0.36) | Canyon Amber |
| WellnessVitals | (0.565,0.659,0.439) | (0.52,0.58,0.38) | (0.647,0.737,0.525) | (0.60,0.66,0.46) | Canyon Olive |
| WellnessFitness | (0.420,0.706,0.337) | (0.46,0.60,0.36) | (0.510,0.804,0.431) | (0.54,0.70,0.44) | Dune Sage |

영향: **98+ 파일 자동 전파, 코드 변경 0**

### 1-2. xcassets Score Colorset RGB 교체 (5개) + Wellness 4개 삭제

**Score 교체:**

| Colorset | 현재 Light | 교체 Light | 현재 Dark | 교체 Dark | 사막 이름 |
|----------|-----------|-----------|----------|----------|----------|
| ScoreExcellent | (0.000,0.800,0.545) | (0.18,0.68,0.56) | (0.000,0.878,0.620) | (0.22,0.76,0.64) | Dawn Oasis |
| ScoreGood | (0.220,0.780,0.420) | (0.42,0.64,0.40) | (0.290,0.871,0.502) | (0.50,0.72,0.48) | Morning Sage |
| ScoreFair | (0.918,0.702,0.059) | (0.82,0.66,0.24) | (0.984,0.749,0.141) | (0.90,0.72,0.32) | Midday Sand |
| ScoreTired | (0.922,0.498,0.180) | (0.82,0.48,0.30) | (0.984,0.573,0.235) | (0.90,0.56,0.38) | Dusk Terracotta |
| ScoreWarning | (0.894,0.200,0.310) | (0.80,0.28,0.26) | (0.957,0.247,0.369) | (0.88,0.36,0.34) | Night Ember |

**Wellness 삭제 (4개):**
- `WellnessScoreExcellent.colorset/` → 삭제
- `WellnessScoreGood.colorset/` → 삭제
- `WellnessScoreFair.colorset/` → 삭제
- `WellnessScoreWarning.colorset/` → 삭제

### 1-3. xcassets HR Zone Colorset RGB 교체 (5개)

| Colorset | 교체 Light | 교체 Dark | 사막 이름 |
|----------|-----------|----------|----------|
| HRZone1 | (0.42,0.56,0.64) | (0.50,0.64,0.72) | Dawn Blue |
| HRZone2 | (0.72,0.62,0.42) | (0.80,0.70,0.50) | Morning Sand |
| HRZone3 | (0.82,0.66,0.24) | (0.90,0.72,0.32) | Midday Gold |
| HRZone4 | (0.82,0.48,0.30) | (0.90,0.56,0.38) | Sunset Ember |
| HRZone5 | (0.80,0.28,0.26) | (0.88,0.36,0.34) | Desert Fire |

### 1-4. DesignSystem.swift 토큰 업데이트

**파일**: `DUNE/Presentation/Shared/DesignSystem.swift`

변경:
- `wellnessExcellent/Good/Fair/Warning` 4개 토큰 삭제
- `DS.Opacity` 새 토큰 3개 추가: `chartGrid(0.06)`, `cardOverlay(0.03)`, `hintBlend(0.04)`
- `DS.Gradient` 새 토큰 추가: `chartAreaFade`, `sectionAccent`

### 1-5. WellnessScore+View.swift 통합

**파일**: `DUNE/Presentation/Shared/Extensions/WellnessScore+View.swift`

```swift
// 변경 전
case .excellent: DS.Color.wellnessExcellent
case .good:      DS.Color.wellnessGood
case .fair:      DS.Color.wellnessFair
case .tired:     DS.Color.scoreTired  // 이미 공유
case .warning:   DS.Color.wellnessWarning

// 변경 후
case .excellent: DS.Color.scoreExcellent
case .good:      DS.Color.scoreGood
case .fair:      DS.Color.scoreFair
case .tired:     DS.Color.scoreTired
case .warning:   DS.Color.scoreWarning
```

### 1-6. Watch DS 동기화

**파일**: `DUNEWatch/DesignSystem.swift`

- Wellness 토큰 4개 삭제 (iOS와 동일)
- Watch xcassets에서 Wellness colorset 4개 삭제
- Metric/Score/Zone colorset RGB 값 iOS와 동일하게 교체

---

## Phase 2: 차트 사막화

### 2-1. AreaLineChartView — area gradient에 warmGlow blend 강화

**파일**: `DUNE/Presentation/Shared/Charts/AreaLineChartView.swift`

현재 이미 warmGlow blend가 있음. 그래디언트 정지점 미세 조정:
```swift
// warmGlow 비중을 약간 높여 사막 바닥 느낌 강화
// 현재: tintColor.opacity(0.25) → tintColor.opacity(0.08) → warmGlow.opacity(0.25)
// 제안: tintColor.opacity(0.22) → warmGlow.opacity(0.06) → warmGlow.opacity(0.03)
```

### 2-2. Chart Grid Line — 이미 warmGlow 적용 확인

현재 `warmGlow.opacity(0.30)` 사용 중 → 유지 (이미 사막화 완료)

### 2-3. Chart Selection Indicator — 이미 warmGlow 적용 확인

현재 `warmGlow.opacity(0.35)` dashed → 유지 (이미 사막화 완료)

### 2-4. TrainingLoadChartView — `.orange` 하드코딩 제거

**파일**: `DUNE/Presentation/Activity/Components/TrainingLoadChartView.swift`

```swift
// 변경 전
case 2..<4: .orange  // 하드코딩
// 변경 후
case 2..<4: DS.Color.scoreTired  // DS 토큰 사용 (Dusk Terracotta)
```

### 2-5. Bar Chart 미세 그라데이션

BarMark에 `.gradient` suffix 추가 — 하단이 약간 밝아지는 효과:
```swift
// 기존: .foregroundStyle(color)
// 제안: .foregroundStyle(color.gradient)
```
이미 일부 차트에서 사용 중 (`WeeklySummaryChartView`). 나머지 BarMark에도 일괄 적용.

---

## Phase 3: 카드 & 텍스트 사막화

### 3-1. StandardCard 보더 골드→블루 gradient

**파일**: `DUNE/Presentation/Shared/Components/GlassCard.swift`

현재 이미 `warmGlow(0.35)` + `desertDusk(0.25)` 패턴 사용 → 확인 후 유지/미세 조정

### 3-2. 핵심 수치에 DesertBronze gradient 확대

현재 HeroScoreCard/ConditionHeroView에서 사용 중인 gradient를:
- `VitalCard.swift` 메인 값
- `MetricSummaryHeader.swift` 메인 값
- Chart selection annotation 값

에도 적용. `DS.Gradient.heroScoreText` 토큰을 공유.

**영향 파일**:
- `DUNE/Presentation/Wellness/Components/VitalCard.swift`
- `DUNE/Presentation/Shared/Detail/MetricSummaryHeader.swift`

### 3-3. SandMuted 장식 텍스트 적용

현재 차트 축 레이블에는 `sandMuted` 이미 적용됨.
추가 적용 대상:
- 카드 내 타임스탬프 / "Updated N min ago"
- 단위 텍스트 (ms, bpm, kg 등)

**영향 파일**: 각 카드 컴포넌트에서 `.secondary` → `DS.Color.sandMuted` 교체 (장식적 텍스트만)

### 3-4. Section Title Accent Bar

**파일**: 새 ViewModifier 또는 `DesignSystem.swift`에 추가

```swift
struct SectionAccentBar: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(DS.Color.warmGlow.opacity(0.3))
            .frame(width: 2, height: 14)
    }
}
```

영향: 각 Section header에 accent bar 추가

---

## Phase 4: Watch 적용

### 4-1. Watch xcassets 색상 동기화

iOS와 동일한 RGB 값으로 교체:
- Metric colorsets (Watch에 존재하는 것만)
- Score colorsets
- HR Zone colorsets

### 4-2. Watch 하드코딩 교체

이전 design-consistency-integration에서 이미 대부분 완료.
남은 하드코딩 확인 후 교체.

### 4-3. Watch 카드 warmGlow 힌트

Watch 뷰에 미세한 warmGlow 배경 힌트 추가 (이미 WatchWaveBackground 적용된 뷰 확인).

---

## Phase 5: 모션 & 환경 요소

### 5-1. Period 전환 Sand Shimmer

차트 기간 전환 시 0.3초간 warmGlow shimmer overlay:

```swift
// ChartPeriodTransition modifier
.overlay {
    if isTransitioning {
        Rectangle()
            .fill(DS.Color.warmGlow.opacity(0.06))
            .transition(.opacity)
            .animation(DS.Animation.shimmer, value: isTransitioning)
    }
}
```

### 5-2. Card 등장 Warm Flash

카드 뷰포트 진입 시 border opacity 0.3 → 0.15 fade:

```swift
.onAppear {
    withAnimation(DS.Animation.emphasize) {
        borderOpacity = DS.Opacity.border // 0.15 resting state
    }
}
```

### 5-3. Pull-to-Refresh 사막화

**파일**: `DUNE/Presentation/Shared/Components/WaveRefreshIndicator.swift`

웨이브 stroke에 warmGlow→desertDusk gradient 적용.

### 5-4. Dark Mode 배경 미세 Brown Shift

**파일**: `SurfacePrimary.colorset`의 dark variant 조정

```
현재 dark: 시스템 기본 (거의 순수 검정)
제안: 미세한 warm shift — (0.06, 0.05, 0.04) 정도의 다크 브라운 힌트
```

### 5-5. Empty State 사막 일러스트 힌트

**파일**: `DUNE/Presentation/Shared/Components/EmptyStateView.swift`

웨이브 decoration을 warmGlow→desertDusk 듀얼 톤으로 변경.

---

## Phase 6: 접근성 & 검증

### 6-1. 색맹 시뮬레이션 테스트

Xcode Accessibility Inspector로 Protanopia/Deuteranopia 시뮬레이션.
인접 배치 색상 쌍의 구분 가능성 검증.

### 6-2. WCAG AAA Contrast 달성

모든 변경 색상의 contrast ratio 검증:
- Light mode: 흰 배경 대비 7:1
- Dark mode: 검정 배경 대비 7:1
- 미달 시 채도/밝기 조정

### 6-3. 빌드 검증

```bash
scripts/build-ios.sh  # iOS 빌드
# Watch 빌드
xcodebuild -project Dailve/Dailve.xcodeproj -scheme DailveWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.2'
```

### 6-4. 다크/라이트 모드 시각 검증

시뮬레이터에서 모든 탭 스크린샷 촬영:
- iPhone (compact): Today, Train, Wellness, Exercise
- iPad (regular): 동일 4탭
- Watch: Home, Workout, Summary

---

## Affected Files Summary

### xcassets (자동 전파 — 코드 변경 불필요)

| 작업 | 파일 수 |
|------|--------|
| Metric colorset RGB 교체 | 9 |
| Score colorset RGB 교체 | 5 |
| HR Zone colorset RGB 교체 | 5 |
| Wellness colorset 삭제 | 4 |
| SurfacePrimary dark shift | 1 |
| **소계** | **24 colorset 변경** |

### 코드 변경 필요

| 파일 | 변경 내용 | Phase |
|------|----------|-------|
| `DesignSystem.swift` (iOS) | Wellness 토큰 삭제, Opacity/Gradient 추가 | 1 |
| `DesignSystem.swift` (Watch) | Wellness 토큰 삭제, 동기화 | 1 |
| `WellnessScore+View.swift` | wellness* → score* 통일 | 1 |
| `TrainingLoadChartView.swift` | `.orange` → DS 토큰 | 2 |
| `AreaLineChartView.swift` | area gradient 미세 조정 | 2 |
| `VitalCard.swift` | 메인 값에 DesertBronze gradient | 3 |
| `MetricSummaryHeader.swift` | 메인 값에 DesertBronze gradient | 3 |
| `GlassCard.swift` | StandardCard overlay 미세 조정 | 3 |
| `EmptyStateView.swift` | 듀얼 톤 웨이브 | 5 |
| `WaveRefreshIndicator.swift` | stroke gradient | 5 |
| Section header 관련 파일들 | accent bar 추가 | 3 |
| Watch 뷰 파일들 | 남은 하드코딩 교체 | 4 |
| **소계** | **~15 파일 코드 변경** |

### 자동 전파 (코드 변경 없음)

xcassets RGB 변경으로 자동 업데이트되는 파일: **98+ 파일**

---

## Implementation Order

```
Phase 1: xcassets RGB 교체 + 토큰 정리 (가장 큰 영향, 가장 적은 코드 변경)
    ↓
Phase 2: 차트 사막화 (하드코딩 제거 + gradient 조정)
    ↓
Phase 3: 카드 & 텍스트 사막화 (DesertBronze 확대 + SandMuted 적용)
    ↓
Phase 4: Watch 동기화 (xcassets + 남은 하드코딩)
    ↓
Phase 5: 모션 & 환경 (shimmer, flash, refresh, dark bg, empty state)
    ↓
Phase 6: 접근성 & 검증 (색맹, WCAG, 빌드, 시각 테스트)
```

## Risk Assessment

| 리스크 | 확률 | 영향 | 완화 |
|-------|------|------|------|
| Muted 색상 light mode 가시성 부족 | 중 | 중 | 프로토타입 후 채도 조정 |
| 인접 metric 색상 구분 어려움 | 중 | 중 | hue 20°+ 차이 검증 |
| Watch colorset 누락 | 저 | 저 | iOS/Watch 대조 체크리스트 |
| WCAG AAA 미달 | 중 | 중 | 미달 시 밝기 조정으로 해결 |
