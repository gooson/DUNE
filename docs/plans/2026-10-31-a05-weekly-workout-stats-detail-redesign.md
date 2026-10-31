---
topic: A05 weekly workout statistics detail redesign
date: 2026-10-31
status: planned
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-29-weekly-stats-period-alignment.md
  - docs/solutions/general/2026-03-29-weekly-stats-lastweek-referencedate.md
  - docs/solutions/testing/2026-03-08-training-load-daily-volume-scroll-history.md
related_brainstorms: []
---

# Implementation Plan: A05 Weekly Workout Statistics Detail

## Context

The existing detail has the correct real workout aggregation, period switch, daily chart and exercise breakdown, but presents the five current values as plain shared cards and does not show the previous period's actual values together. A05 improves this one destination's hierarchy: an opaque period-aware hero with all five current metrics, then four aligned previous-period comparison rows under one true date caption. It retains the existing chart and breakdown behavior. The recovered browser prototype is layout guidance only; none of its figures, percentages or history are production inputs.

Planning reference is `672d5fdb`. The inspected L03 sources match the original main source hashes: detail `225d33fa0ce8dee0f8f510dd3b287a7fb5658bec4321f4ea89d61c5e4e9264c8`, VM `5e6de32a439902739ae5da96a636934db45028a8aef9610bfe467d0a75bf8787`, model `e85f82e3ff6d18d9e9abdf795e381147a208de9f19b655e2e439595812258bcb`, service `4aff0a76d6a4fb1ad8c6aba26f30e0fb03f251d4691494e27b17145143e5004c`. Recheck these at A05 branch entry.

The A05 branch was created at `672d5fdbcbc8eca70069ca3a8b328ed18f0c501f`; all four hashes above matched before any App edit. The [separate layout map](../design/layout-map/activity-weekly-stats-detail-a05.html) and [DUNE light/dark theme proposal](../design/theme-map/themes/dune-weekly-stats-detail-a05.html) are browser contracts, not native captures.

## Requirements

### Functional

- Keep the Activity section/header links to the same detail route, native Back, and the original three choices in order: This Week, Last Week, This Month. They are existing rolling seven/thirty-day windows, not calendar week/month buckets.
- Display all five **current** `ActivityStat` values: strength volume, duration, calories, active days and sessions. Use each `stat.icon` (`scalemass.fill`, `clock.fill`, `flame.fill`, `calendar`, `figure.strengthtraining.traditional`), `stat.title`, value, unit and existing optional change semantics. Keep `activity-weeklystats-summary-grid` and `activity-weekly-stat-value-{id}` / `activity-weekly-stat-change-{id}` reachable.
- Show four previous-period rows for volume, duration, calories and sessions only. Use the same corresponding `ActivityStat.icon` in the same leading position in every row. `activeDays` remains current-only; its domain delta does not justify a fifth new comparison row.
- Derive previous values only from `comparison.previous`: manual strength volume from `exerciseTypes.totalVolume`, duration in minutes, calories, and session count. Follow current summary formatting and absence conventions. `previous == nil` gets an unavailable state. An actual zero previous denominator or missing previous data never becomes a fabricated 0% change. Existing current change strings remain governed by the VM.
- Put a single localized, locale-aware date caption under the comparison heading using `previous.startDate` / `previous.endDate`; do not repeat the range in each row. Do not compute a new date range from `Date()` in presentation.
- Keep `DailyVolumeChartView` intact: Duration/Sessions/Volume (kg), chart heading, selected metric, long-press selection, scroll to historical days, visible-range label/probe, period `.id` and chart height/AX menu behavior. Keep `ExerciseTypeBreakdownView` and its real activity-type icons/colors, duration shares, session counts, percent bars, sorting and empty copy.
- Preserve loading, error and true empty states, pull-to-refresh, scene-active/Health/calendar revisions, cancellation and request identity in the existing loading pipeline.

### Non-functional

- Native opaque hero with palette ink and original metric icon colors; text and icons remain legible in light/dark and maximum Dynamic Type. Keep activity/fatigue semantic colors distinct from the hero surface. No mock percentages, invented prior workouts, or generic replacement symbols.
- Constrain readable body width without hiding the fifth metric or lower content. Preserve one scroll path and reachable native controls on phone, iPad and Duo folded/open. No Watch scope.
- Prefer private presentation structs/functions in `WeeklyStatsDetailView.swift`. Do not change `WeeklyStatsGrid`/`ActivityStatCardView` used on Activity root, the VM, domain models, query service or analysis math.

## Approach

Compose a private A05 hero from the existing `viewModel.summaryStats` and selected period. A private previous comparison section receives `PeriodComparison.previous` and the matching current `ActivityStat`s for icons, labels and units. Use `ScoreHeroPalette`'s opaque surface/ink pattern and existing DS spacing, with normal and AX layouts. Keep the period picker and all child chart/breakdown Views wired to the same existing bindings and data.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| Change shared `WeeklyStatsGrid` | Less local code | Changes Activity root and other consumers | Reject |
| Add previous metrics and percentages in VM | Central formatting | Changes data contract, invites an unrequested active-days comparison | Reject |
| Private detail-only hero and comparison section | Scoped, uses actual model and source icons | Needs careful formatting/AX verification | Choose |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `DUNE/Presentation/Activity/WeeklyStats/WeeklyStatsDetailView.swift` | Modify | Detail-only opaque hero, four prior rows, single prior period caption, responsive composition; retain loading and child bindings. |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | Targeted addition only if needed | Keep `testVisualAuditWeeklyStatsDetailDirect` for source-matched baseline and after capture; add one focused actual-prior/AX contract if existing selectors cannot prove it. |
| `docs/design/layout-map/activity-weekly-stats-detail-a05.html`, layout index/README | New/modify | Explicit layout and state contract before App change. |
| `docs/design/theme-map/themes/dune-weekly-stats-detail-a05.html`, manifest/index/README | New/modify | Illustrative opaque hero direction and theme-map generator/check. |
| `docs/design/phone-design-map/actual/index.html` plus new A05 PNGs | Modify after native capture | Source-matched actual phone, iPad, Duo folded/open after states only. |

