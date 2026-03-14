---
tags: [swift-charts, metric-detail, scroll-domain, current-day, hrv, condition-score]
category: architecture
date: 2026-03-14
severity: important
related_files:
  - DUNE/Domain/Models/TimePeriod.swift
  - DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift
  - DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift
  - DUNETests/TimePeriodTests.swift
  - DUNETests/MetricDetailViewModelTests.swift
  - DUNETests/ConditionScoreDetailViewModelTests.swift
related_solutions:
  - docs/solutions/general/2026-03-08-chart-scrollable-axes-visible-domain.md
  - docs/solutions/architecture/2026-03-11-metric-detail-weekly-chart-current-day-alignment.md
  - docs/solutions/general/2026-03-12-condition-score-rhr-baseline-and-chart-scroll.md
---

# Solution: Metric Detail Today Scroll Padding

## Problem

HRV 상세 화면에서 오늘 값은 존재하지만 주간 차트가 현재 시각 기준으로 clamp되어, 헤더가 `3.7 – 3.14`처럼 하루 왼쪽으로 밀리고 사용자가 오늘 끝까지 스크롤할 수 없었다. 같은 scroll domain 경로를 공유하는 Condition Score detail도 동일한 회귀 가능성이 있었다.

### Symptoms

- 오늘 데이터 포인트가 차트 우측 경계에 붙어 보인다.
- 마지막 weekday label이 잘리거나 오른쪽 여백이 부족해 보인다.
- 스크롤을 더 오른쪽으로 밀어도 오늘 기준 window로 맞춰지지 않는다.

### Root Cause

detail ViewModel의 `scrollDomain` upper bound가 `Date()` 그대로였다. Swift Charts는 `chartXVisibleDomain(length:)` window가 domain 안에 완전히 들어가야 하므로, 현재 시각이 새벽/오전이면 최대 `scrollPosition`을 `now - visibleLength`로 clamp한다. 결과적으로 의도한 `startOfToday - 6d` 대신 몇 시간 앞선 전날 밤/새벽 anchor로 밀리면서 today-inclusive weekly window가 깨졌다.

## Solution

data fetch range는 그대로 `now`를 사용하고, chart scroll/display domain만 다음 day boundary까지 확장했다. 동시에 detail ViewModel configure 시점에 `scrollPosition`을 현재 period 시작점으로 명시적으로 초기화해 차트 clamp에만 의존하지 않도록 정리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Models/TimePeriod.swift` | `scrollDomainUpperBound(referenceDate:)` helper 추가 | current-time clamp를 막는 공통 display-domain 경계 계산을 한 곳에 두기 위해 |
| `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift` | `configure()`에서 `resetScrollPosition()` 호출, `scrollDomain` upper bound를 helper로 계산 | HRV/RHR 등 공통 metric detail이 today-inclusive window를 유지하도록 맞추기 위해 |
| `DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift` | 동일한 초기 scroll/reset + aligned upper bound 적용 | Condition Score detail도 같은 회귀를 방지하기 위해 |
| `DUNETests/TimePeriodTests.swift` | next-day boundary regression test 추가 | helper가 새벽 reference date에서도 다음 날 자정으로 정렬되는지 고정하기 위해 |
| `DUNETests/MetricDetailViewModelTests.swift` | configure reset / scrollDomain upper bound test 추가 | metric detail ViewModel이 올바른 초기 위치와 scroll domain을 유지하는지 보호하기 위해 |
| `DUNETests/ConditionScoreDetailViewModelTests.swift` | configure reset / scrollDomain expectation 보강 | score detail도 동일한 contract를 따르는지 검증하기 위해 |

### Key Code

```swift
func scrollDomainUpperBound(
    referenceDate: Date = Date(),
    calendar: Calendar = .current
) -> Date {
    let startOfReferenceDay = calendar.startOfDay(for: referenceDate)
    return calendar.date(byAdding: .day, value: 1, to: startOfReferenceDay) ?? referenceDate
}
```

```swift
var scrollDomain: ClosedRange<Date> {
    let range = extendedRange
    let upperBound = selectedPeriod.scrollDomainUpperBound(referenceDate: range.end)
    return range.start...max(range.end, upperBound)
}
```

## Prevention

scrollable chart는 “데이터 query end”와 “display/scroll domain end”를 분리해서 봐야 한다. 일간 버킷을 보여주는 UI에서 domain upper bound를 `now`로 두면 새벽/오전 시간대에 current-day window가 항상 왼쪽으로 밀릴 수 있다.

### Checklist Addition

- [ ] today-inclusive chart가 `Date()`가 아니라 다음 day boundary 기준으로 scroll domain을 여는지 확인한다
- [ ] initial `scrollPosition`이 차트 clamp에만 의존하지 않고 current period start로 명시 초기화되는지 확인한다
- [ ] detail/chart 회귀를 고칠 때 공통 helper와 score detail parity를 함께 점검한다

### Rule Addition (if applicable)

기존 chart scroll solution 문서군과 testing-required 규칙으로 충분해 새 전역 rule 추가는 하지 않았다.

## Lessons Learned

- “오늘 점이 보인다”와 “오늘까지 스크롤 가능하다”는 별개의 문제다.
- scrollable 차트의 query range와 display domain을 섞으면 새벽 시간대 회귀가 반복된다.
- Metric detail과 Condition Score detail은 scroll semantics를 공유하므로 한쪽만 고치면 다시 parity bug가 생긴다.
