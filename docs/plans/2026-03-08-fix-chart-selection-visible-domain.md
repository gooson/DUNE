---
tags: [charts, swiftui, gesture, visible-domain, regression]
date: 2026-03-08
category: plan
status: approved
---

# Plan: Fix Chart Selection Breaking Visible Domain

## Problem Statement

웰니스 상세 차트에서 롱프레스 selection 활성화 시:
1. 차트가 주간 데이터 대신 ~5주 전체 버퍼 데이터를 표시 (월간처럼 보임)
2. selection 중 과거로 스크롤 불가

### Root Cause

`.chartScrollableAxes([])` 설정 시 `.chartXVisibleDomain(length:)` 무시됨.
Apple Charts의 `visibleDomain`은 scrollable 차트에서만 동작하며, 비-scrollable 차트는 전체 데이터를 표시.

이전 수정(2026-03-08 chart-long-press-scroll-regression)에서 selection 중 scroll 방지를 위해
`allowsScroll ? .horizontal : []` 패턴을 도입했으나, 이것이 visible domain을 깨뜨림.

## Solution

`.chartScrollableAxes(.horizontal)`을 항상 유지하되, `.scrollDisabled()`로 사용자 스크롤만 비활성화.
추가로 `.updating` 시 scroll position도 복원하여 drift 방지.

## Affected Files

| File | Change |
|------|--------|
| `Shared/Charts/AreaLineChartView.swift` | `.chartScrollableAxes` 고정 + `.scrollDisabled` + updating scroll restore |
| `Shared/Charts/BarChartView.swift` | 동일 |
| `Shared/Charts/DotLineChartView.swift` | 동일 (timePeriod nil 체크 보존) |
| `Shared/Charts/RangeBarChartView.swift` | 동일 |
| `Shared/Charts/SleepStageChartView.swift` | 동일 |

## Implementation Steps

### Step 1: 5개 차트 뷰의 `.chartScrollableAxes` 수정

Before:
```swift
.chartScrollableAxes(selectionGestureState.allowsScroll ? .horizontal : [])
```

After:
```swift
.chartScrollableAxes(.horizontal)
.scrollDisabled(!selectionGestureState.allowsScroll)
```

DotLineChartView 특수 케이스:
```swift
// Before:
.chartScrollableAxes(timePeriod != nil && selectionGestureState.allowsScroll ? .horizontal : [])
// After:
.chartScrollableAxes(timePeriod != nil ? .horizontal : [])
.scrollDisabled(!selectionGestureState.allowsScroll)
```

### Step 2: gesture handler에서 `.updating` 시 scroll position 복원

Before:
```swift
case .updating:
    selectedDate = ChartSelectionInteraction.resolvedDate(...)
```

After:
```swift
case .updating:
    if let restore = selectionGestureState.initialScrollPosition {
        scrollPosition = restore
    }
    selectedDate = ChartSelectionInteraction.resolvedDate(...)
```

## Test Strategy

- 기존 `ChartSelectionInteractionTests` — state machine 동작 변경 없으므로 통과해야 함
- 기존 `ChartInteractionRegressionUITests` — period 불변성 + selection activation 검증 통과해야 함
- 빌드 검증

## Risks & Edge Cases

1. `.scrollDisabled()`가 Charts 내부 scroll에 적용되지 않을 수 있음 → scroll position 복원이 fallback
2. scroll position 복원 시 차트 애니메이션 jitter → `.transaction { $0.animation = nil }` 필요할 수 있음
3. `pendingActivation` 단계(0-180ms)에서는 scroll이 여전히 허용됨 → 이것은 의도된 동작 (사용자가 스크롤하려는 건지 selection하려는 건지 아직 결정 전)
