---
tags: [swiftui, injury-statistics, chart, recovery, accessibility]
category: general
date: 2026-11-06
severity: minor
related_files: [DUNE/Presentation/Injury/InjuryStatisticsView.swift, DUNEUITests/Full/WellnessRegressionTests.swift]
related_solutions: []
---

# Solution: Clarify injury statistics while preserving computed values

## Problem

### Symptoms

- Total, Active, Avg Recovery, and Longest had similar visual weight, making the overview harder to scan.
- The frequency chart axis label color was weak in the Light theme.
- The redesign still had to use the existing statistics, including absent recovery values and an empty frequency section.

### Root Cause

Four uniform `StatCard`s flattened the information hierarchy. The chart axis used a theme sand color that was less legible on the updated surface.

## Solution

### Changes Made

| File | Change | Reason |
| --- | --- | --- |
| `DUNE/Presentation/Injury/InjuryStatisticsView.swift` | Put Total and Active together in a caution-tinted hero; keep Avg Recovery and Longest as supporting cards. | Lead with record count and current state. |
| Same | Give section headings symbols and use secondary text color for chart axis labels; darken active count in Light appearance. | Improve scan order and contrast. |
| Same | Keep existing optional average/longest formatting (`—`) and show frequency only when body-part data exists. | Preserve the original data semantics and empty state. |
| `DUNEUITests/Full/WellnessRegressionTests.swift` | Check seeded 2 total, 1 active, 10d average/longest, Knee/Shoulder frequency, chart presence, and return. | Detect changed calculations or route regressions. |

### Key Code

```swift
Text(statistics.averageRecoveryDays.map { "\(Int($0.rounded()).formattedWithSeparator)d" } ?? "—")
Text(statistics.longestRecoveryDays.map { "\($0.formattedWithSeparator)d" } ?? "—")
```

The view consumes `InjuryStatistics`; this change did not alter its computation or invent values for missing recovery data.

## Prevention

### Checklist Addition

- [ ] Compare every displayed statistic with the seeded records, including nil recovery and empty frequency cases.
- [ ] Inspect chart axes and count colors against both Light and Dark surfaces before final capture.

## Lessons Learned

A clearer statistics hierarchy can be built around the existing computed model. Value checks and chart evidence should accompany the visual change so presentation cannot hide a data regression.

## Validation

Normal iPhone, iPad, Duo closed/open and closed Duo maximum text were checked with the relevant selected methods and independent PNG/AX review. The [native gallery](../../design/full-redesign-map/review/h11-injury-statistics-native-2026-11-06/index.html) records each executed source, individual result, fixture, paired assets, preserved failures, and remaining P3 notes. No full-suite, Dark, physical-device or VoiceOver claim is made.
