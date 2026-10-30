# Siri health query native UI: iPhone visual review

Reviewed 2026-10-30. Evidence: `siri-native-iphone-reviewed/manifest.json` and `overview.png`, plus individual native screenshots `T17-health-qa-browse`, `SQ00-no-data`, `SQ02-workoutSummary`, `SQ07-bodyTrend`, `SQ08-sleep`, `SQ09-condition`, `SQ10-metricComparison`, `SQ11-workoutComparison`, `SQ12-software-keyboard`, `SQ13-report-preview`, and `SQ14-longAnalysis`. The overview was used to inspect SQ01–SQ14 together. These are fresh 402 × 874 pt iPhone 18 Pro captures from the actual DEBUG fixture app at source commit `2282ab876808f2dd52ce959d7a05e352d92ffb81`; the values are synthetic and the screenshots are not Siri system UI.

## Assessment

The large result numbers, units, selected period, and card titles are generally readable. Workout, body, sleep, condition, and comparison results have distinguishable information hierarchy. SQ08 accurately labels the colored bar as **recorded sleep stage totals**, rather than suggesting a time ordered night timeline. SQ00 identifies a successful empty result and offers a period change. The SQ12 search field and action remain visible above the software keyboard. SQ13 preview includes the report period and an explicit notice that body measurements and personal notes are excluded. The floating navigation header is intentional; content that continues below the screenshot is scrollable, so the screenshot boundary alone is not evidence of inaccessible content.

## Findings

| Priority | IDs | Observation and action |
|---|---|---|
| P2 | SQ10 | **Aggregate comparison dates can be read as sample dates.** “Workout Records 3” and “Active Duration 1:55:00” are totals for the selected Oct 1–30 period, yet both current cells show only Oct 24; their previous cells show Sep 16. Readers may attribute the totals to those single dates. Label each side with its actual aggregation window, or remove the per-cell date for aggregates and show the two compared windows above the cards. Keep sample dates on genuinely per-record comparisons such as SQ11. |
| P2 | SQ02, SQ08, SQ10, SQ13 | **Duration chart axes expose raw numeric units.** “Workout Duration by Day” has ticks around 1,000–3,000 while the summary uses `1:55:00`; “Sleep” has ticks around 10,000–30,000 while the result uses `15:30:00`. The chart does not identify those numbers as seconds. Format ticks as time (for example, minutes or hours) and state the unit in the axis or chart title. Preserve the actual plotted values. |
| P3 | SQ07, SQ09, SQ02, SQ08, SQ13 | **Top chart tick labels are cut at the plot's top edge.** The first `75`/`100` or `3,000`/`30,000` tick is partially covered in the individual captures. Give the chart's plot and axis labels enough top inset. This is limited to tick labels; the main result values are visible. |
| P3 | SQ07 | **The body trend leaves the actual change to inference.** The card shows 68.4 kg and “Previous: 69.2 kg,” but the planned comparison result was to state the change. Add a signed `−0.8 kg` summary with both sample dates, keeping the chart as supporting evidence. |
| P3 | SQ13-report-preview | **Preview reads as a repeated plain-text report beneath the visual report.** The notice about excluded fields is useful, but the second “Workout Report” block repeats numbers already in the card. Consider a separate preview sheet or clearer “Content to share” boundary so users can distinguish the share payload from the on-screen summary. The capture shows scroll continuation, not confirmed clipping. |

No P1 visual finding from these captures. The known Browse period tap failure and Share mini popover without a header Close affordance are interaction/test findings under separate investigation; these screenshots do not establish their resolution. The share popover actually opened, so this review does not characterize it as a failed share action.

## Verification limits

The manifest reports native fixture capture and the passed all-kind and no-data captures; this review is visual only. Native Siri invocation/host UI and spoken answer, VoiceOver reading order and labels, maximum accessibility text size, iPad, Duo folded/unfolded layouts, and live HealthKit provenance remain unverified here. Source and timestamp text visible in SQ06/SQ12 is plausibly ordered, but a screenshot cannot prove its underlying data provenance or freshness calculation.
