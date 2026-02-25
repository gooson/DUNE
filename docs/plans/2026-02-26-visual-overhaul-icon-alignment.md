---
tags: [design, ux, visual, dark-mode, color-palette, icon-alignment, card-style]
date: 2026-02-26
category: plan
status: draft
source: docs/brainstorms/2026-02-26-visual-overhaul-icon-alignment.md
---

# Plan: App Icon 기반 전체 비주얼 오버홀

## Overview

앱 아이콘(다크 + 오렌지-골드 파동선)과 앱 내부 UI의 시각적 일관성을 확보한다.
다크 모드 우선 설계로, 세 탭(Today/Activity/Wellness)을 균일한 프리미엄 톤으로 통일한다.

## Approach

**핵심 전략**: Color asset 값 변경 → 모든 `DS.Color.*` 토큰이 자동 반영되므로, colorset 파일 수정만으로 앱 전체 색상이 전환된다. 이후 카드 스타일, 배경 그라디언트, 웨이브 모티프를 순차 적용.

**메트릭 색상 구분 전략**: 옵션 A 채택 — warm 스펙트럼 내에서 분산.
- HRV: 앰버/골드 (아이콘 핵심 톤)
- RHR: 코랄/살몬
- HR: 따뜻한 레드 (현행 유지)
- Sleep: 인디고/딥퍼플 (밤 연상, 유지하되 약간 워밍)
- Activity: 따뜻한 에메랄드 (현행 초록에서 yellow-shift)
- Steps: 따뜻한 틸/민트 (시안에서 green-shift)
- Body: 골드 (현행 유지)
- Vitals: 소프트 앰버
- Fitness: 따뜻한 그린

---

## Affected Files

### Phase 1: Color Palette Warming (colorset 수정)

| File | Change | Impact |
|------|--------|--------|
| `Assets.xcassets/Colors/MetricHRV.colorset/Contents.json` | 보라→앰버/골드 | HRV 차트, 카드, 링 전체 |
| `Assets.xcassets/Colors/MetricSleep.colorset/Contents.json` | 밝은보라→딥인디고(약간 warm) | 수면 차트, 카드 |
| `Assets.xcassets/Colors/MetricActivity.colorset/Contents.json` | 차가운초록→따뜻한에메랄드 | 활동 카드, 섹션 |
| `Assets.xcassets/Colors/MetricSteps.colorset/Contents.json` | 시안→따뜻한틸 | 걸음 카드, 차트 |
| `Assets.xcassets/Colors/MetricRHR.colorset/Contents.json` | 핑크→코랄/살몬 | RHR 카드, 차트 |
| `Assets.xcassets/Colors/WellnessVitals.colorset/Contents.json` | 틸→소프트앰버 | Vitals 섹션 아이콘 |
| `Assets.xcassets/Colors/WellnessFitness.colorset/Contents.json` | 초록→따뜻한그린 | Fitness 섹션 아이콘 |
| `Assets.xcassets/Colors/SurfacePrimary.colorset/Contents.json` | Light: 연보라→웜크림 | 라이트모드 배경 전체 |
| `Assets.xcassets/Colors/CardBackground.colorset/Contents.json` | Light: 순백→웜크림 | 라이트모드 카드 전체 |

### Phase 2: Background Gradient Enhancement (3탭 배경)

| File | Change |
|------|--------|
| `Presentation/Dashboard/DashboardView.swift` | gradient opacity 0.03→0.08, 범위 확장, 색상을 AccentColor 기반 warm으로 |
| `Presentation/Activity/ActivityView.swift` | 동일 패턴, Activity 색상 기반 |
| `Presentation/Wellness/WellnessView.swift` | 동일 패턴, Wellness 색상 기반 |

### Phase 3: Card Style Warming (카드 컴포넌트)

| File | Change |
|------|--------|
| `Presentation/Shared/Components/GlassCard.swift` | HeroCard: warm gradient border, glow 강화. StandardCard: warm shadow, subtle border |
| `Presentation/Shared/Components/SectionGroup.swift` | 옵션: warm tint 배경 |
| `Presentation/Shared/DesignSystem.swift` | 새 토큰 추가: `warmGlow`, `cardBorder` |

### Phase 4: Wave Motif (선택적)

| File | Change |
|------|--------|
| `Presentation/Shared/Components/WaveShape.swift` | **새 파일** — 아이콘 파동선 Shape |
| `Presentation/Dashboard/DashboardView.swift` | 배경에 subtle wave overlay |
| `Presentation/Shared/Components/EmptyStateView.swift` | wave 모티프 장식 |

---

## Implementation Steps

