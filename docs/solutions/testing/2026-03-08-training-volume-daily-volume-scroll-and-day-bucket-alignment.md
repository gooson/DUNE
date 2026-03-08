---
tags: [ios, swiftui, charts, activity, scroll, training-volume, accessibility-id]
category: testing
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift
  - DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeDetailView.swift
  - DUNE/Presentation/Activity/TrainingVolume/Components/StackedVolumeBarChartView.swift
  - DUNE/Presentation/Activity/Components/TrainingLoadChartView.swift
  - DUNE/Presentation/Activity/WeeklyStats/Components/DailyVolumeChartView.swift
  - DUNE/Presentation/Shared/Charts/ChartModels.swift
  - DUNETests/TrainingVolumeViewModelTests.swift
  - DUNETests/ChartModelsTests.swift
  - DUNEUITests/Regression/ChartInteractionRegressionUITests.swift
related_solutions:
  - docs/solutions/testing/2026-03-08-training-load-daily-volume-scroll-history.md
  - docs/solutions/architecture/2026-03-08-chart-scroll-domain-sparse-data.md
---

# Solution: Training Volume Daily Volume Scroll And Day-Bucket Chart Alignment

## Problem

`TrainingVolumeDetailView`의 상단 `일일 볼륨` stacked chart는 과거 데이터 스크롤이 되지 않았고, 하단 `트레이닝 부하` chart는 헤더 range와 실제 막대 표시 범위가 하루 어긋나 보였다.

### Symptoms

- Training Volume 상세 상단 `일일 볼륨` card가 항상 현재 period만 보여 이전 구간으로 이동할 수 없음
- Training Load header는 `3월 2일 – 3월 8일`인데 실제 x축은 `3월 1일 – 3월 7일`처럼 하루 앞당겨 보임
- day-bucket bar chart 회귀를 막는 테스트가 없어 상단 chart 누락과 날짜 정렬 오차가 함께 남음

### Root Cause

- 지난 scroll history 확장 작업이 `TrainingLoadChartView`와 `WeeklyStats` daily chart까지만 적용되고, `TrainingVolumeDetail`의 `StackedVolumeBarChartView`는 여전히 `comparison.current.dailyBreakdown`만 사용하고 있었다.
- Swift Charts day-bucket bar chart에 `.chartXScale(domain:)`를 `first...last`로 주면 마지막 날짜 bucket의 끝 경계가 빠져, visible window가 최신 날짜보다 하루 앞에서 clamp될 수 있다.

## Solution

Training Volume 화면에 chart 전용 history state를 추가하고, day-bucket bar chart 공통 x-domain helper를 도입해 마지막 날짜 bucket까지 포함하도록 정렬을 통일했다. 동시에 unit/UI regression을 추가해 stacked daily volume scroll과 training load 정렬 패턴을 다시 고정했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift` | `chartDailyBreakdown` history 상태 추가 | comparison summary와 별개로 scrollable daily history 공급 |
| `DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeDetailView.swift` | 상단 stacked chart에 history 배열과 period 전달 | current-only breakdown 대신 scrollable history 표시 |
| `DUNE/Presentation/Activity/TrainingVolume/Components/StackedVolumeBarChartView.swift` | scroll position, visible range, UI test surface, shared overlay 연결 | Training Volume 상단 daily chart도 과거 스크롤/selection 지원 |
| `DUNE/Presentation/Shared/Charts/ChartModels.swift` | `resolvedDayBucketXDomain` 추가 | 마지막 일자 bucket이 잘리지 않도록 공통 day-bucket domain 정렬 |
| `DUNE/Presentation/Activity/Components/TrainingLoadChartView.swift` | 새 day-bucket domain helper 적용 | training load 최신 날짜 표시 하루 밀림 방지 |
| `DUNE/Presentation/Activity/WeeklyStats/Components/DailyVolumeChartView.swift` | 동일 helper 적용 | scrollable daily bar chart 정렬을 화면 간 일관되게 유지 |
| `DUNETests/TrainingVolumeViewModelTests.swift` | daily history 범위 테스트 추가 | Training Volume chart history 길이/시작/끝 날짜 고정 |
| `DUNETests/ChartModelsTests.swift` | day-bucket domain padding 테스트 추가 | 마지막 bucket + 1 day 규칙 고정 |
| `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift` | Training Volume daily volume scroll regression 추가 | 상단 chart 누락을 실제 seeded 제스처로 방지 |

### Key Code

```swift
func resolvedDayBucketXDomain(
    dates: [Date],
    calendar: Calendar = .current
) -> ClosedRange<Date> {
    guard let first = dates.min(), let last = dates.max() else {
        let now = Date()
        return now...now.addingTimeInterval(1)
    }

    let start = calendar.startOfDay(for: first)
    let lastDay = calendar.startOfDay(for: last)
    let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay.addingTimeInterval(86_400)

    return start...end
}
```

## Prevention

### Checklist Addition

- [ ] Activity detail chart scroll 작업 시 `TrainingVolumeDetail` 상단 `StackedVolumeBarChartView`도 대상에 포함됐는지 확인한다
- [ ] day 단위 `BarMark` + `chartXScale(domain:)` 조합은 마지막 날짜 다음날까지 upper bound를 열어 latest bucket 정렬을 검증한다
- [ ] scrollable chart regression은 새 AXID와 seeded quick drag test로 실제 과거 이동을 고정한다

### Rule Addition (if applicable)

새 전역 rule 추가까지는 필요하지 않았다. 다만 차트 scroll 회귀를 볼 때 “history state 누락”과 “day-bucket domain upper bound”를 함께 확인하는 패턴을 기존 chart solution 묶음에 포함해 재사용한다.

## Lessons Learned

- 같은 화면 안에서도 차트마다 데이터 공급 방식이 다르면 scroll 개선이 일부 카드에만 적용되고 끝날 수 있다.
- Date line chart에서 쓰던 `first...last` x-domain은 day-bucket bar chart에서는 마지막 bin을 보장하지 못한다.
- chart gesture 회귀 테스트는 “차트가 있느냐”보다 “과거 데이터가 실제로 드러나느냐”를 직접 확인해야 한다.
