---
tags: [wellness, flow, quality, swiftui]
date: 2026-10-28
category: review
status: reviewed
---

# SwiftUI quality review — Wellness flow

Read-only source review of `main...HEAD` and current unstaged native changes. No build, test, simulator, or visual capture was run for this review. Findings below are source-level risks, not a native visual pass.

## Final source delta through `6c1d3f77`

Compared only the native source changes after the `8ce1b517` review and consulted `quality-apple.md` and `quality-astra.md`. **Current source findings: P1 0, P2 0, P3 0 new.** This is a bounded source verdict, not final native UI approval. Parent-reported phone/iPad results were not independently run here; the `6c1d3f77` health delta and Duo verification were still in progress at review time.

- Stable accessibility identifiers now sit on the intended metric links (`WellnessView.swift:458-463`, `WellnessBodySummaryCard.swift:75-81`) and sleep/forecast/evidence headings or rows, avoiding the former container-level identifier ambiguity. Source alone does not establish VoiceOver traversal quality.
- Watch data shows `summary.date` and uses a leading vertical metric layout at accessibility text sizes (`WatchPostureSummaryCard.swift:63-105`). The assessment heading also drops its icon at accessibility sizes (`WellnessView.swift:614-621`). Native nonempty Watch layout remains unverified by this reviewer.
- The non-Desert hero ring follows `AppTheme` colors (`WellnessHeroCard.swift:109-120`); unused hero inputs were removed from declaration and caller. The score link, evidence rows, and detail destination remain intact.
- The earlier Astra **P2** temperature-context finding is resolved at source level: `WellnessMetricCard.swift:92-98` labels the wrist-temperature value as a change from personal baseline, with en/ko/ja catalog entries. The observed sleep bars now scale to `max(600, actual sample maximum)` (`WellnessSleepSummaryCard.swift:28-30,81-85`), removing the over-600-minute saturation. Astra's remaining wide-capsule visual polish note is P3 and was not reassessed from pixels here.

## Final targeted delta review after `8ce1b517`

`WellnessView.swift:129-135` now renders an empty `WellnessBodySummaryCard(cards: [], comparisons: [:], onAdd: openBodyRecord)` when `hasSummaryData` is false. `WellnessBodySummaryCard.swift:53-59` always renders the identified Add Body Record button, so the previously residual records-only manual-entry issue is resolved at source level. **Residual P1/P2 findings from this review: 0.** The initial and intermediate findings below are retained as history, not as currently open findings. The parent reported a generic build pass and two unit suites in progress; this reviewer did not run or verify those results. UI tests and native visual captures remain unverified, so this is not a native UI quality pass.

## Delta review after `8085e875`

Read-only recheck of the prior findings and their targeted fixes. Native build was in progress upstream; unit/UI tests and visual captures had not run when this review was written. The sections below retain the initial findings as an audit trail. Current status:

| Initial finding | Status after delta | Evidence |
|---|---|---|
| P1 posture/injury-only records hidden | **Resolved for posture/injury reachability; one related P1 remains** | `WellnessView.swift:112-148` now places injury and posture children outside `hasSummaryData`. See residual below. |
| P1 comparison excludes day -8 | **Resolved** | `WellnessBodyComparison.swift:27-34` now selects latest valid sample through the day -7 cutoff; `WellnessBodyComparisonTests.swift:50-89` includes day -8 and too-recent examples. |
| P2 weight/body-fat trend reversed | **Resolved** | `WellnessViewModel.swift:304,335` sorts samples by ascending date before mapping values; new ViewModel tests cover order. |
| P2 posture score identity incomplete | **Resolved at source level** | `WellnessView.swift:607-622` includes latest ID, score, and front/side metric JSON in `.task(id:)`. |
| P2 unmeasurable older posture numeric ring | **Resolved** | `WellnessView.swift:737-776` branches on measurable metrics and counts only measured metrics. |
| P3 hero VoiceOver narrative/date absent | **Resolved at source level** | `WellnessHeroCard.swift:109-112` adds accessible value with narrative and evaluation date. |

### Intermediate residual P1 (resolved by `8ce1b517`) — Body record entry was omitted in records-only state

