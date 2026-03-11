---
tags: [swift-charts, metric-detail, hrv, rhr, scroll-domain, visible-range]
category: architecture
date: 2026-03-11
severity: important
related_files:
  - DUNE/Presentation/Shared/Detail/MetricDetailView.swift
  - DUNE/Presentation/Shared/Extensions/TimePeriod+View.swift
  - DUNETests/MetricDetailViewModelTests.swift
  - DUNETests/TimePeriodTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-08-chart-scroll-unified-vitals.md
  - docs/solutions/architecture/2026-03-08-chart-scroll-domain-sparse-data.md
---

# Solution: Metric Detail Weekly Chart Current Day Alignment

## Problem

HRV 상세의 주간 차트가 오늘 데이터가 아직 없을 때 현재 주간 window를 유지하지 못하고, 마지막 실제 데이터가 있는 전날까지로 밀려 보였다. 같은 화면의 visible range 헤더는 배타 종료일을 그대로 표시해 하루 큰 날짜가 노출될 수 있었다.

### Symptoms

- 수요일인데 HRV 주간 차트의 마지막 x축 레이블이 화요일까지만 보임
- visible range 헤더가 실제 보이는 일수보다 하루 뒤 날짜까지 표시될 수 있음
- HRV/RHR는 vitals와 달리 sparse-data domain 보정이 빠져 있어 상세 화면 간 동작이 일관되지 않음

### Root Cause

1. `MetricDetailView`에서 HRV/RHR chart path만 `scrollDomain`을 넘기지 않아, Swift Charts가 실제 데이터 포인트 범위로 x-domain을 자동 계산했다.
2. 오늘 샘플이 없으면 domain upper bound가 전날에서 끊기고, visible window도 전날 기준으로 clamp되었다.
3. `visibleRangeLabel(from:)`는 visible window의 종료 시점을 배타 경계 그대로 포맷해, 마지막 보이는 날짜 대신 다음 날짜를 표시할 수 있었다.

## Solution

기존 vitals/body-composition 상세 화면에 이미 적용된 패턴을 HRV/RHR에도 동일하게 적용했다. 차트에는 explicit `scrollDomain`을 전달해 현재 기간 끝까지 domain을 열어두고, 헤더는 `endExclusive - 1 second`를 포맷해 마지막 visible day를 표시하도록 맞췄다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | HRV/RHR chart constructors에 `scrollDomain: viewModel.scrollDomain` 추가 | sparse daily vitals도 현재 기간 끝까지 x-domain 유지 |
| `DUNE/Presentation/Shared/Extensions/TimePeriod+View.swift` | visible range label이 `displayEnd`를 사용하도록 수정 | 배타 종료 경계 off-by-one 제거 |
| `DUNETests/TimePeriodTests.swift` | week visible range inclusive-end regression test 추가 | 주간 헤더 날짜 회귀 방지 |
| `DUNETests/MetricDetailViewModelTests.swift` | ViewModel visibleRangeLabel regression test 추가 | 실제 상세 화면이 쓰는 경로 보호 |

### Key Code

```swift
DotLineChartView(
    data: viewModel.chartData,
    baseline: nil,
    yAxisLabel: "ms",
    timePeriod: viewModel.selectedPeriod,
    tintColor: DS.Color.hrv,
    trendLine: trend,
    scrollDomain: viewModel.scrollDomain,
    scrollPosition: $viewModel.scrollPosition
)

let displayEnd = calendar.date(byAdding: .second, value: -1, to: endExclusive) ?? scrollDate
return "\(formatter.string(from: scrollDate)) – \(formatter.string(from: displayEnd))"
```

## Prevention

### Checklist Addition

- [ ] metric detail에 새 line/range chart를 붙일 때 `scrollDomain`이 연결되어 있는지 확인한다
- [ ] visible-range 헤더를 만들 때는 배타 종료 경계가 아니라 마지막 visible instant를 포맷한다
- [ ] “오늘 데이터가 없을 때도 오늘 축이 보여야 하는가”를 sparse-data chart 리뷰 체크포인트에 포함한다

### Rule Addition (if applicable)

기존 chart scroll solution 문서군으로 충분해 새 전역 rule 추가는 필요하지 않았다. 다만 metric detail chart 리뷰 시 `scrollDomain` 누락 여부를 반드시 같이 확인한다.

## Lessons Learned

- 같은 chart component를 써도 화면별로 `scrollDomain` 전달 여부가 다르면 “오늘 축 누락” 같은 미묘한 회귀가 남을 수 있다.
- 날짜 range 헤더는 데이터 domain과 별개로, 배타/포함 경계를 명시적으로 정리하지 않으면 하루 차이 UI 버그가 쉽게 생긴다.
- sparse metric chart는 “데이터가 없는 오늘”을 정상 상태로 보고 domain과 label을 설계해야 한다.
