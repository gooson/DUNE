---
topic: wave-motif-visual-enhancement
date: 2026-02-26
status: draft
confidence: high
related_solutions:
  - architecture/2026-02-26-visual-overhaul-warm-tone-alignment
  - performance/2026-02-19-swiftui-color-static-caching
  - general/2026-02-17-chart-ux-layout-stability
related_brainstorms:
  - 2026-02-26-visual-overhaul-icon-alignment
  - 2026-02-25-app-icon-splash-design
---

# Implementation Plan: Wave Motif + Visual Enhancement

## Context

MVP 비주얼 오버홀(색상 팔레트 워밍 + 카드 스타일)이 완료되었다. 앱 아이콘의 핵심 아이덴티티인 **HRV 파동선(wave motif)**을 앱 내부에 반영하여 브랜드 일관성을 강화한다. 동시에 히어로 카드의 비주얼을 업그레이드하고, 디자인 시스템을 문서화하며, watchOS 색상을 동기화한다.

**선행 작업 완료 확인**: Warm tone 팔레트, `DS.Gradient.tabBackgroundEnd` 토큰, `GlassCard` 골드 보더 — 모두 적용 완료 (PR #41).

## Requirements

### Functional

- Wave 모티프를 앱 아이콘의 파동선과 시각적으로 일치시킨다
- Dashboard 배경, EmptyStateView 중 **2곳**에 절제된 wave 적용 (과용 금지 원칙)
- Progress Ring에 앰버-골드 그라디언트 통일
- 점수 숫자에 미세한 골드 그라디언트
- watchOS 색상 팔레트를 iOS와 동기화

### Non-functional

- `Shape.path(in:)` 내 무거운 연산 금지 (Correction #82) — `MuscleBodyShape` 패턴 준수
- Color 인스턴스 hot path 생성 금지 (Correction #83) — static 캐싱
- Dark mode opacity >= 0.06 (Correction #127)
- 반복 UnitPoint/opacity → `DS.Gradient` 토큰 추출 (Correction #128)
- v1(보수적) → v2(강화) 2단계 접근 (Correction #129)
- `accessibilityReduceMotion` 지원 필수

## Approach

**4개 독립 워크스트림**으로 분리하여 각각 독립 커밋 가능하게 구성:

1. **WaveShape 컴포넌트** — 재사용 가능한 SwiftUI Shape
2. **Wave 적용 (2곳)** — Dashboard 배경 + EmptyStateView
3. **히어로 카드 업그레이드** — Progress Ring 그라디언트 + 점수 골드 텍스트
4. **디자인 시스템 정비** — SKILL.md 문서화 + watchOS 색상 동기화

Loading state wave 애니메이션과 Pull-to-refresh 커스텀 indicator는 **이번 스코프에서 제외**한다:
- Loading state: 현재 `.redacted(reason: .placeholder)` 패턴이 충분히 작동하며, 커스텀 wave 애니메이션은 복잡도 대비 사용자 가치가 낮다
- Pull-to-refresh: iOS의 네이티브 `.refreshable` indicator가 사용자 기대에 부합하며, 커스텀 indicator는 유지보수 비용이 높다

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Sine wave (수학 계산) | 파라미터 조절 용이, 코드 간결 | `path(in:)` 내 sin() 호출 (Correction #82 위반 가능) | **채택** — init 시 포인트 사전 계산으로 해결 |
| SVG path 기반 wave | 디자이너 제작 가능, 정밀 제어 | SVG 파싱 오버헤드, 파라미터 변경 어려움 | 미채택 — 아이콘의 wave는 수학적 sine 기반으로 충분 |
| Lottie 애니메이션 | 풍부한 모션, 디자이너 워크플로우 | 외부 의존성 추가, 바이너리 크기 증가 | 미채택 — 의존성 최소화 원칙 |
| Wave를 5곳+ 적용 | 강한 브랜드 존재감 | 과용 → 시각적 피로, TODO 주의사항 위반 | 미채택 — 2곳 제한 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Presentation/Shared/Components/WaveShape.swift` | **New** | Wave SwiftUI Shape 컴포넌트 |
| `Presentation/Shared/DesignSystem.swift` | Modify | Wave 관련 DS.Gradient 토큰 추가 |
| `Presentation/Dashboard/DashboardView.swift` | Modify | 배경에 subtle wave overlay 추가 |
| `Presentation/Shared/Components/EmptyStateView.swift` | Modify | Wave 장식 추가 |
| `Presentation/Shared/Components/ProgressRingView.swift` | Modify | 앰버-골드 그라디언트 옵션 |
| `Presentation/Dashboard/Components/ConditionHeroView.swift` | Modify | 골드 그라디언트 점수 텍스트 |
| `.claude/skills/design-system/SKILL.md` | Modify | DS 문서 완전 정의 |
| `DUNEWatch/Resources/Assets.xcassets/Colors/*.colorset` | Modify | watchOS 색상 동기화 |
| `DUNETests/WaveShapeTests.swift` | **New** | Wave Shape 유닛 테스트 |

## Implementation Steps

### Step 1: WaveShape 컴포넌트 생성

- **Files**: `Presentation/Shared/Components/WaveShape.swift`
- **Changes**:
  - `WaveShape: Shape` 구현
  - `init(amplitude:frequency:phase:verticalOffset:)` — 파라미터로 wave 커스터마이즈
  - init 시점에 normalized 포인트 배열 사전 계산 (`cachedPoints: [(x: CGFloat, y: CGFloat)]`)
  - `path(in:)` 에서는 포인트를 rect 크기로 스케일링만 수행 (Correction #82 준수)
  - `phase` 파라미터로 애니메이션 가능 (TimelineView에서 phase 변경)
  - 기본값: amplitude 0.03 (rect 높이 대비 3%), frequency 2 (2개 파동), verticalOffset 0.7 (하단 30% 위치)

```swift
struct WaveShape: Shape {
    let amplitude: CGFloat   // 0...1 (fraction of height)
    let frequency: CGFloat   // number of full waves
    var phase: CGFloat       // 0...2π, animatable
    let verticalOffset: CGFloat // 0...1 (vertical center of wave)

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    // Pre-computed at init — 60 sample points per wave
    private let sampleCount: Int

    init(amplitude: CGFloat = 0.03, frequency: CGFloat = 2,
         phase: CGFloat = 0, verticalOffset: CGFloat = 0.7) { ... }

    func path(in rect: CGRect) -> Path {
        // Only scaling + Path.addLine — no sin() calls here
    }
}
```

  - `WaveOverlay` convenience View: WaveShape를 `Color.accentColor.opacity(...)` fill로 감싸는 래퍼

- **Verification**: `WaveShapeTests` — path가 rect 범위 내에 있는지, 빈 rect에서 crash 없는지

### Step 2: DS 토큰 확장

- **Files**: `Presentation/Shared/DesignSystem.swift`
- **Changes**:
  - `DS.Gradient` 확장:
    ```swift
    // Wave overlay
    static let waveAmplitude: CGFloat = 0.03
    static let waveFrequency: CGFloat = 2
    static let waveVerticalOffset: CGFloat = 0.7
    // Hero card
    static let heroRingGradientStart = UnitPoint(x: 0, y: 0)
    static let heroRingGradientEnd = UnitPoint(x: 1, y: 1)
    ```
  - `DS.Animation` 확장:
    ```swift
    /// Subtle wave drift (background decoration)
    static let waveDrift = SwiftUI.Animation.linear(duration: 6).repeatForever(autoreverses: false)
    ```

- **Verification**: 빌드 성공 확인

### Step 3: Dashboard 배경 wave overlay (v1 — 보수적)

- **Files**: `Presentation/Dashboard/DashboardView.swift`
- **Changes**:
  - 기존 `LinearGradient` 배경 **아래**에 wave overlay 추가
  - `WaveShape`를 `Color.accentColor.opacity(0.04)` fill (v1 시작값)
  - `accessibilityReduceMotion` 시 phase 고정 (정적 wave)
  - 일반 모드: `TimelineView(.animation)` + phase drift로 느린 파동 효과
  - `.ignoresSafeArea()` + `.allowsHitTesting(false)` 적용

```swift
.background {
    // Existing gradient
    LinearGradient(...)
    // Wave decoration (below gradient, above background color)
    WaveShape(
        amplitude: DS.Gradient.waveAmplitude,
        frequency: DS.Gradient.waveFrequency,
        phase: wavePhase,
        verticalOffset: DS.Gradient.waveVerticalOffset
    )
    .fill(Color.accentColor.opacity(0.04))
    .ignoresSafeArea()
    .allowsHitTesting(false)
}
```

- **Verification**: 시뮬레이터에서 light/dark 모드 확인, wave가 subtle하게 보이는지

### Step 4: EmptyStateView wave 장식

- **Files**: `Presentation/Shared/Components/EmptyStateView.swift`
- **Changes**:
  - VStack 하단에 정적 wave 장식 추가 (애니메이션 없음 — 빈 화면이므로 주의 분산 방지)
  - `WaveShape` 2개 레이어 (amplitude/phase 약간 다르게) → `.quaternary` 스타일과 조화

```swift
// Bottom wave decoration
ZStack {
    WaveShape(amplitude: 0.015, frequency: 1.5, phase: 0, verticalOffset: 0.5)
        .fill(Color.accentColor.opacity(0.06))
    WaveShape(amplitude: 0.02, frequency: 2, phase: .pi / 3, verticalOffset: 0.5)
        .fill(Color.accentColor.opacity(0.03))
}
.frame(height: 60)
.clipped()
```

- **Verification**: EmptyStateView가 사용되는 화면들에서 wave가 적절한지 확인

### Step 5: Progress Ring 앰버-골드 그라디언트

- **Files**: `Presentation/Shared/Components/ProgressRingView.swift`
- **Changes**:
  - `useWarmGradient: Bool = false` 파라미터 추가 (기본 false로 기존 동작 유지)
  - `useWarmGradient == true`일 때 `AngularGradient`를 앰버→골드 기반으로 변경:
    ```swift
    AngularGradient(
        colors: [
            Color.accentColor.opacity(0.6),
            ringColor,
            Color.accentColor.opacity(0.8)
        ],
        center: .center,
        startAngle: .degrees(-90),
        endAngle: .degrees(270)
    )
    ```
  - 그라디언트 색상 배열은 `private enum Cache { static let warmColors = [...] }` (Correction #83)

- **Verification**: ConditionHeroView에서 ring 모양이 의도대로인지 확인

### Step 6: 골드 그라디언트 점수 텍스트

- **Files**: `Presentation/Dashboard/Components/ConditionHeroView.swift`
- **Changes**:
  - 점수 `Text`에 `.foregroundStyle(warmScoreGradient)` 적용
  - `warmScoreGradient`: `LinearGradient(colors: [.accentColor, .accentColor.opacity(0.7)], startPoint: .top, endPoint: .bottom)`
  - 그라디언트는 파일 내 `private enum` static let 으로 캐싱
  - ConditionHeroView에서 `ProgressRingView(progress:ringColor:useWarmGradient: true)` 전달

- **Verification**: 시뮬레이터에서 점수 텍스트의 미세한 골드 톤 확인

### Step 7: 디자인 시스템 문서화

- **Files**: `.claude/skills/design-system/SKILL.md`
- **Changes**:
  - 현재 `[To be defined]` 상태인 모든 섹션을 실제 DS 값으로 채움
  - Colors: 전체 color token 테이블 (Named Color → 용도 → 값)
  - Typography: heroScore, cardScore, sectionTitle
  - Spacing: 4pt grid 전체
  - Radius: sm~xxl
  - Animation: 전체 토큰 + 사용 가이드
  - Gradient: 토큰 + wave 파라미터
  - Components: HeroCard, StandardCard, InlineCard, SectionGroup 사용 가이드

- **Verification**: 문서가 실제 `DesignSystem.swift` 값과 일치하는지 교차 확인

### Step 8: watchOS 색상 동기화

- **Files**: `DUNEWatch/Resources/Assets.xcassets/Colors/*.colorset`
- **Changes**:
  - iOS `DUNE/Resources/Assets.xcassets/Colors/` 의 각 `.colorset/Contents.json` 값을 watchOS 쪽에 복사
  - 변경 대상: MetricHRV, MetricRHR, MetricSleep, MetricActivity, MetricSteps, WellnessVitals, WellnessFitness, SurfacePrimary, AccentColor (warm tone 적용된 값들)
  - watchOS에 없는 colorset이 있으면 생성

- **Verification**: watchOS 빌드 성공 + 시뮬레이터에서 색상 확인

### Step 9: v2 강도 조절 (필요 시)

- **Files**: Step 3, 4, 5, 6의 파일들
- **Changes**:
  - v1 커밋 후 시뮬레이터에서 전체 확인
  - wave opacity, amplitude, ring gradient 강도를 사용자 피드백에 따라 조절
  - Correction #129: v1 확인 후 v2로 강화

- **Verification**: light/dark 모드 모두에서 시각적 밸런스 확인

## Edge Cases

| Case | Handling |
|------|----------|
| `accessibilityReduceMotion` 활성 | wave phase 애니메이션 비활성화, 정적 wave만 표시 |
| 빈 rect (width=0 or height=0) | `guard rect.width > 0, rect.height > 0 else { return Path() }` |
| iPad (regular sizeClass) | wave amplitude는 rect 비율 기반이므로 자동 스케일링 |
| EmptyStateView action 버튼과 wave 겹침 | wave를 VStack 하단 별도 영역에 배치, `.allowsHitTesting(false)` |
| 다크 모드 wave 가시성 | opacity 0.04 기준 시작, Correction #127에 따라 최소 0.06 보장 여부 확인 |
| watchOS에 동일 colorset 부재 | Contents.json 전체 생성 (idiom universal, platform watchos) |

## Testing Strategy

- **Unit tests**:
  - `WaveShapeTests.swift`: path가 rect 범위 내, 빈 rect 방어, animatableData 동작
  - 기존 `DesignSystemTests`(존재 시): 새 토큰 접근 검증
- **Manual verification**:
  - iPhone 시뮬레이터: light + dark 모드에서 Dashboard wave 확인
  - iPad 시뮬레이터: sizeClass에 따른 wave 스케일링
  - EmptyState 화면 진입하여 wave 장식 확인
  - ConditionHeroView 점수 + ring 골드 그라디언트 확인
  - watchOS 시뮬레이터: 색상 동기화 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Wave 애니메이션이 성능에 영향 | Low | Medium | `TimelineView(.animation)` + phase만 변경, path 재계산 없음. reduceMotion 지원 |
| Wave가 너무 눈에 띄어 산만함 | Medium | Low | v1 opacity 0.04로 시작, 피드백 후 조절 (Correction #129) |
| watchOS colorset 포맷 오류 | Low | Medium | Correction #124~#125 준수 (platform 소문자, idiom universal) |
| ProgressRing warm gradient가 기존 status 색상과 충돌 | Low | Low | `useWarmGradient`는 ConditionHeroView만 true, 나머지는 기존 동작 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: MuscleBodyShape라는 검증된 Shape 패턴이 이미 존재하고, DS 토큰 시스템이 잘 갖춰져 있어 확장이 자연스럽다. Wave 적용 범위를 2곳으로 제한하여 리스크가 낮다. watchOS 색상 동기화는 단순 JSON 값 복사이며, Correction #124~#125로 포맷 규칙이 명확하다.
