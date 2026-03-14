---
tags: [condition-score, hourly-chart, intraday, hrv, dashboard]
category: general
date: 2026-03-14
severity: important
related_files:
  - DUNE/Domain/UseCases/CalculateConditionScoreUseCase.swift
  - DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift
  - DUNETests/CalculateConditionScoreUseCaseTests.swift
  - DUNETests/ConditionScoreDetailViewModelTests.swift
related_solutions:
  - docs/solutions/general/2026-03-12-condition-score-rhr-baseline-and-chart-scroll.md
  - docs/solutions/architecture/2026-03-13-hourly-score-snapshot-system.md
---

# Solution: Stabilize Condition Score Intraday Chart

## Problem

Condition Score 상세 화면의 `day` 그래프가 시간별 변화를 보여주지만, 실제 계산은 일간용 score snapshot을 그대로 재사용하고 있었다. 자정 이후 HRV 샘플이 몇 개만 더 들어와도 "오늘 누적 평균"이 크게 바뀌면서 그래프가 급격히 튀었다.

### Symptoms

- 새벽 구간의 점수가 60대와 80대 후반 사이를 짧은 간격으로 왕복함
- 사용자는 그래프를 시간별 컨디션 변화로 해석하지만, 실제로는 partial-day daily average 변화가 반영됨
- `day` 차트가 `ScoreRefreshService` snapshot 유무에 따라 비거나 과도하게 민감하게 보일 수 있음

### Root Cause

1. `ConditionScoreDetailViewModel.loadHourlyData()`가 raw HRV 기반 시간별 재계산이 아니라 persisted snapshot 점수를 그대로 차트에 그렸다.
2. snapshot의 condition score는 기존 `CalculateConditionScoreUseCase.execute` 경로를 사용해 "오늘 일평균 HRV"를 계산하므로, intraday 해상도와 맞지 않았다.
3. 최근 몇 시간의 변화가 아니라 하루 누적 평균이 계속 다시 잡히면서 초반 데이터에 과민 반응했다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/UseCases/CalculateConditionScoreUseCase.swift` | `executeIntraday` helper와 공통 scoring path 추가 | intraday 전용 HRV window 계산을 일간 score와 분리하기 위해 |
| `DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift` | `day` 차트를 snapshot read 대신 raw HRV/RHR 기반 hour-by-hour recompute로 전환 | 그래프 의미를 실제 시간별 score로 맞추기 위해 |
| `DUNETests/CalculateConditionScoreUseCaseTests.swift` | 3h→6h window fallback, stale spike 완화 테스트 추가 | intraday 수식 안정성 회귀 방지 |
| `DUNETests/ConditionScoreDetailViewModelTests.swift` | snapshot service 없이도 `day` 차트가 생성되는 테스트 추가 | view model 경로가 raw health data 기반임을 고정 |

### Key Code

```swift
private func computeIntradayAverage(
    from samples: [HRVSample],
    evaluationDate: Date,
    calendar: Calendar
) -> Double? {
    let recentWindow = validSamples.filter { $0.date >= recentWindowStart }
    if recentWindow.count >= minimumIntradayWindowSamples {
        return average(recentWindow.map(\.value))
    }

    let expandedWindow = validSamples.filter { $0.date >= expandedWindowStart }
    if expandedWindow.count >= minimumIntradayWindowSamples {
        return average(expandedWindow.map(\.value))
    }

    return average(validSamples.map(\.value))
}
```

```swift
chartData = hourlyEvaluationDates.compactMap { item in
    let output = scoreUseCase.executeIntraday(input: .init(
        hrvSamples: samples,
        rhrDailyAverages: rhrDailyAverages,
        evaluationDate: item.evaluationDate
    ))
    guard let score = output.score else { return nil }
    return ChartDataPoint(date: item.hourDate, value: Double(score.score))
}
```

## Prevention

### Checklist Addition

- [ ] 시간축이 hour-level인 차트가 실제로 hour-level 계산식을 사용하는지 확인
- [ ] daily score를 intraday chart에 재사용할 때 partial-day 평균이 과민 반응하지 않는지 검토
- [ ] 최신 sample 기반 그래프는 3h/6h 같은 최소 window 정책이 있는지 확인

### Rule Addition (if applicable)

새 rule 추가까지는 필요 없다. 다만 score chart가 더 늘어나면 "time resolution과 score formula를 맞춘다"는 규칙으로 승격할 가치가 있다.

## Lessons Learned

intraday UI를 만들 때 저장 단위(hourly snapshot)와 계산 단위(daily average)가 다르면 차트는 쉽게 의미를 잃는다. 시간 해상도가 올라가면 score input도 같은 해상도로 다시 정의해야 사용자가 그래프를 신뢰할 수 있다.
