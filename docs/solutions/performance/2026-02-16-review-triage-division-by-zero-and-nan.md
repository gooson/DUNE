---
tags: [division-by-zero, nan, infinite, guard, math-safety, trend-line, linear-regression, highlight]
category: performance
date: 2026-02-16
severity: critical
related_files:
  - Dailve/Presentation/Shared/HighlightBuilder.swift
  - Dailve/Presentation/Shared/Detail/MetricDetailViewModel.swift
  - Dailve/Domain/UseCases/HealthDataAggregator.swift
  - Dailve/Presentation/Shared/Charts/BarChartView.swift
  - Dailve/Presentation/Shared/Charts/DotLineChartView.swift
  - Dailve/Presentation/Shared/Charts/RangeBarChartView.swift
related_solutions: []
---

# Solution: Division-by-Zero 및 NaN 방어 패턴 통합

## Problem

### Symptoms

- 데이터가 비어있거나 값이 0인 경우 trend 계산, accessibility summary, aggregation에서 NaN/Infinity crash 가능
- Linear regression 결과가 degenerate일 때 차트에 잘못된 점이 표시될 수 있음

### Root Cause

1. **Trend 계산**: `firstHalf.reduce(0, +) / Double(firstHalf.count)` — count가 0이면 NaN
2. **Trend 퍼센트**: `firstAvg`가 0이면 `((secondAvg - firstAvg) / firstAvg) * 100` → Infinity
3. **Linear regression**: 결과 m, b가 NaN/Infinite일 때 후속 계산이 propagate
4. **Accessibility summary**: `data.reduce(0, +) / Double(data.count)` — 빈 배열이면 div/0
5. **Aggregator**: `aggregateRangeData`에서 빈 그룹에 대해 평균 계산 시 div/0

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `HighlightBuilder.swift` | `guard firstHalf.count > 0, secondHalf.count > 0`, `guard firstAvg > 0`, `guard !changePercent.isNaN, !changePercent.isInfinite` | Trend 계산 3중 방어 |
| `MetricDetailViewModel.swift` | `guard !m.isNaN && !m.isInfinite && !b.isNaN && !b.isInfinite`, `guard !y1.isNaN ...` | Regression 결과 이중 검증 |
| `HealthDataAggregator.swift` | `.compactMap` + `guard !points.isEmpty` | 빈 그룹 건너뛰기 |
| `BarChartView/DotLineChartView/RangeBarChartView` | `guard !data.isEmpty` in accessibility summary | 빈 데이터 방어 |

### Key Code

```swift
// Pattern 1: 분모 검증 + NaN 검증 (HighlightBuilder)
guard firstHalf.count > 0, secondHalf.count > 0 else { return nil }
let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
guard firstAvg > 0 else { return nil }
let changePercent = ((secondAvg - firstAvg) / firstAvg) * 100
guard !changePercent.isNaN, !changePercent.isInfinite else { return nil }

// Pattern 2: 중간 결과 검증 (Linear Regression)
let m = (n * sumXY - sumX * sumY) / denominator
let b = (sumY - m * sumX) / n
guard !m.isNaN && !m.isInfinite && !b.isNaN && !b.isInfinite else { return nil }

// Pattern 3: compactMap으로 빈 그룹 제거 (Aggregator)
return grouped.keys.sorted().compactMap { key -> RangeDataPoint? in
    guard let points = grouped[key], !points.isEmpty else { return nil }
    // ... safe division
}
```

## Prevention

### Checklist Addition

- [ ] 나눗셈이 있는 모든 코드에서 분모가 0이 될 수 있는지 확인
- [ ] 수학 함수 결과에 `.isNaN`, `.isInfinite` 체크 적용 여부 확인
- [ ] `reduce(0, +) / count` 패턴이 있으면 count > 0 guard 필수

### Rule Addition (if applicable)

이미 `input-validation.md`에 수학 함수 방어 규칙이 있으나, **중간 결과 이중 검증** 패턴을 강화:
- 최종 결과뿐 아니라 중간 계산값(m, b 등)에도 NaN/Infinite 체크

## Lessons Learned

- Division by zero는 빈 배열(`count == 0`)과 값이 0인 데이터(`firstAvg == 0`) 두 가지 경로로 발생
- `guard !result.isNaN` 한 줄로 여러 upstream 원인을 일괄 방어 가능 — "belt and suspenders" 접근
- Accessibility summary처럼 눈에 잘 안 띄는 곳에서도 div/0가 발생할 수 있음
