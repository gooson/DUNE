---
tags: [training-load, calendar, dst, ui-test, design-map]
category: testing
date: 2026-11-21
severity: important
related_files:
  - DUNE/Presentation/Activity/Components/TrainingLoadWeekTotals.swift
  - DUNE/Presentation/Activity/Components/TrainingLoadChartView.swift
  - DUNETests/TrainingLoadWeekTotalsTests.swift
  - DUNEUITests/Regression/ChartInteractionRegressionUITests.swift
related_solutions:
  - docs/solutions/testing/2026-03-08-training-load-daily-volume-scroll-history.md
---

# Solution: R07 equal seven-day training load comparison

## Problem

The earlier summary included eight calendar dates in its current period and seven in its previous period, so its percentage compared unequal windows. The wording “This week” also suggested a calendar week although the calculation was rolling.

### Root Cause

The current filter began at today minus seven days and had no exclusive end at tomorrow. The cached summary was tied to point count, so new daily values with the same count could remain stale.

## Solution

Use calendar-day boundaries for today plus six preceding days and the seven dates before that. End at tomorrow 00:00 exclusively. Calendar date arithmetic preserves day buckets through DST. Display the latest period as “Last 7 days” / “최근 7일” / “直近7日間”. Show a 100% decline when current total is zero and previous is positive; omit comparison only when both totals are zero. Recalculate cached chart summaries on same-count value changes while keeping scroll position when the date domain is unchanged.

### Changes Made

| File | Change | Reason |
|---|---|---|
| `TrainingLoadWeekTotals.swift` | Two disjoint seven-day windows | Correct date arithmetic and future exclusion |
| `TrainingLoadChartView.swift` | Correct zero case, label, cache update | Keep visible comparison in sync with values |
| Unit/UI tests | DST, boundary, zero, value update, A06 label | Prevent regression and preserve an actual capture |

## Verification and actual map

- Unit selector: `DUNETests/TrainingLoadWeekTotalsTests`; passed with both March and November DST parameters. The A06 UI assertion verified the displayed label. Same-count view invalidation was checked during source review.
- UI selector: `DUNEUITests/ChartInteractionRegressionUITests/testTrainingLoadChartShowsRollingSevenDaySummaryAndCapturesA06()`. A supplied passed native screenshot is preserved in `docs/design/phone-design-map/actual/r07-training-load-seven-days-2026-11-21/`.
- iPhone evidence: iPhone 18 Pro, iOS 27.2, Korean/light, code `8a0d632d7`. `evidence.json` records the original attachment, SHA-256, and visible scope.
- iPad A06 and Duo folded/open A06 await new captures. Earlier images are historical evidence only.

## Prevention

Define rolling comparisons with explicit inclusive start and exclusive end dates. Include a zero-current/positive-previous case, a DST boundary, and unchanged count with changed values in focused tests. Record device and source revision for each native capture.

## Lessons Learned

Date filters that look one week apart can produce unequal counts when both ends are inclusive. Data count is not a sufficient cache key for a daily chart.
