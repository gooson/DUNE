---
tags: [condition-score, hrv, sampling-density, intraday, healthkit]
category: general
date: 2026-10-14
severity: important
related_files:
  - DUNE/Domain/UseCases/CalculateConditionScoreUseCase.swift
  - DUNETests/ConditionScoreHRVDensityTests.swift
related_solutions:
  - docs/solutions/general/2026-03-14-condition-score-intraday-stability.md
---

# Solution: HRV 표본 밀도와 무관한 컨디션 점수

## Problem

### Symptoms

- 한 시간에 표본을 더 자주 기록하는 기기를 사용하면 같은 시간대의 생리 신호도 하루 평균에서 더 큰 비중을 차지한다.
- 최근 한 시간의 중복 표본이 하루 중 점수의 3시간 창 또는 최소 표본 조건을 잘못 충족할 수 있다.

### Root Cause

일간 계산은 모든 원시 표본을 같은 가중치로 평균했고, 하루 중 계산은 창 선택에 원시 표본 수를 사용했다. 기록 주기가 달라지면 실제로 관측한 시간대 수와 관계없이 점수 입력이 바뀌었다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/UseCases/CalculateConditionScoreUseCase.swift` | 시간별 합계와 개수를 한 번 집계해 시간별 평균을 구하고, 하루 평균에는 각 관측 시간을 같은 가중치로 반영 | 시간당 표본 밀도에 따른 편향 제거 |
| `DUNE/Domain/UseCases/CalculateConditionScoreUseCase.swift` | 3시간·6시간 창과 하루 전체 fallback의 최소 조건을 서로 다른 관측 시간 수로 판정 | 중복 표본으로 창이 전환되는 문제 방지 |
| `DUNETests/ConditionScoreHRVDensityTests.swift` | 혼합 기록 주기, 중복 표본, 3시간 창, 하루 전체 fallback 회귀 테스트 | 원시 표본 개수와 계산 결과를 분리해서 검증 |

### Key Code

```swift
for (hour, bucket) in hourlyTotals(from: samples, calendar: calendar) {
    let day = calendar.startOfDay(for: hour)
    var daily = dailyTotals[day] ?? (sum: 0, count: 0)
    daily.sum += bucket.sum / Double(bucket.count)
    daily.count += 1
    dailyTotals[day] = daily
}
```

하루 중 점수는 각 후보 창의 `hourlyAverages` 개수를 검사하고, 선택한 창의 시간별 평균을 다시 평균한다. 하루 전체 fallback에는 최소 두 관측 시간이 필요하다.

## Prevention

- [ ] 센서 기록 주기를 바꾸는 기능은 동일한 시간별 신호를 저빈도·고빈도·혼합 표본으로 만들어 결과를 비교한다.
- [ ] 시간 창의 최소 데이터 조건은 원시 표본 수가 아니라 독립 관측 단위로 판정한다.
- [ ] 하루 평균을 계산할 때 시간별 집계를 먼저 수행하고 불필요한 일자별 원시 표본 재그룹화를 피한다.

## Lessons Learned

HealthKit 표본 개수는 측정 횟수를 뜻하며 독립된 시간대 수를 뜻하지 않는다. 기기별 기록 주기가 달라도 같은 생리 신호에는 같은 가중치를 부여해야 한다.
