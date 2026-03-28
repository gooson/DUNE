---
topic: rich-animation-enhancement
date: 2026-03-28
status: draft
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-13-dashboard-smooth-transitions.md
  - docs/solutions/architecture/2026-03-09-muscle-map-volume-scale-animation.md
related_brainstorms:
  - docs/brainstorms/2026-03-28-rich-animation-enhancement.md
---

# Implementation Plan: Rich Animation Enhancement (All Tabs)

## Context

현재 앱의 애니메이션은 Dashboard의 insight cards stagger와 HeroScoreCard counter를 제외하면 대부분 기본 수준. Activity, Wellness, Life 탭은 데이터 등장 애니메이션이 전혀 없고, 인터랙션 피드백(press scale, haptic)도 없음. Rich 수준의 모션 디자인으로 전체 앱을 업그레이드하여 프리미엄 시각 경험 제공.

## Requirements

### Functional

- 모든 탭의 카드/섹션에 stagger 등장 애니메이션 적용
- 점수 카운터에 glow pulse 효과 추가
- 탭 가능한 카드에 press scale + haptic 피드백
- 차트에 draw animation (왼→오 시간순)
- Detail views의 hero score에 ring entrance animation

### Non-functional

- `reduceMotion` 접근성 100% 대응
- 스크롤 60fps 유지 (stagger는 visible items만)
- 기존 Wave Background, ChartSelectionOverlay와 충돌 없음
- DS.Animation 기존 프리셋 하위호환

## Approach

