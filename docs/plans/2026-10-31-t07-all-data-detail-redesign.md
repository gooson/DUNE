---
topic: T07 all-data native detail redesign
date: 2026-10-31
status: approved
confidence: high
related_solutions:
  - docs/solutions/healthkit/2026-03-04-all-data-sleep-awake-alignment.md
  - docs/solutions/healthkit/2026-03-11-sleep-all-data-time-anchor.md
---

# Implementation Plan: T07 All Data

## Context

The approved detail rollout requires a native screen-level PR for all sixteen AllDataView categories. Improve category identity and date/time/value hierarchy while preserving actual retrieval and every native state. User authorized implementation, scoped verification, independent review and per-screen PR/merge through run. This branch is based on T06 candidate a367ae22; PR stays dependent on T06 until that screen lands, then targets main. Main, original prototype checkout and .claude settings remain untouched.

## Requirements

### Functional

- Preserve sixteen category icons and names from HealthMetric+View, fixed-English category navigation title, native back, all-data-screen-<rawValue> and empty-state AX identities.
- Preserve all actual date sections, per-point time and formatted measurement. Sleep groups by reporting date but displays earliest non-awake stage displayDate. Keep awake exclusion, percent/temperature/precision formatting.
- Preserve limited-history notice, ready/empty/limited-empty/loading/next-page states and pagination. Page size means thirty calendar days, never thirty records or a history cap.
- Do not add unsupported date filters, averages, percentile, full-history counts, last-updated timestamps or fictional source badges. Prototype switches are inspection fixtures rather than native controls.
- Keep AllDataViewModel, cancellation/request IDs, latestDate gap jumps and production services unchanged except a strictly opt-in test fixture seam for the previously unseeded breathing-disturbance category.

### Non-functional

Use existing DS spacing, category SF Symbol and theme color, compact opaque identity hero consistent with metric detail, adaptive readable rows, tabular numbers and real Dynamic Type. Keep lazy system List/paging and static decoration. iPhone, iPad, Duo folded/open only. One owned simulator at a time; no builds during another native UI execution. Never alter .claude or validation runner during this screen work.

## Research

Independent planner /root/t07_plan researched source, consumers, prototype manifest, solutions, prior plans/todos and native pairing. Detailed ignored report is preserved in L03 .codex-checks/detail-rollout/t07-plan-research.md. Existing --seed-mock uses SimulatorAdvancedMockDataProvider for fifteen category services. BreathingDisturbanceQueryService bypasses this provider. ContentView already has a DEBUG T06 direct-route pattern. Existing limited-history and empty-provider flags cover notice/empty states. LatestDate gap behavior remains a separate existing VM unit contract; current fixture must never be described as full history.

The recovered approved prototype at revision 786c2c3cb8dab80ccb0f5db0414c23f0ae5e4894 is proposal evidence, not native data. Exact old PNG pairing exists only for HRV phone/Duo closed and sleep iPad/Duo open. New baseline capture uses the original AllDataView layout and the same explicitly identified deterministic mock fixture as after; do not label other historical category images as exact references.

## Approach

First add bounded opt-in UI route/fixture instrumentation and selected tests while AllDataView production layout stays byte-identical. Freeze and capture all sixteen original layouts. Only then implement View-only identity hero and rows after a T07 layout/theme map is recorded. Reuse existing formatting and data paths. Query mock seam must require DEBUG simulator plus --uitesting and explicit T07 intent; real-device/production fallback stays untouched. Existing provider referenceDate anchors an explicit missing-category test sample (1.2 disturbances/hr); it is fixture data, not a live or preexisting dataset measurement. The existing fifteen seeded categories and range filtering remain authoritative. If a category fixture cannot be seeded correctly, stop that claim and record the exact missing state rather than fabricate ready rows.

### Alternative Approaches Considered

| Approach | Benefit | Cost | Decision |
| --- | --- | --- | --- |
| Replace List with custom fetch/grid | Broad visual freedom | Risks lazy paging, historical semantics and AX | Reject |
| Prototype example rows in production | Quick rendering | Replaces actual health data | Reject |
| View-only layout with opt-in fixture for actual UI | Narrow change, repeatable exact comparison | One missing-category mock seam and native captures | Select |

## Affected Files

| File | Change | Reason |
| --- | --- | --- |
| DUNE/Presentation/Shared/Detail/AllDataView.swift | View-only layout after baseline | Category identity, readable time/value rows, real state preservation |
| DUNE/App/ContentView.swift | DEBUG route instrumentation only | Existing AllDataDestination with explicit T07 intent |
| DUNE/Data/HealthKit/BreathingDisturbanceQueryService.swift | Strict DEBUG test mock branch only if required | Complete existing provider seed for sixteenth category; no live retrieval change |
| DUNEUITests/Full/AllDataDetailRedesignTests.swift | Focused UI contracts | Sixteen identities, actual seeded row formatting, sleep start, empty/limited and AX |
| docs/design/layout-map/all-data-detail-t07.html and index | Before implementation contract | Screen hierarchy and all data states |
| docs/design/theme-map/themes/dune-all-data-detail-t07.html, manifest/README/index | Preserved direction | Identity hero and native List appearance, no fake data claims |
| Shared/Resources/Localizable.xcstrings | Only if needed | Prefer existing category/History strings; any new strings en/ko/ja/manual format |
| Actual design map indices/images and review gallery | Fresh four-tier capture after layout | Distinguish original baseline, new native UI and proposal |

