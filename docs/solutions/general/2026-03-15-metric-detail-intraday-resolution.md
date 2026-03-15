---
tags: [healthkit, intraday, chart, heart-rate, body-composition, aggregation]
category: general
date: 2026-03-15
severity: important
related_files:
  - DUNE/Data/HealthKit/HeartRateQueryService.swift
  - DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift
  - DUNETests/HeartRateQueryServiceTests.swift
  - DUNETests/MetricDetailViewModelTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-14-metric-detail-today-scroll-padding.md
  - docs/solutions/general/2026-03-14-condition-score-intraday-stability.md
---

# Solution: Preserve Intraday Resolution in Metric Detail Charts

## Problem

`MetricDetailView`의 `일` 탭이 시간축 UI를 보여도, 실제 데이터 경로가 중간에서 다시 일 단위로 뭉개지면 차트가 의미를 잃는다. 이번에는 `Heart Rate` 상세가 고정된 일간 평균 집계를 사용하고 있었고, `Weight/BMI/Body Fat/Lean Body Mass`도 `일` 탭에서 같은 날의 여러 샘플을 다시 일 평균으로 합치고 있었다.

### Symptoms

- 심박수 상세 `일` 차트가 시간대별 점이 아니라 하루 평균 흐름처럼 보임
- 체중/체성분 상세 `일` 차트에서 같은 날 여러 측정값이 하나의 점으로 줄어듦
- 주/월 이상에서는 괜찮아 보여도 `일` 탭만 유독 데이터 해상도가 낮아짐

### Root Cause

1. `HeartRateQueryService.fetchHeartRateHistory(start:end:)`가 호출 컨텍스트와 무관하게 항상 `DateComponents(day: 1)` statistics collection을 사용했다.
2. `MetricDetailViewModel.loadBodyCompositionData`가 period 구분 없이 raw sample을 다시 `.day` 평균으로 재집계했다.
3. mock path와 real path 모두 “상세 차트 해상도”를 명시적으로 검증하는 테스트가 없어서, UI가 시축으로 바뀌어도 집계 해상도는 그대로 남았다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/HealthKit/HeartRateQueryService.swift` | interval-aware `fetchHeartRateHistory(start:end:interval:)` overload 추가 | 상세 화면이 `day/hour`, `week/day` 같은 period별 집계 해상도를 직접 요청할 수 있게 하기 위해 |
| `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift` | heart rate 상세에 `HealthDataAggregator.intervalComponents(for:)` 전달 | `일` 탭에서 hour bucket, 장기 탭에서 기존 daily/weekly semantics를 유지하기 위해 |
| `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift` | body composition `day`는 raw sample 유지, `week+`만 재집계 | 같은 날 여러 측정값을 intraday detail에서 보존하기 위해 |
| `DUNETests/HeartRateQueryServiceTests.swift` | hourly/day aggregation regression test 추가 | 서비스 계층의 interval 의미를 고정하기 위해 |
| `DUNETests/MetricDetailViewModelTests.swift` | heart rate/body composition day-period regression test 추가 | ViewModel이 intraday 데이터를 다시 뭉개지 않도록 막기 위해 |

### Key Code

```swift
let interval = HealthDataAggregator.intervalComponents(for: selectedPeriod)
let samples = try await heartRateService.fetchHeartRateHistory(
    start: range.start,
    end: range.end,
    interval: interval
)
```

```swift
let aggregated: [ChartDataPoint]
if selectedPeriod == .day {
    aggregated = raw
} else {
    aggregated = HealthDataAggregator.aggregateByAverage(
        raw,
        unit: selectedPeriod == .sixMonths || selectedPeriod == .year
            ? selectedPeriod.aggregationUnit
            : .day
    )
}
```

## Prevention

### Checklist Addition

- [ ] 차트 x-axis가 `hour`이면 service query interval도 `hour`인지 확인
- [ ] raw-sample metric은 `day` detail에서 다시 `.day` 평균으로 합치지 않는지 확인
- [ ] mock path와 real path가 같은 aggregation semantics를 가지는지 테스트로 고정

### Rule Addition (if applicable)

`docs/corrections-active.md`에 intraday detail 해상도 보존 규칙을 추가했다.

## Lessons Learned

시간 해상도는 UI 포맷이 아니라 데이터 계약이다. `day` 차트가 시간축을 보여주면 service, mock, ViewModel 재집계까지 모두 intraday semantics를 유지해야 하고, 장기 period 최적화를 그대로 재사용하면 차트는 쉽게 “보여주기만 hourly”인 상태가 된다.