**ViewModifier 중심 접근**: 공통 ViewModifier 3종을 만들고 각 탭의 카드/섹션에 일괄 적용. 기존 DashboardView의 inline stagger 패턴을 범용 modifier로 승격.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| ViewModifier 중심 | DRY, 일관성, 재사용 | modifier 조합 복잡성 | **선택** |
| 각 View 개별 구현 | View별 커스텀 가능 | 중복, 유지보수 어려움 | 기각 |
| AnimationCoordinator 객체 | 중앙 관리 | 과잉 설계, 상태 관리 복잡 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Presentation/Shared/DesignSystem.swift` | Modify | Rich 프리셋 추가 |
| `Presentation/Shared/ViewModifiers/StaggeredAppearModifier.swift` | **New** | stagger 등장 modifier |
| `Presentation/Shared/ViewModifiers/PressableModifier.swift` | **New** | press scale + haptic modifier |
| `Presentation/Shared/ViewModifiers/ChartDrawModifier.swift` | **New** | 차트 draw animation modifier |
| `Presentation/Shared/Components/HeroScoreCard.swift` | Modify | glow pulse 추가 |
| `Presentation/Shared/Components/ProgressRingView.swift` | Modify | trailing glow 추가 |
| `Presentation/Dashboard/DashboardView.swift` | Modify | stagger modifier 적용, inline 코드 제거 |
| `Presentation/Dashboard/Components/InsightCardView.swift` | Modify | pressable 적용 |
| `Presentation/Activity/ActivityView.swift` | Modify | stagger + pressable 적용 |
| `Presentation/Wellness/WellnessView.swift` | Modify | stagger + pressable 적용 |
| `Presentation/Life/LifeView.swift` | Modify | stagger + pressable 적용 |
| `Presentation/Shared/Charts/BarChartView.swift` | Modify | draw animation |
| `Presentation/Shared/Charts/AreaLineChartView.swift` | Modify | draw animation |
| `Presentation/Shared/Charts/DotLineChartView.swift` | Modify | draw animation |
| `Presentation/Shared/Detail/MetricDetailView.swift` | Modify | hero entrance + chart draw |
| Detail views (Condition, Wellness, Training, etc.) | Modify | stagger + hero entrance |

## Implementation Steps

### Step 1: DS.Animation Rich 프리셋 추가

- **Files**: `Presentation/Shared/DesignSystem.swift`
- **Changes**:
  ```swift
  // DS.Animation 내 추가
  static let cardEntrance = SwiftUI.Animation.spring(duration: 0.5, bounce: 0.15)
  static let pressDown = SwiftUI.Animation.spring(duration: 0.2, bounce: 0.0)
  static let pressUp = SwiftUI.Animation.spring(duration: 0.4, bounce: 0.15)
  static let chartDraw = SwiftUI.Animation.easeOut(duration: 0.8)

  static func staggerDelay(index: Int, base: Double = 0.06, max: Int = 8) -> Double {
      Double(min(index, max)) * base
  }
  ```
- **Verification**: 빌드 성공

### Step 2: StaggeredAppearModifier 생성

- **Files**: `Presentation/Shared/ViewModifiers/StaggeredAppearModifier.swift` (new)
- **Changes**:
  - `@State private var hasAppeared = false`
  - slide-up(12pt) + fade + scale(0.97)
  - spring(0.5, bounce: 0.15) + stagger delay
  - `reduceMotion` → 즉시 표시
  - `View.staggeredAppear(index:)` extension
- **Verification**: Preview에서 stagger 동작 확인

### Step 3: PressableModifier 생성

- **Files**: `Presentation/Shared/ViewModifiers/PressableModifier.swift` (new)
- **Changes**:
  - `ButtonStyle` 기반 (contentShape 포함)
  - press: scale(0.97) + shadow 축소 + haptic `.light`
  - release: spring(0.4, bounce: 0.15)
  - `reduceMotion` → scale만 적용, haptic은 유지
  - `View.pressableCard(action:)` extension
- **Verification**: 카드 탭 시 scale + haptic 동작

### Step 4: ChartDrawModifier 생성

- **Files**: `Presentation/Shared/ViewModifiers/ChartDrawModifier.swift` (new)
- **Changes**:
  - `@State private var drawProgress: CGFloat = 0`
  - `.chartXScale(domain:)` 또는 `.mask` 기반 left-to-right reveal
  - easeOut(0.8) + appear 트리거
  - `reduceMotion` → 즉시 표시
  - `View.chartDrawAnimation()` extension
- **Verification**: 차트가 왼→오로 그려지는 애니메이션

### Step 5: HeroScoreCard glow pulse 추가

- **Files**: `Presentation/Shared/Components/HeroScoreCard.swift`
- **Changes**:
  - 카운터 완료 시 ring에 glow pulse (shadow + opacity animation)
  - 1회 pulse 후 정지 (infinite 아님)
  - `reduceMotion` 대응
- **Verification**: 점수 카운트 종료 후 ring glow 1회

### Step 6: Dashboard stagger 마이그레이션

- **Files**: `Presentation/Dashboard/DashboardView.swift`
- **Changes**:
  - insightCardsSection의 inline stagger 코드를 `StaggeredAppearModifier` 사용으로 교체
  - hero 카드, 코칭 카드, 날씨 카드, pinned 섹션에도 stagger 적용
  - 기존 `sectionTransition` + `sectionVisibilityHash` 패턴은 유지 (공존)
- **Verification**: Dashboard 섹션들이 순차 등장

### Step 7: Activity 탭 stagger + pressable 적용

- **Files**: `Presentation/Activity/ActivityView.swift`
- **Changes**:
  - hero card, weekly stats, muscle map, volume, workout list 등 각 섹션에 `.staggeredAppear(index:)`
  - NavigationLink 카드에 `.pressableCard` 적용
  - 기존 `sectionTransition` 없으면 추가
- **Verification**: Activity 탭 스크롤 시 섹션 순차 등장 + 카드 press 피드백

### Step 8: Wellness 탭 stagger + pressable 적용

- **Files**: `Presentation/Wellness/WellnessView.swift`
- **Changes**:
  - hero card, vital cards, sleep section, body composition 등에 stagger 적용
  - 카드 press 피드백 적용
- **Verification**: Wellness 탭 섹션 순차 등장

### Step 9: Life 탭 stagger + pressable 적용

- **Files**: `Presentation/Life/LifeView.swift`
- **Changes**:
  - habit rows, completion chart, heatmap 등에 stagger
  - habit 체크 시 scale bounce (기존 toggle에 animation 추가)
- **Verification**: Life 탭 habit rows 순차 등장

### Step 10: 차트 draw animation 적용

- **Files**: `BarChartView.swift`, `AreaLineChartView.swift`, `DotLineChartView.swift`
- **Changes**:
  - 각 차트에 `.chartDrawAnimation()` 적용
  - bar chart: `.mask(alignment: .leading)` + width animation
  - line chart: `.trim(from:to:)` 또는 mask 기반
- **Verification**: 차트가 왼→오로 드로잉

### Step 11: Detail views stagger + hero entrance

- **Files**: 각 detail view (ConditionScoreDetailView, WellnessScoreDetailView, TrainingReadinessDetailView 등)
- **Changes**:
  - hero score 영역에 ring entrance + counter drama
  - 하위 섹션에 stagger
  - summary stats에 stagger
- **Verification**: detail 화면 진입 시 순차 등장

### Step 12: 최종 정리 + 빌드 검증

- **Files**: 전체
- **Changes**:
  - 디버그 코드 제거
  - reduceMotion 일관성 검증
  - stagger index 순서 최종 확인
- **Verification**: `scripts/build-ios.sh` 통과

## Edge Cases

| Case | Handling |
|------|----------|
| reduceMotion=true | 모든 Rich 효과 즉시 완료, haptic은 유지 |
| 빠른 탭 전환 | onAppear 재트리거로 자연스럽게 재생 |
| Background→Foreground | 이미 appeared 상태이므로 re-animate 안함 |
| 대량 카드 (10+) | stagger max index=8, 이후는 동시 표시 |
| iPad Split View | stagger는 동일 (index 기반이므로 레이아웃 무관) |
| 스크롤 중 데이터 로드 | onAppear 기반이므로 화면 진입 시에만 트리거 |
| 빈 상태 (데이터 없음) | EmptyStateView에도 fade-in 적용 |

## Testing Strategy

- **Unit tests**: DS.Animation.staggerDelay 함수 테스트 (index, base, max 조합)
- **Manual verification**:
  - 4개 탭 각각 첫 진입 시 stagger 동작 확인
  - 카드 press 시 scale + haptic 확인
  - 차트 draw animation 확인
  - Settings > Accessibility > Reduce Motion ON 시 즉시 표시 확인
  - 스크롤 성능 60fps 확인 (Instruments)
- **UI tests**: 기존 UI 테스트 회귀 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 스크롤 성능 저하 | Low | Medium | stagger는 onAppear 기반, 화면 밖 요소 불필요 |
| 기존 transition과 충돌 | Low | Low | stagger는 opacity+offset, sectionTransition은 유지 |
| pressable과 NavigationLink 충돌 | Medium | Medium | ButtonStyle 기반으로 NavigationLink과 분리 |
| ChartSelectionOverlay 제스처 충돌 | Low | High | pressable은 카드 레벨, chart interaction은 차트 레벨 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 DashboardView에 동일 패턴이 이미 구현되어 있고, 이를 범용 modifier로 추출하여 나머지 탭에 적용하는 구조. 기술적 불확실성 낮음.
