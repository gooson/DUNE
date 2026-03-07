---
tags: [swiftui, charts, gesture-selection, floating-overlay, wellness]
category: general
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Shared/Charts/ChartSelectionInteraction.swift
  - DUNE/Presentation/Shared/Charts/ChartSelectionOverlay.swift
  - DUNE/Presentation/Shared/Charts/AreaLineChartView.swift
  - DUNE/Presentation/Shared/Charts/BarChartView.swift
  - DUNE/Presentation/Shared/Charts/DotLineChartView.swift
  - DUNE/Presentation/Shared/Charts/HeartRateChartView.swift
  - DUNE/Presentation/Shared/Charts/RangeBarChartView.swift
  - DUNE/Presentation/Shared/Charts/SleepStageChartView.swift
  - DUNETests/ChartSelectionInteractionTests.swift
related_solutions:
  - docs/solutions/general/2026-02-17-chart-ux-layout-stability.md
  - docs/solutions/architecture/2026-02-23-activity-detail-view-v2-patterns.md
---

# Solution: Common Chart Long-Press Selection And Floating Overlay

## Problem

BMI/Weight/RHR/Sleep detail charts shared the same selection behavior, but the interaction quality was poor across all chart types.

### Symptoms

- Long-press drag selection felt offset or unstable while the chart was still horizontally scrollable.
- The selected date/value overlay stayed pinned to the chart top instead of following the selected point.
- Edge points could place the overlay in awkward positions near chart bounds.
- Haptic feedback could fire too often because the raw drag date changed more frequently than the snapped data point.

### Root Cause

The shared charts relied on `chartXSelection` plus a fixed top overlay. That made it hard to control long-press activation, snapping behavior, overlay placement, and scroll/selection conflicts consistently across different chart types.

## Solution

Replace the fixed `chartXSelection` interaction with a shared `chartOverlay + ChartProxy` selection pipeline, then render a floating overlay anchored to the snapped chart point.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Charts/ChartSelectionInteraction.swift` | Added shared gesture activation, nearest-point snapping, anchor conversion, and overlay clamp/flip layout helpers | Centralize all interaction math for common charts |
| `DUNE/Presentation/Shared/Charts/ChartSelectionOverlay.swift` | Added `FloatingChartSelectionOverlay` with measured size and point-relative positioning | Show value/date near the graph instead of pinning to the top |
| `DUNE/Presentation/Shared/Charts/AreaLineChartView.swift` | Replaced `chartXSelection` with manual overlay gesture and floating overlay | Fix drag precision and UI placement for area charts |
| `DUNE/Presentation/Shared/Charts/BarChartView.swift` | Same shared interaction migration | Keep bar chart behavior aligned with other charts |
| `DUNE/Presentation/Shared/Charts/DotLineChartView.swift` | Same shared interaction migration | Keep HRV/detail chart behavior aligned |
| `DUNE/Presentation/Shared/Charts/HeartRateChartView.swift` | Added floating overlay and snapped selection | Improve workout heart-rate chart exploration |
| `DUNE/Presentation/Shared/Charts/RangeBarChartView.swift` | Added floating overlay, localized `Avg` label reuse, and snapped range selection | Improve RHR range chart readability and localization compliance |
| `DUNE/Presentation/Shared/Charts/SleepStageChartView.swift` | Moved stacked sleep selection to the same floating overlay model | Unify sleep chart interaction with the rest of the app |
| `DUNETests/ChartSelectionInteractionTests.swift` | Added pure tests for hold activation, cancellation, snapping, clamp, and flip logic | Lock down the interaction math independently from UI rendering |

### Key Code

```swift
DragGesture(minimumDistance: 0, coordinateSpace: .local)
    .onChanged { value in
        guard selectionGestureState.registerChange(
            at: value.time,
            translation: value.translation
        ) else { return }

        selectedDate = ChartSelectionInteraction.resolvedDate(
            at: value.location,
            proxy: proxy,
            plotFrame: plotFrame
        )
    }
```

```swift
let layout = ChartSelectionInteraction.overlayLayout(
    anchor: anchor,
    overlaySize: overlaySize,
    chartSize: chartSize,
    plotFrame: plotFrame
)
```

## Prevention

When a chart needs custom long-press selection UX, do not start from a fixed top overlay or raw `chartXSelection` alone. Move the interaction math into a shared helper, snap to the nearest domain model point, and keep scroll disabled while selection is active.

### Checklist Addition

- [ ] If a chart uses long-press selection, verify scroll and selection do not compete during the same gesture
- [ ] Trigger haptics from the snapped point identity, not from raw drag coordinates
- [ ] Clamp floating overlays at horizontal edges and flip them below the point when top space is insufficient
- [ ] Add pure layout/gesture tests for any new chart interaction helper

### Rule Addition (if applicable)

No new rule file was added. The existing chart/shared-view patterns were sufficient once the interaction math was extracted.

## Lessons Learned

- `chartOverlay + ChartProxy` is the right level of control when product UX needs exceed the default chart selection APIs.
- Shared interaction math is easier to verify with small pure tests than by relying on UI-only validation.
- Gesture precision bugs often come from competing scroll state and feedback triggers, not only from coordinate conversion.
