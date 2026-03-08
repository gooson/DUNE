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
  - DUNE/Presentation/Activity/TrainingReadiness/Components/ReadinessTrendChartView.swift
  - DUNE/Presentation/Activity/TrainingReadiness/Components/SubScoreTrendChartView.swift
  - DUNE/Presentation/Activity/Components/TrainingLoadChartView.swift
  - DUNE/Presentation/Activity/TrainingVolume/Components/StackedVolumeBarChartView.swift
  - DUNE/Presentation/Activity/TrainingVolume/ExerciseTypeDetailView.swift
  - DUNE/Presentation/Activity/WeeklyStats/Components/DailyVolumeChartView.swift
  - DUNETests/ChartSelectionInteractionTests.swift
  - DUNEUITests/Regression/ChartInteractionRegressionUITests.swift
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

The original shared charts relied on `chartXSelection` plus a fixed top overlay. Later fixes also diverged into per-screen gesture patches, which made scroll/selection cleanup and stale state handling inconsistent across chart types.

## Solution

Replace the fixed `chartXSelection` interaction with a shared `chartOverlay + ChartProxy` selection pipeline, then keep the actual long-press capture inside a reusable `UIViewRepresentable` recognizer so scroll, selection, cleanup, and overlay placement all share one contract.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Charts/ChartSelectionInteraction.swift` | Added shared nearest-point snapping, anchor conversion, overlay clamp/flip, and selection cleanup helpers | Centralize interaction math and stale-state cleanup |
| `DUNE/Presentation/Shared/Charts/ChartSelectionOverlay.swift` | Added `FloatingChartSelectionOverlay`, `ChartLongPressSelectionRecognizer`, and `scrollableChartSelectionOverlay(...)` | Reuse one long-press + overlay contract across charts |
| `DUNE/Presentation/Shared/Charts/*.swift` + `DUNE/Presentation/Activity/**/*.swift` | Migrated 12 selection charts to the shared modifier | Keep shared/activity interaction behavior aligned |
| `DUNETests/ChartSelectionInteractionTests.swift` | Added pure tests for snapping, layout, and selection cleanup | Lock down common interaction state independently from UI rendering |

### Key Code

```swift
ChartLongPressSelectionRecognizer(
    minimumPressDuration: ChartSelectionInteraction.holdDuration
) { state, location in
    ChartSelectionInteraction.handleLongPressSelection(
        state: state,
        location: location,
        proxy: proxy,
        plotFrame: plotFrame,
        selectionState: $selectionState,
        selectedDate: $selectedDate,
        scrollPosition: scrollPosition
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

When a chart needs custom long-press selection UX, do not start from a fixed top overlay, raw `chartXSelection`, or screen-local gesture patch. Move the interaction math into a shared helper, snap to the nearest domain model point, and clear stale selection state whenever scrolling changes the visible range.

### Checklist Addition

- [ ] If a chart uses long-press selection, verify scroll and selection do not compete during the same gesture
- [ ] Verify selection 종료 후 scroll resume, scroll-after-selection cleanup, and no snap-back to old visible range
- [ ] Trigger haptics from the snapped point identity, not from raw drag coordinates
- [ ] Clamp floating overlays at horizontal edges and flip them below the point when top space is insufficient
- [ ] Add pure layout/gesture tests for any new chart interaction helper

### Rule Addition (if applicable)

관련 규칙을 다음 문서에 반영했다.

- `.claude/rules/testing-required.md` — chart gesture lifecycle seeded 검증 체크리스트
- `.claude/rules/documentation-standards.md` — solution 문서 final implementation 동기화 규칙

## Lessons Learned

- `chartOverlay + ChartProxy` is the right level of control when product UX needs exceed the default chart selection APIs.
- Shared interaction math is easier to verify with small pure tests than by relying on UI-only validation.
- Gesture precision bugs often come from competing scroll state and feedback triggers, not only from coordinate conversion.