At `8085e875`, `DUNE/Presentation/Wellness/WellnessView.swift:119-129` rendered `WellnessBodySummaryCard` only when `hasSummaryData` was true. The records-only fixture has no HealthKit/body summary data, so the new UI test expected a button absent from the tree. Commit `8ce1b517` adds the empty body card with `onAdd: openBodyRecord` in the `else` branch, resolving this source-level mismatch. The targeted UI test still needs execution.

No other prior P1/P2 finding remains on source inspection. Build/test/visual outcomes remain unverified here.

## Findings

### P1 — Existing posture or injury records disappear when health metrics are empty

`DUNE/Presentation/Wellness/WellnessView.swift:73-88` chooses the global empty state using only `physicalCards`, `activeCards`, and `wellnessScore`. The two independent `@Query` children for injury and posture (lines 113-146) live only in the `else` branch. A user who has photo assessments or injury records but no current HealthKit/body metrics sees “No Wellness Data” and cannot reach those records from the Wellness flow. Make the health-data empty state a section within the flow, or include the independent record presence in the root decision while keeping `@Query` isolated in child views. Verify seeded posture-only and injury-only states.

### P1 — Body comparison excludes valid observations older than seven days

`DUNE/Presentation/Wellness/WellnessBodyComparison.swift:27-32` admits only samples on the calendar day exactly seven days before the latest measurement. The approved plan says to use an observation **at least seven days before** each metric's latest measurement, and the query already collects 40 days. If a user measured eight days ago but missed day seven, `No comparison record` appears despite a valid older sample. Select the most recent valid sample with `date <=` the seven-day cutoff (choose calendar-day or exact-time semantics explicitly), and update `DUNETests/WellnessBodyComparisonTests.swift:50-69`, which currently codifies the exclusion.

### P2 — Weight and body-fat trend lines run newest-to-oldest

`DUNE/Presentation/Wellness/WellnessViewModel.swift:304,335` maps the HealthKit history directly into `sparklineData`, and `WellnessMetricSparkline.swift:41-45` plots that order left-to-right. `BodyCompositionQueryService.swift:283-299` fetches these samples with descending start-date order, so live weight/body-fat trends show the newest measurement on the left and the oldest on the right. Sort history ascending by date before constructing those sparkline arrays; verify first/last points against dated fixture records.

### P2 — Posture score update is keyed to metrics array alone

`DUNE/Presentation/Wellness/WellnessView.swift:605-608` uses `.task(id: records.first?.allMetrics)` to push the latest record's `overallScore` into the Wellness score. A newly inserted latest record can have an identical metrics array but a changed `overallScore`, or the score can be corrected while metrics stay equal; the task then does not rerun, leaving the hero score stale. Use an identity that includes latest record ID and score (and the measurability state), then verify replacement/correction updates.

### P2 — Unmeasurable older posture records display a numeric ring

`DUNE/Presentation/Wellness/WellnessView.swift:723-746` always renders `overallScore` for the two older records, while the latest summary correctly checks whether any metric is measurable at lines 638-659. For an unmeasurable record the row presents a score/ring that looks observed. Apply the same measurability condition in the history rows and show the “Unable to measure” state instead.

### P3 — Hero score-link VoiceOver label omits its interpretation

`DUNE/Presentation/Wellness/Components/WellnessHeroCard.swift:109-111` overrides the link's children with a score/status label and generic hint, so VoiceOver does not read the visible narrative and evaluation time inside that link. Include the narrative and date in the accessible value or leave the children exposed with an intentional combined label. Confirm with accessibility inspection; this is not a visual finding.

## Checked without finding a source-level blocker

- `WellnessView` keeps `@Query` inside injury/posture child views and uses eager `VStack` rows with `.scrollBounceBehavior(.basedOnSize)`.
- Root navigation destinations remain outside conditional branches; tab-root `NavigationStack` is not duplicated.
- Metric card values use flexible widths and accessibility size switches the health/body grids to one column. Actual fit on iPhone/iPad/Duo and large Dynamic Type still requires fresh captures.
- Header navigation uses `CardNavigationHeader`'s 44-point minimum where specified. The hero header uses `minimumHeight: 0`, but the whole score summary is a link with a content shape; confirm hit geometry in a simulator rather than inferring failure from source.
