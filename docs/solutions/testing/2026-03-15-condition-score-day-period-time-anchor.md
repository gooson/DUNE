---
tags: [condition-score, unit-test, time-dependent, now-provider, hrv]
category: testing
date: 2026-03-15
severity: minor
related_files:
  - DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift
  - DUNETests/ConditionScoreDetailViewModelTests.swift
related_solutions:
  - docs/solutions/general/2026-03-14-condition-score-intraday-stability.md
---

# Solution: Anchor Condition Score Day-Period Test Time

## Problem

`ConditionScoreDetailViewModelTests.dayPeriodUsesIntradayRecompute()`가 새벽 시간대에 간헐적으로 실패했다. 테스트는 snapshot service 없이 raw HRV 샘플로 `day` 차트를 재계산하는 contract를 고정해야 하는데, 실행 시각에 따라 `chartData`가 비어 회귀 신호가 거짓 양성으로 바뀌었다.

### Symptoms

- `#expect(vm.chartData.count >= 2)` 실패
- `#expect(vm.summaryStats != nil)` 실패
- 로컬 시각이 `2026-03-15 00:36 KST`일 때 재현

### Root Cause

테스트가 `Date()`의 현재 hour component로 today sample hour를 만들었다. 자정 직후에는 생성된 sample 중 일부가 현재 시각보다 미래가 되고, `ConditionScoreDetailViewModel.loadHourlyData()`는 `sample.date <= now`만 허용하므로 future sample을 제거한다. 결과적으로 same-day hour bucket이 1개 이하로 줄어 `executeIntraday`의 최소 샘플 수를 만족하지 못했다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift` | `nowProvider` 주입점 추가 | 시간 필터를 테스트에서 결정적으로 고정하기 위해 |
| `DUNETests/ConditionScoreDetailViewModelTests.swift` | failing test에 noon anchor 주입 | 새벽 실행에도 today chart가 항상 2개 이상 hour bucket을 갖도록 만들기 위해 |

### Key Code

```swift
init(
    hrvService: HRVQuerying? = nil,
    healthKitManager: HealthKitManager = .shared,
    scoreRefreshService: ScoreRefreshService? = nil,
    nowProvider: @escaping @Sendable () -> Date = Date.init
) {
    self.nowProvider = nowProvider
}
```

```swift
let fixedNow = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
let vm = ConditionScoreDetailViewModel(hrvService: service, nowProvider: { fixedNow })
```

## Prevention

### Checklist Addition

- [ ] same-day hourly chart 테스트는 `Date()`의 현재 hour를 직접 조합하지 않는다.
- [ ] production code가 `now` 기준 필터를 가지면 테스트도 같은 기준 시각을 주입하거나 고정한다.
- [ ] 자정 직후에도 기대 bucket 수가 성립하는지 먼저 계산해 본다.

### Rule Addition (if applicable)

새 rule 추가까지는 필요 없다. 다만 time-sensitive test가 반복되면 공통 `nowProvider` 패턴을 테스트 작성 규칙으로 승격할 수 있다.

## Lessons Learned

시간 의존 테스트는 입력 데이터만 고정해서는 충분하지 않다. production path가 `Date()`를 직접 읽으면 테스트도 동일한 clock을 제어할 수 있어야 새벽/타임존 구간에서 flaky regression을 막을 수 있다.
