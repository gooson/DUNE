---
topic: t06-health-metric-detail-redesign
date: 2026-10-30
status: approved
confidence: medium
related_solutions:
  - ../solutions/architecture/2026-03-11-metric-detail-weekly-chart-current-day-alignment.md
  - ../solutions/architecture/2026-03-14-metric-detail-today-scroll-padding.md
  - ../solutions/architecture/2026-10-30-shared-score-history-contract.md
---

# Implementation Plan: T06 Health Metric Detail

## Context and research

The user authorized native iPhone/iPad/Duo implementation of the reviewed detail proposals, preserving every existing function/icon and creating screen-specific /run PRs. T05 remains isolated on `codex/t05-cumulative-stress-redesign`; its final UI path is deferred behind an execution-tool guard and an explicit exception question. This independent T06 branch starts at `9a21f364` and must not alter T05 or its execution records.

The missing prototype was recovered read-only from Git snapshot `786c2c3cb8dab80ccb0f5db0414c23f0ae5e4894`. Its full manifest SHA matches the preserved reviewed T05 source. This establishes the indexed proposal's identity, not any later absent-worktree dirty edits. Preserve the 16 T06 proposal variants as design evidence, never as actual native captures or approved production benchmark data.

Three bounded research streams inspected native dispatch/profile evidence, solutions/inventory/UI selectors, and official body-reference sources. The four legacy T06 capture records all identify Sleep; they are invalid HRV comparison images. Native contracts include all 16 categories, unit overrides, day/hour data, selectable periods, chart selection/scroll/trend, limited history, highlights, four conditional sleep analysis groups, visible exercise totals and All Data.

The prototype's MCST reference is not automatically usable product data: its [official distribution page](https://www.mcst.go.kr/site/s_policy/dept/deptView.jsp?pDataCD=0417000000&pSeq=2106) specifies KOGL Type 4. Use no MCST/InBody table or example profile as product truth. [NCHS Series 3 No.50](https://stacks.cdc.gov/view/cdc/174595/cdc_174595_DS1.pdf), Tables 3 and 10, provides public-domain US NHANES 2021–2023 adult weight/BMI means; its survey, population, exclusions and reuse attribution must remain visible in source details. Body-fat DXA 1999–2004 is not a method-matched precision ranking for unknown/BIA records. Korean and body-fat/lean-mass peer data remain unsupported until exact applicable sources and rights are established; that gap must stay explicit in completion reports.

## Requirements

- Preserve every category-specific query, real value, formatting/precision/unit, navigation and conditional analysis. No invented zeros, default current values, history points, profile, peer percentile or clinical grading.
- Use the existing `ScoreHeroPalette` and category's original icon/color for a strong coherent raw-value hero. A quantity is not a 100-point score; do not invent a score ring for kg/BMI/ms/min. At large text sizes, reflow the value/unit and supporting information without clipping.
- Put period selection, previous/next, one visible date range, chart, trend and visible-window summary in one card. Keep D/W/M/6M/Y and existing finer day sampling, selection/scroll lifecycle, period boundaries and history limitations. Audit existing calendar/raw summary contracts before reusing score-only helpers. Plot aggregation must not silently redefine raw summary statistics.
- Consistent leading metric icons, spacing and semantic quantities throughout. Keep all four sleep analysis groups and distance/minute exercise branches; do not replace specialized content with generic cards.
- For weight/BMI, add an optional, explicitly selected US reference cohort with actual source means. Never infer age/sex/region from locale or the prototype. No newly requested HealthKit demographic permission is required: a comparison-criteria sheet may persist only the chosen reference age band and statistical sex locally, initially unset. Make the US survey context clear before Apply. No unsupported-cohort fallback.
- Compare canonical kg or dimensionless BMI before display conversion; preserve preferred weight units. Show a neutral current-minus-mean difference, not a healthy/unhealthy assessment. Body-fat/lean-mass comparison stays honestly unavailable; preserve their actual data and history. This is an outstanding part of the broader peer-comparison request, not completed body-fat support.

## Approach and alternatives

| Approach | Decision |
|---|---|
| Copy prototype MCST values and hard-coded 30–34/male | Reject: example profile and restricted/unverified product data |
| Infer demographics or silently use US as Korean data | Reject: incorrect identity/population |
| Reskin while removing specialized analyses or All Data | Reject: feature loss |
| Keep native category dispatch/formatters, reuse hero palette, integrate chart summary, optional verified reference | Adopt; keep changes small and auditable |
| Rewrite every metric query/history contract | Avoid absent a demonstrated mismatch; fix affected contracts with focused tests only |

