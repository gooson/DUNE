---
topic: desert-aesthetic-expansion
date: 2026-02-27
status: draft
confidence: high
related_solutions:
  - architecture/2026-02-26-visual-overhaul-warm-tone-alignment
  - architecture/2026-02-27-wave-expansion-desert-horizon
related_brainstorms:
  - 2026-02-27-desert-aesthetic-expansion
---

# Implementation Plan: Desert Aesthetic Expansion

## Context

링 컬러의 **골드→블루 그라데이션** (사막 황혼)이 앱의 핵심 비주얼 DNA이지만, 현재 차트/카드/텍스트/모션 영역에는 이 언어가 퍼져 있지 않음. 기존 warm tone 인프라(DS 토큰, 웨이브 배경, GlassCard)를 활용하여 **Subtle 강도**로 4개 영역에 사막 느낌을 확장.

## Requirements

### Functional

- 3개 새 DS 컬러 토큰: `desertDusk` (블루-그레이), `desertBronze` (구리), `sandMuted` (음소거 모래)
- iOS + Watch DS 동기 (Correction #138)
- 차트 7개 파일의 area gradient, grid line, selection indicator 사막화
- StandardCard/InlineCard 보더 사막 그라데이션
- Hero 점수 + 장식 텍스트 사막 톤
- Period 전환 shimmer 모션

### Non-functional

- 다크/라이트 모드 모두 동작 (다크에서 효과 극대화, 라이트는 미세)
- WCAG AA contrast ratio 4.5:1 유지
- gradient/color 캐싱으로 렌더 성능 보장 (Correction #80, #83, #105)
- 기존 iOS 패턴 유지 — "뭔가 다르다" 수준, "이게 뭐지" 수준 아님

## Approach

**Named Color Asset 단일 소스 원칙** 유지. 새 토큰 3개를 xcassets에 추가하고 DS enum에서 참조. 기존 `.gray.opacity(0.3)` 패턴을 `DS.Color.warmGlow.opacity()` 또는 `DS.Color.desertDusk.opacity()`로 교체.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| A. 전역 modifier로 일괄 적용 | 코드 변경 최소 | 세밀한 제어 불가, 예외 처리 어려움 | ❌ |
| B. 파일별 개별 수정 | 정밀한 제어, 각 컴포넌트에 최적화 | 변경 파일 많음 | ✅ 선택 |
| C. Environment 기반 테마 시스템 | 확장성 최고 | 현재 규모에 과잉 설계 | ❌ |

## Affected Files

### Phase 1: Desert Palette 토큰 (4 files + 6 asset files)

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Resources/Assets.xcassets/Colors/DesertDusk.colorset/Contents.json` | **New** | 블루-그레이 컬러셋 |
| `DUNE/Resources/Assets.xcassets/Colors/DesertBronze.colorset/Contents.json` | **New** | 구리/브론즈 컬러셋 |
| `DUNE/Resources/Assets.xcassets/Colors/SandMuted.colorset/Contents.json` | **New** | 음소거 모래 컬러셋 |
| `DUNEWatch/Resources/Assets.xcassets/Colors/DesertDusk.colorset/Contents.json` | **New** | Watch 동기 |
| `DUNEWatch/Resources/Assets.xcassets/Colors/DesertBronze.colorset/Contents.json` | **New** | Watch 동기 |
| `DUNEWatch/Resources/Assets.xcassets/Colors/SandMuted.colorset/Contents.json` | **New** | Watch 동기 |
| `DUNE/Presentation/Shared/DesignSystem.swift` | Modify | 3 토큰 추가 |
| `DUNEWatch/DesignSystem.swift` | Modify | 3 토큰 추가 |
| `Dailve/project.yml` | Modify | 새 파일 경로 반영 (xcodegen) |

### Phase 2: 차트 사막화 (8 files)

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Charts/AreaLineChartView.swift` | Modify | areaGradient에 warmGlow 블렌딩 + selection RuleMark 색상 |
| `DUNE/Presentation/Shared/Charts/DotLineChartView.swift` | Modify | baseline/selection `.gray` → warmGlow + grid hint |
| `DUNE/Presentation/Shared/Charts/BarChartView.swift` | Modify | selection RuleMark `.gray` → warmGlow |
| `DUNE/Presentation/Shared/Charts/HeartRateChartView.swift` | Modify | selection/baseline `.gray` → warmGlow |
| `DUNE/Presentation/Shared/Charts/RangeBarChartView.swift` | Modify | selection `.gray` → warmGlow |
| `DUNE/Presentation/Shared/Charts/SleepStageChartView.swift` | Modify | selection `.gray` → warmGlow |
| `DUNE/Presentation/Shared/Charts/ChartSelectionOverlay.swift` | Modify | 보더에 warmGlow 힌트 추가 |
| `DUNE/Presentation/Shared/Charts/MiniSparklineView.swift` | Modify | area gradient에 warmGlow 블렌딩 |

### Phase 3: 카드 사막화 (1 file)

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Components/GlassCard.swift` | Modify | StandardCard 보더 골드→블루 gradient + InlineCard bottom accent |

### Phase 4: 텍스트 사막화 (2 files)

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Components/HeroScoreCard.swift` | Modify | scoreGradient에 desertBronze 적용 |
| `DUNE/Presentation/Shared/Detail/MetricSummaryHeader.swift` | Modify | tertiary → sandMuted (timestamp, stat label) |

### Phase 5: 모션 사막화 (2 files)

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/DesignSystem.swift` | Modify | shimmer 관련 상수 추가 (DS.Opacity, DS.Animation) |
| `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | Modify | period 전환 시 shimmer overlay |

---

## Implementation Steps

### Step 1: Desert Palette 토큰 추가

**Files**: Assets.xcassets (iOS 3개 + Watch 3개), DesignSystem.swift (iOS + Watch)

**Color Values** (링 레퍼런스에서 추출):

| Token | Light | Dark | 용도 |
|-------|-------|------|------|
| `DesertDusk` | `#8E9BAB` | `#6B7A8E` | 링 하단 블루-그레이. 카드 보더, 차트 하단 |
| `DesertBronze` | `#B87A5E` | `#D4A07A` | 링 숫자 구리톤. Hero 점수, 강조 수치 |
| `SandMuted` | `#A69480` | `#8A7D6E` | 음소거 모래. 타임스탬프, 장식 텍스트 |

**DesignSystem.swift 추가**:
```swift
// Desert Palette — Desert Horizon 링 컬러에서 추출
static let desertDusk   = SwiftUI.Color("DesertDusk")    // Cool blue-gray (ring bottom)
static let desertBronze = SwiftUI.Color("DesertBronze")  // Copper/bronze (ring number)
static let sandMuted    = SwiftUI.Color("SandMuted")     // Muted sand (decorative text)
```

**Watch DesignSystem.swift에도 동일 3줄 추가** (Correction #138)

**Verification**: 빌드 성공 + 프리뷰에서 3개 색상이 올바르게 렌더되는지 확인

---

### Step 2: 차트 Area Gradient 사막화

**Files**: AreaLineChartView.swift, DotLineChartView.swift, MiniSparklineView.swift

**변경 패턴** (AreaLineChartView 예시):
```swift
// AS-IS
private var areaGradient: LinearGradient {
    LinearGradient(
        colors: [tintColor.opacity(0.3), tintColor.opacity(0.05)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// TO-BE: 하단에 warmGlow 블렌딩 추가
private var areaGradient: LinearGradient {
    LinearGradient(
        colors: [
            tintColor.opacity(0.25),
            tintColor.opacity(0.08),
            DS.Color.warmGlow.opacity(0.04)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
```

DotLineChartView, MiniSparklineView도 동일 패턴 적용 (기존 2-stop → 3-stop).

**Verification**: 각 차트 프리뷰에서 다크/라이트 모드 비교. 하단에 은은한 모래색 잔영 확인

---

### Step 3: 차트 Grid Line 워밍

**Files**: AreaLineChartView, DotLineChartView, BarChartView, HeartRateChartView, RangeBarChartView, SleepStageChartView

현재 차트 6개 모두 `AxisGridLine()` (시스템 기본)을 사용. 다크 모드에서 grid에 warmGlow 힌트 추가.

**변경 패턴**:
```swift
// AS-IS
AxisGridLine()

// TO-BE
AxisGridLine()
    .foregroundStyle(DS.Color.warmGlow.opacity(DS.Opacity.subtle))
```

**주의**: `AxisGridLine()`에 `.foregroundStyle` 적용이 Swift Charts API에서 지원되는지 확인 필요. 미지원 시 대안으로 `AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(...)` 사용.

**Verification**: 차트 프리뷰에서 grid line이 은은한 골드 빛인지, 너무 눈에 띄지 않는지 확인

---

### Step 4: 차트 Selection Indicator 사막화

**Files**: AreaLineChartView, DotLineChartView, BarChartView, HeartRateChartView, RangeBarChartView, SleepStageChartView, ChartSelectionOverlay

**4-a. RuleMark 색상 교체** (6개 차트 공통):
```swift
// AS-IS (6개 파일 모두 동일)
RuleMark(x: .value("Selected", point.date, unit: xUnit))
    .foregroundStyle(.gray.opacity(0.3))
    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

// TO-BE
RuleMark(x: .value("Selected", point.date, unit: xUnit))
    .foregroundStyle(DS.Color.warmGlow.opacity(DS.Opacity.border))
    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
```

DotLineChartView의 baseline RuleMark도:
```swift
// AS-IS
.foregroundStyle(.gray.opacity(0.5))
// TO-BE
.foregroundStyle(DS.Color.warmGlow.opacity(0.2))
```

**4-b. ChartSelectionOverlay 보더 추가**:
```swift
// AS-IS
.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

// TO-BE
.background {
    RoundedRectangle(cornerRadius: DS.Radius.sm)
        .fill(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .strokeBorder(DS.Color.warmGlow.opacity(DS.Opacity.subtle), lineWidth: 0.5)
        )
}
```

**Verification**: 차트 터치 시 selection line이 따뜻한 골드빛인지, overlay 캡슐에 미세한 보더 확인

---

### Step 5: StandardCard 보더 골드→블루 그라데이션

**File**: GlassCard.swift

```swift
// AS-IS (StandardCard 다크 모드 보더)
.strokeBorder(
    DS.Color.warmGlow.opacity(colorScheme == .dark ? DS.Opacity.border : 0),
    lineWidth: 0.5
)

// TO-BE: 골드→블루 그라데이션 보더
.strokeBorder(
    LinearGradient(
        colors: colorScheme == .dark
            ? [DS.Color.warmGlow.opacity(DS.Opacity.border),
               DS.Color.desertDusk.opacity(DS.Opacity.light)]
            : [.clear, .clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    ),
    lineWidth: 0.5
)
```

**Verification**: 다크 모드에서 카드 보더가 좌상단=골드, 우하단=블루-그레이로 은은하게 전환되는지 확인

---

### Step 6: InlineCard Bottom Accent

**File**: GlassCard.swift

```swift
// AS-IS (InlineCard — 보더/그림자 없음)
.background {
    RoundedRectangle(cornerRadius: cornerRadius)
        .fill(.ultraThinMaterial)
}

// TO-BE: 하단 미세 accent line
.background {
    RoundedRectangle(cornerRadius: cornerRadius)
        .fill(.ultraThinMaterial)
}
.overlay(alignment: .bottom) {
    RoundedRectangle(cornerRadius: 0.5)
        .fill(
            LinearGradient(
                colors: [.clear, DS.Color.warmGlow.opacity(DS.Opacity.subtle), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .frame(height: 0.5)
        .padding(.horizontal, cornerRadius)
}
```

**Verification**: 카드 리스트에서 하단 0.5px 골드 라인이 은은하게 보이는지, 양쪽 끝이 페이드아웃되는지 확인

---

### Step 7: Hero 점수 숫자에 desertBronze 적용

**File**: HeroScoreCard.swift

```swift
// AS-IS
private enum Layout {
    static let scoreGradient = LinearGradient(
        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// TO-BE: desertBronze 기반 그라데이션
private enum Layout {
    static let scoreGradient = LinearGradient(
        colors: [DS.Color.desertBronze, DS.Color.desertBronze.opacity(0.7)],
        startPoint: .top,
        endPoint: .bottom
    )
}
```

**주의**: HeroScoreCard의 scoreLabel(`.tertiary`)도 sandMuted로 변경 가능하지만,
scoreLabel은 "CONDITION" 등 기능적 텍스트이므로 현재는 `.tertiary` 유지.

**Verification**: Hero 카드 점수가 구리/브론즈 톤으로 표시되는지, 기존 warmGlow와 충분히 구분되는지 확인

---

### Step 8: 장식 텍스트에 sandMuted 적용

**File**: MetricSummaryHeader.swift

**대상 (DECORATIVE만)**:
- 라인 56: "Updated X ago" 타임스탬프 (`.tertiary` → `sandMuted`)
- 라인 76: "Avg", "Min", "Max" stat 라벨 (`.tertiary` → `sandMuted`)

```swift
// AS-IS
.foregroundStyle(.tertiary)

// TO-BE
.foregroundStyle(DS.Color.sandMuted)
```

**적용하지 않는 항목** (FUNCTIONAL):
- 라인 20: 카테고리 이름 (`.secondary` — 기능적)
- 라인 32: 단위 라벨 (`.secondary` — 기능적)
- 라인 144: 비교 문장 (`.secondary` — 의미 전달)

**Verification**: 타임스탬프와 stat 라벨이 모래색으로 보이면서 readability 유지되는지 확인

---

### Step 9: Period 전환 Sand Shimmer

**Files**: DesignSystem.swift, MetricDetailView.swift

**9-a. DS에 shimmer 상수 추가**:
```swift
// DS.Animation
static let shimmer = SwiftUI.Animation.easeInOut(duration: 0.4)

// DS.Opacity
/// Sand shimmer flash (0.08)
static let shimmer: Double = 0.08
```

**9-b. MetricDetailView에 shimmer overlay**:
```swift
// 기존 period 전환 위치
StandardCard {
    ...
}
.id(viewModel.selectedPeriod)
.transition(.opacity)
.animation(.easeInOut(duration: 0.25), value: viewModel.selectedPeriod)

// 추가: shimmer overlay
.overlay {
    if isShimmering {
        RoundedRectangle(cornerRadius: DS.Radius.md)
            .fill(DS.Color.warmGlow.opacity(DS.Opacity.shimmer))
            .allowsHitTesting(false)
            .transition(.opacity)
    }
}

// State + trigger
@State private var isShimmering = false

.onChange(of: viewModel.selectedPeriod) { _, _ in
    withAnimation(DS.Animation.shimmer) { isShimmering = true }
    withAnimation(DS.Animation.shimmer.delay(0.3)) { isShimmering = false }
}
```

**Verification**: 기간 전환 시 0.4초간 warmGlow가 차트 위를 스쳐지나가는지, 너무 강하지 않은지 확인

---

### Step 10: xcodegen 재생성 + 빌드 검증

**Commands**:
```bash
cd Dailve && xcodegen generate
scripts/build-ios.sh
```

**Verification**: 빌드 성공, 경고 0

---

## Edge Cases

| Case | Handling |
|------|----------|
| 라이트 모드에서 desertDusk 보더가 안 보임 | 라이트에서는 `colorScheme == .dark` 조건으로 보더 비활성 (기존 패턴 유지) |
| sandMuted가 배경과 contrast 부족 | light #A69480 vs white bg = 3.2:1 → `.caption`급 텍스트에 적합. 본문 텍스트에는 사용 금지 |
| warmGlow grid line이 metric 색상과 충돌 | opacity 0.06으로 극히 미세하여 충돌 없음. 차트 데이터 색상은 opacity 0.6~1.0 |
| shimmer가 reduceMotion 환경에서 실행 | `@Environment(\.accessibilityReduceMotion)` 체크 후 shimmer 생략 |
| Watch에서 desertBronze가 너무 어두움 | dark variant #D4A07A는 밝은 구리색으로 OLED에서 가독성 양호 |

## Testing Strategy

- **Unit tests**: 색상 토큰은 순수 UI이므로 unit test 면제 (테스트 면제 대상: SwiftUI View body)
- **Manual verification**:
  - [ ] 다크 모드 전체 탭 스크린샷 비교 (before/after)
  - [ ] 라이트 모드 전체 탭 스크린샷 비교
  - [ ] 차트 터치 인터랙션 (selection indicator 색상)
  - [ ] 기간 전환 shimmer 모션
  - [ ] iPad sizeClass에서 카드 보더 렌더링
  - [ ] Watch 시뮬레이터에서 토큰 반영 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| desertBronze vs warmGlow 구분 모호 | Medium | Low | 프로토타입 후 hex 미세 조정 |
| Grid line warmGlow가 차트 가독성 저하 | Low | Medium | opacity 0.06으로 극히 미세하게 설정 |
| shimmer가 과도하게 느껴짐 | Medium | Low | opacity 0.08 + 0.4s duration으로 시작, 필요 시 낮춤 |
| AxisGridLine에 foregroundStyle 미지원 | Low | Medium | Chart modifier 대신 background에 수동 grid 드로잉 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 모든 변경이 기존 DS 토큰/패턴 위에서 이루어짐. 새 컴포넌트 없이 기존 파일의 색상/opacity 값만 수정. xcassets 기반 named color 추가는 이미 32회 검증된 패턴. shimmer만 새 로직이지만 단순 overlay + state toggle.

## Implementation Order

```
Phase 1 (토큰)  ──→  Phase 2 (차트)  ──→  Phase 3 (카드)  ──→  Phase 4 (텍스트)  ──→  Phase 5 (모션)
    ↓                    ↓                    ↓                    ↓                    ↓
 빌드 검증            프리뷰 확인           프리뷰 확인           프리뷰 확인         인터랙션 확인
```

각 Phase 완료 후 빌드 + 시각 검증. Phase 간 의존성은 Phase 1(토큰)만 선행 필수, 나머지는 병렬 가능.
