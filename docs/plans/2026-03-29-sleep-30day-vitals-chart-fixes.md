---
tags: [sleep, chart, gridline, empty-state, vitals]
date: 2026-03-29
category: plan
status: draft
---

# Sleep 30-Day Vitals Chart Fixes

## Problem

수면 상세 화면의 "30일 바이탈" 차트(VitalsTimelineCard)에 두 가지 문제:

1. **Y축 점선 그리드라인 누락**: 야간 건강지표(NocturnalVitalsChartView)에는 Y축에 점선 그리드라인이 있지만, 30일 바이탈 차트에는 `AxisValueLabel()`만 있고 `AxisGridLine()`이 없음
2. **데이터 없을 때 카드 크기 축소**: 손목온도 등 데이터가 없는 탭 선택 시 empty state가 `minHeight: 120`으로 차트 영역(136+16=152pt)보다 작아 카드가 줄어듦

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Presentation/Sleep/Components/VitalsTimelineCard.swift` | Y축/X축에 AxisGridLine 추가, empty state 높이 고정 |

## Implementation Steps

### Step 1: Y축 그리드라인 추가

`trackChart` 함수의 `.chartYAxis` 블록에 `AxisGridLine()` 추가:

```swift
// Before
.chartYAxis {
    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
        AxisValueLabel()
            .font(.caption2)
    }
}

// After
.chartYAxis {
    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            .foregroundStyle(Color.secondary.opacity(0.3))
        AxisValueLabel()
            .font(.caption2)
    }
}
```

### Step 2: X축 그리드라인 추가 (선택적)

야간 건강지표는 X축에도 `AxisGridLine()`이 있음. 30일 차트도 동일하게:

```swift
// After
.chartXAxis {
    AxisMarks(values: .automatic(desiredCount: 5)) {
        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            .foregroundStyle(Color.secondary.opacity(0.3))
        AxisValueLabel(format: .dateTime.day())
            .font(.caption2)
    }
}
```

### Step 3: Empty state 높이 고정

데이터 없는 경우의 empty state 높이를 차트 영역과 동일하게:

```swift
// Before
.frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)

// After — chart height(136) + padding(.top, 16) = 152
.frame(maxWidth: .infinity, minHeight: 152, alignment: .leading)
```

## Test Strategy

- 빌드 확인: `scripts/build-ios.sh`
- 시각적 확인: 시뮬레이터에서 수면 상세 → 30일 바이탈 → 각 탭 선택하여 그리드라인 확인
- Empty state 확인: 데이터 없는 탭(손목온도 등) 선택 시 카드 크기 유지 확인

## Risks & Edge Cases

- 그리드라인 스타일이 야간 건강지표와 시각적으로 일치해야 함
- empty state의 높이 변경이 카드 내 다른 요소 레이아웃에 영향 없는지 확인
