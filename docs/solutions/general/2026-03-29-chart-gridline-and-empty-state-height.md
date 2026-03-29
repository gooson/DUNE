---
tags: [swift-charts, gridline, axis, empty-state, layout-consistency, sleep]
date: 2026-03-29
category: general
status: implemented
---

# Swift Charts Gridline & Empty State Height Consistency

## Problem

VitalsTimelineCard (30-day vitals chart) had two visual inconsistencies:

1. **Missing grid lines**: `chartYAxis` and `chartXAxis` only declared `AxisValueLabel()` without `AxisGridLine()`, unlike the reference NocturnalVitalsChartView which uses default `AxisMarks` (includes gridlines)
2. **Shrinking empty state**: When no data was available (e.g., wrist temperature), the empty state used `minHeight: 120` but the chart area was `height: 136` + `padding(.top, 16)` = 152pt, causing the card to visibly shrink

## Solution

### Grid lines

Added `AxisGridLine(stroke:)` to both Y-axis and X-axis `AxisMarks` closures:

```swift
AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
    .foregroundStyle(Color.secondary.opacity(0.3))
```

Key: `AxisGridLine` must come **before** `AxisValueLabel` in the `AxisMarks` closure (declaration order = render order).

### Empty state height

Changed `minHeight` from 120 to 152 to match the chart area's total height:
- Chart `.frame(height: 136)` + `.padding(.top, 16)` = 152pt

## Prevention

When adding a chart with an empty state fallback, always calculate the empty state height as:
```
minHeight = chart .frame(height:) + any top/bottom padding
```

This prevents the card from jumping in size when switching between data/no-data states.

## Lessons Learned

- Swift Charts' custom `AxisMarks` closure suppresses all defaults (gridlines, ticks, labels). When overriding for custom font, you must re-add `AxisGridLine()` explicitly if gridlines are desired.
- Default `AxisMarks(position: .leading)` includes gridlines automatically — only custom closures need explicit declaration.