Protected read-only sources: `WeeklyStatsDetailViewModel.swift`, `TrainingVolume.swift`, `TrainingVolumeAnalysisService.swift`, `DailyVolumeChartView.swift`, `ExerciseTypeBreakdownView.swift`, `WeeklyStatsGrid.swift`, `ActivityStat.swift`, chart selection machinery and Activity root route.

## Implementation Steps

### Step 1: Freeze original source and actual before states

- **Files**: A05 ignored evidence and formal design maps only.
- **Changes**: Confirm the four source hashes and create the separate layout/theme maps before App edits. Capture the original detail from frozen `672d5fdb` with `ActivityExerciseRegressionTests/testVisualAuditWeeklyStatsDetailDirect`; record build revision, seed, theme, locale, Dynamic Type, device and selected period. Historical `A05.png` files from `443a32ca` are reference only, never current before proof.
- **Verification**: One source-matched route/capture and inspect whether the fixture presents actual summary, previous and daily history; if not, report its state rather than labeling it ready.

### Step 2: Implement the scoped native composition

- **Files**: `WeeklyStatsDetailView.swift`.
- **Changes**: Keep `@Query`, `loadInput`, `.task(id:)`, refresh handlers and picker untouched. Replace only the detail summary presentation with a five-metric private hero, then render a four-row previous section from `comparison.previous`. Keep the one date caption coupled to that summary. Retain child chart/breakdown arguments, `.id`, transitions and accessibility identifiers. Use localized existing copy where possible; if new user-facing strings are necessary, translate en/ko/ja and run the catalog formatter/check.
- **Verification**: Source diff and Swift parse; confirm no protected source or retrieval change.

### Step 3: Targeted behavior and actual maps

- **Files**: one existing focused UI test only if needed; actual map and captured PNGs.
- **Changes**: Verify current hero values and a real previous-period row are distinguishable without assuming prototype literals; compare one chosen previous value with the seeded `PeriodComparison` fixture or a source-derived oracle, including nil/zero handling. Keep existing chart tests for period/selection/history. Capture affected normal/dark/AX and four form factors at the same source revision, with comparison rows and lower breakdown visible where needed.
- **Verification**: Exact selectors below; stop after the changed behavior and affected platform states are demonstrated. Build and native evidence are pending at plan time.

## Edge Cases

| Case | Handling |
|---|---|
| No previous summary | Show an unavailable marker/copy; no date caption or percent. |
| Previous summary with zero value | Show a real zero only where that metric truly counts zero; keep percent absent because denominator is zero. Manual strength volume with no valid volume retains current `—` convention. |
| Current no workouts, loading or error | Preserve original branches and existing no-data copy; do not fill the hero from prototype figures. |
| Last Week selected | Use VM's actual shifted reference date, then `comparison.previous` for the earlier window. Do not derive calendar labels from the picker title. |
| Dynamic Type and narrow Duo | Wrap title/value rows, stack metric cells and comparison contents, keep chart menu picker and all five values reachable. |
| HealthKit/manual overlap | Continue service deduplication; view only formats aggregates. |

## Testing Strategy

- **Baseline/route**: `DUNEUITests/ActivityExerciseRegressionTests/testVisualAuditWeeklyStatsDetailDirect` on unchanged original source and again after A05, with provenance and actual PNG pair.
- **Existing chart regression**: `DUNEUITests/ChartInteractionRegressionUITests/testWeeklyStatsSurfaceShowsSummaryBreakdownAndPeriodSwitching`; `testWeeklyStatsLongPressKeepsPeriodAndActivatesSelection`; `testWeeklyStatsChartScrollsToPastData`.
- **New focused gap**: one scoped seeded detail contract for actual previous value/caption and zero-or-missing percentage behavior if the fixture supports it. Avoid a test that simply counts visual rows. Check the AX-sized chart menu and lower breakdown with the existing Activity Exercise max-AX route test when affected layout warrants it.
- **Manual evidence**: inspect actual light/dark, normal/max AX, phone/iPad/Duo folded/open, selected period, comparison lower content, chart metric menu/selection and native Back. Follow the owned-device and bounded selector policy; do not run the full suite by default.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Previous date caption implies calendar weeks | Medium | High | Format `comparison.previous.startDate/endDate`; retain rolling-period behavior. |
| Strength volume misread as all HealthKit workout load | Medium | High | Keep current manual volume convention and absence marker. |
| Hero/card AX hides the fifth metric or chart | Medium | Medium | Native max-AX and Duo viewport proof, no fixed-height content. |
| Presentation container overwrites child chart/metric IDs | Medium | Medium | Keep `.accessibilityElement(children: .contain)` only where necessary; verify exact selectors. |
| Fresh original baseline differs from historical A05 PNG | High | Medium | Treat historical image as reference and capture original commit/state anew. |

## Confidence Assessment

- **Overall**: Medium.
- **Reasoning**: Source data/period/chart contracts and protected hashes are known. The exact native geometry and available seeded prior-period data still need a source-matched baseline and device readback before implementation is called complete.