### Step 1: Color Palette — Dark Mode Values (핵심)

**목표**: 9개 colorset의 dark mode 값을 warm 스펙트럼으로 조정

**구체적 색상값** (sRGB, dark mode):

| Token | 현재 | 제안 | HSB 참고 |
|-------|------|------|----------|
| MetricHRV | (129,140,248) = 보라 | **(210,170,110)** = 앰버골드 | H35 S48 B82 |
| MetricRHR | (251,113,133) = 핑크 | **(240,130,110)** = 코랄 | H9 S54 B94 |
| MetricHeartRate | (244,102,88) = 레드 | **유지** | — |
| MetricSleep | (167,139,250) = 밝은보라 | **(140,130,210)** = 딥인디고 | H248 S38 B82 |
| MetricActivity | (52,211,153) = 민트그린 | **(110,210,150)** = 따뜻한에메랄드 | H145 S48 B82 |
| MetricSteps | (34,211,238) = 시안 | **(90,200,200)** = 따뜻한틸 | H180 S55 B78 |
| MetricBody | (251,191,36) = 골드 | **유지** | — |
| WellnessVitals | (0,217,208) = 틸 | **(200,175,120)** = 소프트앰버 | H27 S40 B78 |
| WellnessFitness | (64,213,102) = 밝은초록 | **(130,205,110)** = 따뜻한그린 | H107 S46 B80 |

**Light mode 값**: dark 값에서 채도 +10%, 밝기 -15% 정도 조정 (기존 패턴 유지).

**검증**: 시뮬레이터에서 Today/Activity/Wellness 탭 순회하며 가독성 + 구분력 확인.

### Step 2: Surface Colors — Light Mode Warming

**목표**: 라이트 모드 배경을 차가운 연보라에서 따뜻한 크림으로 전환

| Colorset | 현재 Light | 제안 Light |
|----------|-----------|-----------|
| SurfacePrimary | (245,245,250) 연보라 | **(250,248,243)** 웜크림 |
| CardBackground | (255,255,255) 순백 | **(253,251,247)** 아이보리 |

### Step 3: Background Gradient Enhancement

**목표**: 탭별 배경 그라디언트를 인지 가능한 수준으로 강화

현재 패턴:
```swift
LinearGradient(
    colors: [DS.Color.xxx.opacity(0.03), .clear],
    startPoint: .top, endPoint: .center
)
```

변경:
```swift
// DashboardView — 아이콘 골드 warm glow
LinearGradient(
    colors: [Color.accentColor.opacity(0.07), DS.Color.hrv.opacity(0.03), .clear],
    startPoint: .top,
    endPoint: UnitPoint(x: 0.5, y: 0.5)
)

// ActivityView — 따뜻한 에메랄드 glow
LinearGradient(
    colors: [DS.Color.activity.opacity(0.06), .clear],
    startPoint: .top,
    endPoint: UnitPoint(x: 0.5, y: 0.5)
)

// WellnessView — 인디고-앰버 glow
LinearGradient(
    colors: [DS.Color.fitness.opacity(0.06), .clear],
    startPoint: .top,
    endPoint: UnitPoint(x: 0.5, y: 0.5)
)
```

**핵심**: opacity를 0.03→0.06~0.08로 올리되 과하지 않게. endpoint를 center→0.5로 미세 확장.

### Step 4: Card Style — Warm Border & Glow

**목표**: HeroCard와 StandardCard에 프리미엄 따뜻한 디테일 추가

**HeroCard 변경** (`GlassCard.swift`):
```swift
// 기존: tintColor.opacity(0.08) overlay만
// 추가: subtle warm gradient border
.overlay(
    RoundedRectangle(cornerRadius: cornerRadius)
        .strokeBorder(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.15), Color.accentColor.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 0.5
        )
)
```

**StandardCard 변경** (`GlassCard.swift`):
```swift
// 기존: .thinMaterial + shadow
// 추가: dark mode에서 subtle warm border
.overlay(
    RoundedRectangle(cornerRadius: cornerRadius)
        .strokeBorder(
            colorScheme == .dark
                ? Color.accentColor.opacity(0.08)
                : Color.clear,
            lineWidth: 0.5
        )
)
// Shadow 조정
.shadow(
    color: colorScheme == .dark
        ? Color.accentColor.opacity(0.04)  // warm glow (기존: white 0.03)
        : .black.opacity(0.06),            // 유지
    radius: 8, y: 2
)
```

### Step 5: DesignSystem.swift — 새 토큰

```swift
// DS.Color에 추가
static let warmGlow = SwiftUI.Color.accentColor  // border/shadow 참조용 alias
```

