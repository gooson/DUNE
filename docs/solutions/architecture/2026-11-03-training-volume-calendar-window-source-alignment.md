---
tags: [date, calendar, dst, query, training-volume, healthkit]
category: architecture
date: 2026-11-03
severity: important
related_files:
  - DUNE/Domain/UseCases/TrainingVolumeAnalysisService.swift
  - DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift
  - DUNE/Presentation/Activity/TrainingVolume/ExerciseTypeDetailViewModel.swift
  - DUNETests/TrainingVolumeAnalysisServiceTests.swift
  - DUNETests/TrainingVolumeViewModelTests.swift
  - DUNETests/ExerciseTypeDetailViewModelTests.swift
related_solutions: []
---

# Solution: Align training-volume calendar windows with their source queries

## Problem

### Symptoms

The weekly goal could count eight local dates as a seven-day period, while the displayed previous-period totals could omit HealthKit workouts from its first morning. Exercise-type details could also disagree with the overview. A midnight daylight-saving transition could shift day bounds or leave a later daily bucket without its workout.

### Root Cause

The legacy analyzer's current window starts at D−N and includes today, while the previous window has N dates. A rolling 2N-day HealthKit query starts at the current time of day rather than the first displayed day's start. Calendar date arithmetic can preserve 01:00 across a midnight DST transition even when the target date began at 00:00; advancing an unnormalized daily cursor can likewise miss day-start dictionary keys.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| TrainingVolumeAnalysisService.swift | Added explicit inclusive N-date bounds, carried one calendar through aggregation, and normalized each advanced daily bucket. | Keep query, summary and chart dates coherent across DST. |
| TrainingVolumeViewModel.swift | Capture one reference and fetch the exact previous-start through reference range. | Include both HealthKit and manual records on the first previous date. |
| ExerciseTypeDetailViewModel.swift | Apply the same bounds to summary and trend, keeping the rolling 2N-day fetch for the newest-ten list. | Maintain route coherence without truncating recent sessions. |
| Focused domain and view-model tests | Cover 7/30/90/180-day ranges, boundary records, a true seven-date goal, Santiago DST, and a range-filtering recent-session mock. | Exercise real boundaries and query behavior. |
| ChartInteractionRegressionUITests.swift | Expect D−13 through D−7 for the previous 1W caption. | Preserve the actual date-range and goal assertions. |

### Key Code

For N days and one captured reference instant: currentStart is the first instant of D−(N−1); previousStart is the first instant N calendar days before currentStart. Include previousStart ≤ date < currentStart and currentStart ≤ date ≤ reference. Normalize each computed local date to `calendar.startOfDay(for:)`, and normalize every advanced bucket cursor. Calendar arithmetic, not fixed 24-hour subtraction, handles transitions.

The existing `analyze(...referenceDate:)` entry retains its legacy D−N / D−2N instants for A05; both paths share the aggregation and linked-record deduplication body. Its existing eight-current-bucket test remains. This is an A06 and linked exercise-type contract, not a global A05 period migration.

## Prevention

### Checklist Addition

- [ ] Compare displayed bounds, actual range query, manual filtering, chart buckets, and detail consumers using the same captured reference and calendar.
- [ ] Test both sources at the first previous morning, just outside both ends, and across a midnight DST transition using an explicitly injected calendar.
- [ ] Make range-query mocks filter inputs so a narrower query cannot pass a recent-history test accidentally.
- [ ] Check other callers' historical semantics before changing a shared analyzer default.

### Rule Addition (if applicable)

Proposal only: consider adding the first checklist item to a future calendar/query review rule after broader review. No rule or `.claude` file was changed.

## Lessons Learned

A period label implies a data contract across retrieval, aggregation and presentation. Equal numbers of local dates and stable day starts need explicit treatment; a rolling lookback and calendar period are different useful contracts.

## Verification and limits

Three targeted unit suites passed 34 tests on aeabdd7d; application and model inputs are unchanged through e206c0f3, whose two changes are capture tests. On e206, the iPad normal overview case passed 1/1 and the explicitly approved dark, normal-text Goal case passed 1/1. Original first group failed at compilation with no executed tests; the later group had five passes and one Goal failure, and those results remain preserved. Phone normal/MAX passed 2/2 at e206 and Duo closed passed 1/1 with four strict checkpoints and actual 0°/LCD. Duo open e206 failed before entry; after a reviewed test-only explicit root scroll owner change retaining its 8/3 limits and assertions, the same-ID single conditional retry at 844dacaa passed 1/1, with four strict checkpoints and actual 180°/LCD-1. App sources are unchanged across e206/844; older captures are scoped source evidence, not fresh 844 runs. All negative histories remain. The native quality gate passed with notes, and four actual rows/boards were published without changing other rows or Watch. Historical before device/revision/AX/pose uncertainty, a pre-existing donut unit-label mismatch, and partial MAX visual coverage remain explicitly bounded; no full local, live VoiceOver or fold continuity claim is made.