## Affected files

| File / area | Intended change |
|---|---|
| `Presentation/Shared/Detail/MetricDetailView.swift` | Hero, integrated history, spacing, original analyses/actions and reference entry |
| `MetricSummaryHeader.swift` / focused new hero component | Reuse exact value/unit formatting; remove duplicated period dates/stats from hero only after moving them |
| `MetricDetailViewModel.swift` | Only demonstrated visible-window/paging/summary mismatch; retain query dispatch and cadence |
| Focused body-reference domain model + presentation component | Verified weight/BMI means, applicability and difference; explicit unset/unsupported state, local criteria and source disclosure |
| `DUNETests/MetricDetailViewModelTests.swift`, relevant formatter/reference tests | Unit/cadence/boundary/reference and invalid-input coverage |
| Dedicated T06 UI capture/regression tests and opt-in DEBUG fixture only if necessary | Exact metric identity, before/after matrix, native navigation and large type |
| `Shared/Resources/Localizable.xcstrings`, generated project, layout/theme/actual maps | en/ko/ja, standard formatter/regen, honest source provenance |

## Implementation steps and gates

1. Preserve reviewed variant JSON and update layout/theme direction before app edits. Validate theme-map synchronization. Read affected native files/callers and relevant solutions directly; confirm profile and source assumptions.
2. Establish correct native before evidence with a deterministic opt-in fixture and existing navigation where feasible. Capture the original metric screen before changing its production layout. Correct identity is required: `metric-detail-screen-hrv` plus HRV/unit, never the legacy Sleep image. Because the user explicitly requested every detail variant, retain a per-category identity matrix for all 16; the four primary map images represent HRV and additional variants belong in the comparison gallery. Exercise km/min branches and sleep specialized content require their own evidence. Record unavailable variants, not substitutes.
3. Implement the coherent quantity hero and unified chart/summary, preserving specialized groups and All Data. Use separate logical commits. Add verified weight/BMI reference and unset/unsupported states with meaningful calculation/profile tests; no body-fat ranking or unlicensed values. Do not broaden into global profile/HealthKit authorization redesign.
4. Freeze source and run standard build, format checks, consumer analysis, relevant units and targeted UI on owned devices, one runner at a time. First scoped iPhone checks, then affected iPad and Duo closed/open. Confirm large text, dark appearance, units, chart gestures and original navigation. Do not execute full suites absent explicit user request. Establish lock availability before a pipeline attempt; lock deferral must never be mislabeled as app failure or test success. Do not modify an executor to pass this screen.
5. Export fresh actual captures with exact revision/fixture/device/state and native AX/PNG identity, compare every available before/after pair, regenerate only affected map records and inspect actual images. Do not claim every category/state/theme is verified from one HRV capture.
6. Complete five source-review perspectives, SwiftUI/Apple UX/UI-test/performance applicability, App Quality, Resolve, Compound, Pre-Ship and PR reviewer. Preserve any unsupported benchmark/capture scope explicitly. Create/merge only when required native gates are satisfied, then cleanup owned devices/branch and standard regeneration.

## Testing and edge cases

- All 16 category dispatch/units; SpO₂ fraction conversion exactly once, signed wrist temperature, sleep duration, exercise km/min and preferred mass units.
- Calendar/DST/month end, current complete day, visible prior window, cancellation/late response, missing/limited/error data, raw summary vs plot buckets, selection after scroll and vertical scroll from chart.
- Peer lookup exact 20–29/30–39/40–49/50–59/60–69/70–79/80+ and male/female survey rows; no 5-year interpolation, nearest-band/other-sex fallback, unsupported metric or malformed persisted criteria. No age/sex default. Finite canonical quantities, kg/lb difference conversion, source table provenance and mean versus P50 distinction.
- Fresh before/after exact identity; large text/icon/value spacing and reachable 44pt controls. Existing targeted entry/All Data: `WellnessRegressionTests/testHRVCardOpensMetricDetailAndAllData`; related chart regressions are in `ChartInteractionRegressionUITests`.

## Risks and confidence

Source preservation is high confidence. Runtime/capture scope and benchmark product UX are medium until implemented and verified. NHANES references are US survey means, not Korean norms or health targets. Body-fat/lean-mass comparison is intentionally not claimed supported; further applicable source work remains. Legacy Sleep pairings must be removed from HRV comparisons. Shared chart changes can affect other consumers, so prefer no shared behavioral change and document any required expansion. T05 execution-policy question is independent and must not be bypassed through T06.
