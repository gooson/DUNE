---
tags: [swiftui, charts, metric-comparison, dynamic-type, accessibility, native-evidence]
category: testing
date: 2026-11-05
severity: important
related_files:
  - DUNE/Presentation/Wellness/MetricComparisonView.swift
  - DUNEUITests/Full/WellnessRegressionTests.swift
related_solutions:
  - docs/solutions/testing/2026-10-28-wellness-flow-accessibility-and-native-evidence.md
---

# Shared metric dates, readable marks, and bounded native menu tests

## Problem

The metric comparison sheet repeated its date range in two cards. Both plots needed the same exact date domain while keeping their own units and value scales. Its accessibility menu required full selected labels and reachable options. In fresh native tests, nesting a Picker inside a Menu removed option identifiers. The menu virtualized lower options and reopened at its first page; an index-bound global query also became stale. After those causes were corrected, a fixed short scroll could not return from the lower MAX chart to the period control.

Light category colors used for essential chart marks and selected menu text measured 2.54:1 against the card. An ordinary mock launch also left history metadata on a live HealthKit path: the chart stayed loading. No task trace identified the exact suspended await.

## Solution

Compute one ClosedRange in the comparison parent and pass that value to both chart X scales. Display its date range once. Keep both independent metric bindings/ViewModels, their units and Y scales, all five periods, native dismissal, empty/error/retry states, and original resolved metric icons. Reuse the existing palette for a compact comparison header.

At accessibility sizes, use direct native Menu Buttons with stable option IDs, selected checkmarks, and a wrapping title/value label. Ordinary size retains the native Picker. Use TextSecondary for menu labels. For light appearance only, darken the original category mark color once before the Chart closure; dark appearance retains the original mark color.

The targeted tests use the existing long-history fixture to isolate history metadata as well as collection data. Reveal popup options only inside the actual clipped collection ancestor, using accessibility-bound elements. Missing options are scanned from the observed first-page position. Returning to Month uses its live frame and the visible comparison viewport, at most twelve bounded gestures, and succeeds only for a unique, fully visible, enabled, hittable control. The phone Period picker could lie inside the scroll frame while being covered by native navigation; its separate normal-only helper centers the live control even in that contained-but-unhittable state. Then assert the changed single date, selected period, and Done return.

## Verification

Five effective cases passed across phone, iPad, Duo closed/open and closed dark/MAX, with31 independently reviewed original PNG/AX pairs. The same final app bytes are used across test sources14f9d4aa, bfd03486 and89031bea. The later normal Period helper ran on phone/iPad; earlier Duo contract evidence is reused with explicit source closure. All10 raw archives retain historical13 executed/6 passed/7 failed counts, and failed aggregates are never promoted. English/W-to-M behavior is observed; no every-locale, live HealthKit or VoiceOver claim is made. On iPad, the full second plot is shown in its week capture, while the month checkpoint reaches its picker. No model/query change required a redundant unit/full-suite run.

## Prevention

- Inspect real menu AX before assuming nested IDs or restored scroll positions.
- Distinguish missing virtualized rows from offscreen instantiated rows; avoid global index-bound frame enumeration.
- Derive scroll travel from the current clipped viewport without increasing attempt or time limits.
- Compare generated map cards by their embedded screen ID; grouped rendering order can differ from the raw catalog. Preserve other card entries and board pixels.
- Verify actual light essential-mark contrast; preserve category identity separately from mark readability.
- Reuse passed cases only after explicit unchanged app/test/dependency closure. Preserve the enclosing failed result and historical failures.

## Lessons Learned

One shared date range does not mean a shared value scale, and correlated plots do not establish cause. A selected-test pass, native visual approval, source identity, and complete evidence archive are separate claims. Rule promotion is proposal-only; no .claude source was modified.

The solution changes MetricComparisonView.swift and H04-local WellnessRegressionTests.swift helpers; the native gallery and map updates carry the corresponding evidence. A failed first-launch AX handshake is separate from H04 behavior: the same attempt later exposed complete Wellness AX/PNG, and the next run entered H04. No precise host-lock/startup root cause was proved.