## Implementation Steps

### Step 1: Freeze original layout with deterministic instrumentation

Read applicable code, design, UI/testing and health data rules. Add only explicit DEBUG route and missing breathing mock with real range filtering; reuse current seed dataset. Write bounded sixteen-category tests using positive --uitesting/--seed-mock/--ui-t07-all-data flags. Preserve production retrieval and AllDataView source hash. Independent test/source review before commit. Parent runs standard App/UI compilation and captures the untouched original layout on the single validation phone. Keep full original xcresult/AX/PNG/logs and exact source revision.

### Step 2: Update design contract before View code

Record T07 layout and theme direction with shared hero tokens, all sixteen icons, real section date/time/value, restricted/empty/loading and Dynamic Type behavior. Link indices and build/check theme map. Read this plan before implementing.

### Step 3: Implement narrow View change

Use original category icon/name/theme in compact static hero. Keep native lazy List, notice, section grouping, spinner task and AX root. Preserve formattedValue method and displayDate choice byte-for-byte where possible. Show every row using actual viewModel points; no invented summary. Keep narrow and accessibility layouts in one readable column and avoid repeated redundant period text. No other screen source edits.

### Step 4: Focused verification and resolve

Run before/after same sixteen-category fixture loop, separate sleep reporting-day/display-time assertion, limited ready/empty and dark maximum AX reachability. Reuse existing unchanged paging/sleep VM test evidence when source closure matches; otherwise run exact relevant AllDataViewModelTests. Keep real entry-route selectors from T06 and Wellness as applicable; no unsolicited full regression. Record all failures and cause-based retry budget; same cause one retry only. Build/unit/UI/capture serialized per root and one owned device, fixed deadlines.

### Step 5: Reviews, actual maps, Compound and screen PR

Independently run applicable Security, Data Integrity, Architecture, Simplicity, Performance and SwiftUI/Apple UX/app-quality/pr review roles under canonical model policy. Review fresh native captures for phone/iPad/Duo closed/open, accurate same-category pairing, icon parity, paging/notice and text clipping. Resolve findings and only retest changed scope. Sync actual design map and preserve proposal separately. Document concrete learning, inspect final diff/validation/source provenance, create separate T07 PR dependent on T06, merge only after gates pass and clean only owned resources.

## Edge Cases

| Case | Required handling |
| --- | --- |
| Empty + limited history | Same exact limited message and notice, no fake zero rows |
| Sleep prior-evening start | Group by report date, row time from displayDate, exclude awake |
| Missing interval | Keep latestDate gap jump and hasMoreData semantics |
| Loaded-so-far data | Do not label count as total history |
| Narrow Duo / maximum text | No fixed-width clipping; full values/units and readable hierarchy |
| View re-entry / cancellation | Existing VM request IDs and tasks untouched |
| Sixteenth fixture | Explicit opt-in mock only, range-filter existing data; never silently assert real HealthKit sample |

## Testing Strategy

Meaningful native scoped tests on actual app, with before/after matching fixture. Existing AllDataViewModelTests cover paging, request cancellation, sleep anchor and duration. Production VM logic is unchanged; avoid duplicate implementation-mirroring unit tests. Exact existing route tests include MetricDetailRedesignTests/testHRVRealWellnessEntryAndAllData, LimitedHealthHistoryUITests/testAllDataExplainsLimitedHistory and TodaySettingsRegressionTests/testSleepMetricPushesDetailBackAndReopensAllData; confirm source availability before executing only affected selectors. Actual four hardware tiers required for the final design map; Watch excluded. UI collector success is not a visual-quality pass.

## Risks

| Risk | Mitigation |
| --- | --- |
| Header changes lazy paging visibility | Keep native List/spinner semantics and bounded actual state test |
| Date/time confusion | Preserve point.date vs point.displayDate contract and sleep fixture test |
| Wrong before PNG category | Fresh original-layout sixteen-category capture, explicit per-image provenance |
| Fixture leakage | DEBUG + simulator + --uitesting + explicit T07 gate; no production fallback |
| Parent T06 not merged | Keep explicit stacked dependency until T06 lands; retarget after main integration |

## Confidence Assessment

High for View-only change and fifteen existing seeded categories. Missing-category test mock/route requires focused review before first capture. Four-tier UI and final PR gates are pending; this plan is not implementation completion.
