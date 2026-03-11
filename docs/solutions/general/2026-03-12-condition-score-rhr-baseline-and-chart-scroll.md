---
tags: [condition-score, rhr, baseline, dashboard, charts]
date: 2026-03-12
category: general
status: implemented
related_files:
  - DUNE/Domain/Models/ConditionScore.swift
  - DUNE/Domain/UseCases/CalculateConditionScoreUseCase.swift
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
  - DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift
  - DUNE/Presentation/Shared/Components/ConditionCalculationCard.swift
related_solutions:
  - docs/solutions/general/2026-03-11-condition-score-rhr-visibility.md
  - docs/solutions/architecture/2026-03-11-metric-detail-weekly-chart-current-day-alignment.md
---

# Solution: Condition Score RHR Baseline 정렬 및 상세 차트 Today Scroll 복원

## Problem

컨디션 스코어는 HRV는 baseline-relative로 계산하면서 RHR는 `today vs yesterday` 임계값 보정만 사용하고 있었음. 그 결과 Today hero 카드, Score Contributors, Condition Calculation 카드가 서로 다른 기준을 보여줬고, historical score chart도 RHR를 반영하지 못했다. 추가로 컨디션 상세 차트는 오늘 점을 그리더라도 scroll domain이 없어 마지막 스크롤 한계가 사실상 어제 데이터에서 끝날 수 있었다.

### Symptoms

- Today hero 카드에서 HRV만 보이고 RHR 변화가 빠짐
- Condition Score detail의 contributor와 calculation card 설명이 서로 다름
- 최근 score history / detail chart가 HRV-only 계산으로 남음
- Condition Score detail chart에서 오늘 점은 보이는데 스크롤 최대 범위가 어제처럼 느껴짐

### Root Cause

1. `CalculateConditionScoreUseCase`가 RHR를 baseline 편차가 아니라 전일 차이 임계값으로만 처리했음.
2. `buildRecentScores`와 `ConditionScoreDetailViewModel.computeDailyScores`가 HRV samples만 넘겨 historical score를 계산했음.
3. Today hero badge 모델이 metric별 polarity를 표현하지 못해 RHR badge를 붙이기 어려웠음.
4. `ConditionScoreDetailView`가 `DotLineChartView.scrollDomain`을 주입하지 않아 sparse/current-day chart에서 today-inclusive scroll range를 보장하지 못했음.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/UseCases/CalculateConditionScoreUseCase.swift` | RHR를 baseline-relative 연속 보정으로 교체하고 fallback contributor 추가 | HRV와 같은 baseline 철학으로 score/contributor/detail 정렬 |
| `DUNE/Domain/Models/ConditionScore.swift` | `ConditionScoreDetail`에 `rhrAdjustment`, `baselineRHR`, `rhrDeltaFromBaseline`, `rhrBaselineDays` 추가 | UI와 mirrored payload가 baseline-relative RHR 문맥을 유지하도록 보존 |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | hero badge를 `HRV vs 14d avg` + `RHR vs 14d avg`로 정렬하고 recent score 계산에 RHR history 전달 | Today hero와 7일 sparkline도 같은 scoring input 사용 |
| `DUNE/Data/Services/SharedHealthDataServiceImpl.swift` | snapshot/recent score 계산에 RHR daily averages 전달 | shared snapshot 경로도 로컬 경로와 동일한 score 계산 유지 |
| `DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift` | chart score history 계산에 RHR collection 포함, `scrollDomain` 추가 | detail chart가 historical RHR를 반영하고 오늘까지 스크롤 가능하게 함 |
| `DUNE/Presentation/Shared/Components/ConditionCalculationCard.swift` | RHR 섹션을 `Today/Latest`, `Baseline`, `Delta`, `Adjustment` 구조로 재작성 | 계산 방식 설명을 baseline-relative 모델에 맞춤 |
| `DUNE/Presentation/Shared/Models/MetricBaselineDelta.swift` / `BaselineTrendBadge.swift` | badge에 inverse polarity 메타데이터 추가 | RHR badge를 hero에서 색/의미 반대로 렌더링 |
| `DUNE/Data/Services/HealthSnapshotMirrorMapper.swift` | legacy payload 복원 시 RHR 14일 series를 scoring input에 전달 | mirrored legacy record도 baseline-relative detail 복구 |

### Key Code

```swift
let rhrBaselineSamples = Array(
    dailyRHR
        .filter { $0.date < scoreDate }
        .prefix(Self.conditionWindowDays)
)
let rhrDeltaFromBaseline = todayRHR.flatMap { today in
    baselineRHR.map { today - $0 }
}
let rhrZScore = rhrDeltaFromBaseline / max(rhrStdDev, minimumRHRStdDev)
let rhrAdjustment = max(-12, min(12, -(rhrZScore * 4.0)))
rawScore += rhrAdjustment
```

```swift
DotLineChartView(
    data: viewModel.chartData,
    baseline: 50,
    yAxisLabel: "Score",
    timePeriod: viewModel.selectedPeriod,
    tintColor: score.status.color,
    trendLine: viewModel.trendLineData,
    scrollDomain: viewModel.scrollDomain,
    scrollPosition: $viewModel.scrollPosition
)
```

## Prevention

### Checklist Addition

- [ ] score detail screen이 현재 score와 history score에 동일한 metric inputs를 쓰는지 확인
- [ ] hero badge 모델에 metric polarity가 필요한지 먼저 검토
- [ ] scrollable chart는 항상 `scrollDomain`과 `visibleRangeLabel`이 today-inclusive인지 함께 검증

## Lessons Learned

- baseline-relative 지표는 current card, contributors, history chart가 같은 window/data source를 공유해야 UX가 어긋나지 않는다.
- current-day point가 보이는 것과 current-day까지 스크롤 가능한 것은 별개라서, sparse chart에서는 `scrollDomain`이 사실상 필수다.
