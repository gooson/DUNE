---
tags: [score-detail, unification, shared-components, canonical-layout, viewmodel-pattern]
date: 2026-03-14
category: solution
status: implemented
---

# Score Detail View Unification

## Problem

3개 스코어 상세 뷰(Condition, Training Readiness, Wellness)가 각각 독립적으로 구현되어 있어:
- 레이아웃 순서, 차트 타입, 서브스코어 배치가 불일치
- 동일 UI 패턴(Summary Stats, Highlights, Composition Card 등)이 중복 구현
- ViewModel이 외부 데이터에 의존하거나, 서브스코어 계산이 인라인으로 중복

## Solution

### 1. Canonical Layout Template

모든 스코어 상세 뷰가 동일한 섹션 순서를 따르도록 통일:

```
Hero → Time-of-Day → Period Picker → Chart Header → DotLineChart
→ Summary Stats → Highlights → Sub-Scores → Component Weights
→ Contributors → Calculation Card → Explainer
```

### 2. Shared Components (7개 추출)

| Component | 역할 |
|-----------|------|
| `ScoreDetailSummaryStats` | Min/Max/Avg + ChangeBadge (sizeClass는 @Environment) |
| `ScoreDetailHighlights` | Best/worst day with icons |
| `ScoreDetailChartHeader` | Visible range label + trend toggle |
| `ScoreDetailEmptyState` | Chart empty state |
| `ScoreCompositionCard` | Component weight breakdown with progress bars |
| `CalculationMethodCard` | Formula explainer (icon + title + bullets) |
| `TimeOfDayCard` | Time-of-day 4 phase chips (init-time pre-compute) |

위치: `DUNE/Presentation/Shared/Components/`

### 3. Self-Contained ViewModel Pattern

각 ViewModel이 자체 HealthKit 서비스를 주입받아 데이터를 독립 페치:

```swift
@Observable @MainActor
final class XxxDetailViewModel {
    // Services injected via init
    private let hrvService: HRVQuerying
    private let sleepService: SleepQuerying  // Wellness only

    // Stored properties (not computed — avoids 60Hz recalc)
    private(set) var trendLineData: [ChartDataPoint]?
    private(set) var scrollDomain: ClosedRange<Date> = Date.now...Date.now

    // Explicit recalculation
    private func recalculateScrollDomain() { ... }
    private func recalculateTrendLine() { ... }
}
```

### 4. HealthDataAggregator Shared Helpers

`buildHRVDailyAverages` / `buildRHRDailyPoints` — 범위 검증(HRV 0-500ms, RHR 20-300bpm) 포함:

```swift
static func buildHRVDailyAverages(from:start:end:calendar:) -> [ChartDataPoint]
static func buildRHRDailyPoints(from:) -> [ChartDataPoint]
```

## Key Decisions

1. **trendLineData/scrollDomain → stored property**: computed property는 body 평가마다 선형회귀/범위 계산을 실행하여 60Hz 성능 문제 유발
2. **TimeOfDayCard init-time compute**: Calendar 연산을 body에서 init으로 이동 (performance-patterns.md 규칙)
3. **ScoreDetailSummaryStats sizeClass → @Environment**: 파라미터 전달 대신 환경값 직접 읽기로 API 단순화
4. **AnyShapeStyle 제거**: ScoreCompositionCard에서 concrete Color 사용 (type erasure 불필요)
5. **Single HRV fetch**: current + previous period를 하나의 fetchHRVSamples로 통합, 날짜로 파티션

## Prevention

- 새 스코어 상세 뷰 추가 시 canonical layout template과 shared components를 재사용
- ViewModel에서 computed property로 expensive 계산을 노출하지 않기 (stored + explicit recalc)
- 서브스코어 일별 계산은 HealthDataAggregator의 shared helpers 사용