### Step 6: Wave Shape (Nice-to-have, MVP 이후)

아이콘의 파동선을 SwiftUI Shape로 구현하여 배경/empty state에 적용.
이 단계는 MVP에서 제외하고, 색상+카드 변경 결과를 보고 결정.

---

## Verification Checklist

### 기능 검증
- [ ] Today 탭: ConditionHeroView 링 색상이 앰버/골드 계열로 표시
- [ ] Today 탭: VitalCard들의 sparkline, icon 색상이 warm 톤
- [ ] Activity 탭: TrainingReadinessHeroCard 서브스코어 바 색상 확인
- [ ] Activity 탭: MuscleRecoveryMap 색상 (FatigueLevel은 별도 — 변경 불필요)
- [ ] Wellness 탭: VitalCard, WellnessHeroCard 서브스코어 바
- [ ] 메트릭 간 색상 구분력: HRV(앰버) vs Body(골드) 충분히 다른지
- [ ] 메트릭 간 색상 구분력: Activity(에메랄드) vs Steps(틸) 충분히 다른지

### 다크/라이트 모드
- [ ] 다크 모드: 아이콘 → 앱 전환 시 시각적 연속성
- [ ] 다크 모드: 카드 border가 은은하게 보이는지 (과하지 않은지)
- [ ] 라이트 모드: 배경이 따뜻한 크림톤인지
- [ ] 라이트 모드: 카드 border가 invisible인지 (다크 전용)

### 차트 가독성
- [ ] MetricDetailView 차트: 새 색상으로 데이터 라인 가독성 유지
- [ ] AreaLineChart: HRV 앰버 gradient가 배경과 충분히 대비
- [ ] DotLineChart: RHR 코랄 dot이 다크 배경에서 명확
- [ ] BarChart: Activity 에메랄드 바가 차트 내에서 명확

### 성능
- [ ] Color asset 변경은 런타임 성능에 영향 없음 (Named Color는 한번 로드)
- [ ] Card border overlay 추가가 스크롤 성능에 영향 없는지 확인
- [ ] Correction #83: Color static caching이 여전히 유효한지 (FatigueLevel은 별도 캐시, 영향 없음)

### 빌드
- [ ] `scripts/build-ios.sh` 통과
- [ ] watchOS 빌드 확인 (색상 토큰 공유 여부)

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| HRV 앰버 vs Body 골드 구분력 부족 | 중 | 중 | HRV는 밝은 앰버, Body는 진한 골드로 명도 차이 확보 |
| 라이트 모드에서 warm 톤이 "누런" 느낌 | 중 | 낮 | SurfacePrimary 채도를 최소로 (거의 흰색에 가까운 warm) |
| 차트 gradient 가독성 저하 | 낮 | 중 | 변경 후 모든 차트 타입 스크린샷 비교 |
| Material backdrop 위에서 border 겹침 | 낮 | 낮 | strokeBorder 0.5pt는 material 위에 자연스러움 |
| watchOS 색상 불일치 | 낮 | 낮 | watchOS는 별도 asset catalog — 이번 스코프 외 |

---

## Alternatives Considered

### A. 색상 유지 + 모티프만 적용
- 장점: 안전, 변경 최소
- 단점: 아이콘-앱 톤 괴리 미해결. 근본 문제 방치

### B. AccentColor만 강조 (기존 팔레트 유지)
- 장점: 메트릭 구분력 유지
- 단점: 보라 HRV가 앱의 주 색상으로 남아 아이콘과 불일치

### C. 전면 warm 전환 (선택)
- 장점: 아이콘과 완전 일체감. 프리미엄 톤 통일
- 단점: 메트릭 구분력 리스크 → warm 스펙트럼 내 분산으로 해결

---

## Dependencies

- 없음 (순수 비주얼 변경, 로직 변경 없음)
- colorset 값 변경은 SwiftData/HealthKit에 영향 없음
- Git: 별도 branch `feature/visual-overhaul` 에서 작업 권장

## Estimated Effort

| Phase | 작업량 | 비고 |
|-------|--------|------|
| Step 1: Color Palette | 30분 | 9개 JSON 파일 값 수정 |
| Step 2: Surface Colors | 10분 | 2개 JSON 파일 값 수정 |
| Step 3: Background Gradient | 20분 | 3개 View 파일 수정 |
| Step 4: Card Style | 30분 | GlassCard.swift 수정 |
| Step 5: DS Token | 5분 | DesignSystem.swift 수정 |
| QA/미세조정 | 30분 | 스크린샷 비교, 색상 조정 |
| **합계** | **~2시간** | Wave는 별도 |
