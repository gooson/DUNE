---
topic: A07 exercise type detail redesign
date: 2026-10-31
status: draft
confidence: medium
related_solutions:
  - docs/solutions/testing/2026-03-16-e2e-settings-activity-surface-contracts.md
  - docs/solutions/testing/2026-03-08-training-volume-daily-volume-scroll-and-day-bucket-alignment.md
related_brainstorms: []
---

# Implementation Plan: A07 Exercise Type Detail

## Context

The Activity Training Volume list opens a detail for one canonical exercise type. The original view has real duration, calories, sessions, a daily **minutes** chart, conditional distance/weighted volume, and HealthKit workout links. A07 improves the hierarchy and readability of those actual values with a type-specific opaque hero and aligned comparison. The recovered prototype depicts multiple type variants but its values and percentage changes are illustrative, not native input or history.

Read-only source research is preserved in the rollout evidence. The [A07 layout contract](../design/layout-map/activity-exercise-type-detail-a07.html) and [DUNE theme proposal](../design/theme-map/themes/dune-exercise-type-detail-a07.html) are browser proposals, not native captures. The original A07 View Git blob at `672d5fdb` is `fb9085193e8c5e4d810d98f2b0b87577fe74c666`; ViewModel `08d9cd0f87da5be6e8393dfee9d26ba4b561ae6f`, analysis service `f0b9390c78075311712408374504b39b82f5d72e`, domain model `e9fb5e77d2a1bbbd3c118f1ae15309e450db0618`, workout provider `e82781557fbf7faf0077f6e51a179688455ff2ac`. The same blobs were confirmed at candidate `1f7f9900`. Freeze these and recheck in the eventual A07 worktree. Historical A07 PNGs at `443a32ca…` are references, not source-matched before captures. The fresh original six-selector batch on source-matched `1f7f9900` was still in progress when this plan was prepared; the A07 Week audit image and Month teardown remain pending PNG/AX inspection. No baseline or native pass is claimed.

## Requirements

### Functional

- Keep Activity → A06 exercise-type row → A07 destination and native Back; preserve `typeKey` exactly. Manual lookup accepts `manual-<exerciseType>` and legacy raw `exerciseType` in records; HealthKit lookup filters exact `activityType.rawValue`. Do not group different names or raw types.
- Keep four `VolumePeriod` choices 1W/1M/3M/6M (7/30/90/180 days), Week default, local picker selection, `@Query` records, `.task(id:)` reload, request invalidation, two-window provider fetch and link-ID de-duplication.
- Preserve current summary duration (`formattedDuration()`), calories (`kcal`) and sessions; conditional distance in m/km only when positive; conditional manual completed-set weight×reps volume in kg/t only when positive. A HealthKit workout does not supply strength sets or weighted volume. Keep optional metrics in the comparison where they already exist.
- Use the original type/equipment identity: resolved equipment SVG at 30pt when available, otherwise exact `WorkoutActivityType.iconName` and the original `dumbbell.fill` fallback; preserve type/category color resolution. Add semantically correct metric SF symbols with matching leading slots in current/comparison rows. Hero emphasis must choose an **available** real metric: weighted volume only for valid manual strength data, duration for time-led/cardio, otherwise another present original metric or truthful no-data. Do not impose one kg hero on every type.
- Keep original daily bar chart (duration minutes, 180pt, source period buckets, selection overlay/date/minutes, original 1/7/14/30 day axis stride); chart is not horizontally scrollable. Keep `activity-exercise-type-trend-chart` and picker/root IDs. No invented trend points or inert date arrows.
- Show one prior-window caption in comparison when it can be anchored to the same analyzed window, not one date per row. `previousSummary` contains a type aggregate but **not** the `PeriodComparison.previous` dates. The View can derive the window from `trendData.first?.date` (analysis current-start bucket) plus `selectedPeriod.days` using `Calendar.current`; when that anchor is unavailable, show “Previous period” without fabricated dates. Do not compute percentages in the View: retain existing `durationChange`/`calorieChange`, including nil when prior denominator is zero or nonfinite; sessions/distance/volume have no original change percentage.
- Keep newest-first top-ten **HealthKit-only** recent sessions, each date, duration/calorie/distance, and `HealthKitWorkoutDetailView` link. Manual types do not gain fabricated workout history. Keep original loading/no-data, zero-bucket chart, provider failure logging/fallback and conditional sections.

### Non-functional

- Detail-private presentation only: local opaque `ScoreHeroPalette`/DS composition, original type tint as semantic accent, palette ink with sufficient contrast, native icon/equipment shape intact, readable normal/dark/max AX and narrow Duo. On iPad use a bounded readable column; keep one vertical path to chart/history. No fixed-height hero or glyph/text overlap.
- Do not change A06 rows, shared detail hero, ViewModel, analysis/model/provider/query, manual volume rules, HealthKit de-duplication, or other type consumers. Existing strings and formatters should be reused; any genuinely new user copy requires en/ko/ja catalog and format/manual checks.

## Approach

Refactor `ExerciseTypeDetailView`'s header and comparison presentation privately around the existing `currentSummary` and `previousSummary`; retain query, task, chart and recent-session wiring. Make the type identity legible as the hero anchor. Present the three universal metrics and the real optional metrics as aligned rows, with one bounded prior-window caption. A07 should style manual strength and HealthKit cardio differently only where the source data differs, without new branching in aggregation.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| Copy prototype totals/sets/percentages into fixture or View | Visual match | Falsifies real data and type semantics | Reject |
| Change ViewModel to expose a new detail model/date range | Direct caption source | Broadens a presentation task and invalidates protected VM hash | Avoid; use existing analyzed chart start or generic prior label |
| Detail-local hero/comparison with existing source | Small scope; preserves retrieval, chart and drilldown | Needs native contrast/AX and date-anchor verification | Choose |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `DUNE/Presentation/Activity/TrainingVolume/ExerciseTypeDetailView.swift` | Modify | Private hero/metric/comparison presentation; preserve chart, state and session routes. |
| `Shared/Resources/Localizable.xcstrings` | Conditional | Only if a necessary new caption cannot use existing keys; en/ko/ja and formatter/manual checks. |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | Conditional focused test | Add one real-data invariant for manual strength/HealthKit type and prior truth if existing fixtures support it; keep original selector. |
| `docs/design/layout-map/activity-exercise-type-detail-a07.html`, index/README | Plan phase | Source/states/responsive layout proposal, clearly separate from actual captures. |
| `docs/design/theme-map/themes/dune-exercise-type-detail-a07.html`, manifest/index/README | Plan phase | Illustrative light/dark direction; standard generator/check. |
| `docs/design/phone-design-map/actual/index.html`, new A07 PNGs | After native | Only actual source-matched after captures, paired to validated original states. |

## Implementation Steps

### Step 1: Authenticate source and capture original states

- **Files**: ignored evidence plus separate layout/theme maps; no App edit.
- **Changes**: Confirm listed hashes and route. Run exact `ActivityExerciseRegressionTests/testExerciseTypeDetailShowsTrendSurface` on unchanged A07 source. `row.auditTap()` captures after tap but **before** the method's explicit A07 root assertion; inspect the PNG and AX for `activity-exercise-type-detail-screen`, Week picker and real manual-strength content. Automatic teardown is after Week→Month and must be labeled Month. The A06 route-only test stops at the row and cannot be used as an A07 image. Collect matching original phone/iPad/Duo folded/open states where pairing is claimed; historical `443a32ca…` PNGs do not substitute.
- **Verification**: Record commit, app/test source, fixture, selected canonical type, period, theme, type size, device and actual root/visible values for each before image. No complete baseline claim until inspection.

### Step 2: Compose type-specific real-data presentation

- **Files**: A07 View, conditional catalog, proposal maps.
- **Changes**: Preserve `.task(id: selectedPeriod)`, `@Query`, root/picker/chart/recent IDs, plot marks/selection/domain, `ChangeBadge` math, and `HealthKitWorkoutDetailView` links. Build local opaque hero with original equipment/SF identity and real current metrics. Align matching symbols/current/prior metrics; show prior date once only with a proven anchor. Keep distance/volume conditional and session dates per workout. Use adaptive stack/grid, no fixed height.
- **Verification**: Swift parse, diff, catalog format/manual checks if touched, unchanged protected hashes before build.

### Step 3: Focused native contract and actual design map

- **Files**: focused UI test if needed, actual map and native PNGs.
- **Changes**: Check manual-strength fixture's actual positive weighted volume and 1W→1M chart; verify optional metric disappears when input absent rather than inventing zero. If an existing HealthKit running fixture/route genuinely reaches A07, add a second targeted type check for duration/distance/no weighted-kg inference and top-ten link behavior. Do not create a mock-only value just to match prototype. Verify comparison caption against source window, changes only for duration/calories, native Back, light/dark/max AX and phone/iPad/Duo viewport reachability.
- **Verification**: Exact original selector plus only changed-behavior tests; inspect AX and PNG rather than `exists` alone for clipped lower content. Native/build not yet run at draft time.

## Edge Cases

| Case | Handling |
|---|---|
| Manual record with legacy raw type name | Original record filter remains, including existing possibility of an unmatched trend segment; no new alias aggregation. |
| HealthKit type vs manual type | Exact raw activity filter or canonical `manual-` key; no mixed workouts or fabricated sets/history. |
| Missing, bodyweight, or invalid weighted sets | Volume omitted; no kg/t hero or claim. |
| Distance under/over 1 km; volume under/over 1000 kg | Reuse original formatters and thresholds, m/km and kg/t respectively. |
| Prior summary nil/zero | No manufactured 0% or session/distance/volume percentage. Generic previous caption if date anchor unavailable. |
| No selected aggregate but zero-filled trend buckets | Keep “No data”; trend may still exist, comparison/history absent. |
| Loading, failed provider query, period changes | Preserve 200pt loading branch, logged fallback, clearing/invalidation and new period fetch. |
| Narrow Duo / maximum Dynamic Type | Wrap/stack long type and equipment names, icons and units; all four periods, chart overlay and Back remain reachable. |

## Testing Strategy

- **Original route/before**: `ActivityExerciseRegressionTests/testExerciseTypeDetailShowsTrendSurface` on original source; prove default Week screenshot identity by AX/image, then label teardown Month. `testActivityDetailRoutesOpenExpectedScreens` is A06-only at the relevant checkpoint.
- **Targeted behavior**: Re-run the direct A07 selector after View change for manual-strength type, period picker and daily-minutes chart. New meaningful check should compare real current/previous data or absence of invalid volume/percentage, not assert five decorative rows. HealthKit running case is conditional on an existing seeded A06 row actually reaching it; inspect fixtures before selecting a second test. No production mock fallback or invented fixtures.
- **Native visual**: Source-matched phone, iPad, Duo folded/open; normal and affected dark/max AX. Inspect correct type icon/equipment, actual units, prior date once, selected chart overlay, recent-workout link, and scroll/Back. Watch is outside A07 scope.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Copying prototype strength volume to cardio/bodyweight | Medium | High | Derive hero only from type's actual optional metrics; inspect both variants. |
| Previous date reconstructed from wall clock rather than analyzed window | Medium | High | Anchor to source chart's current-start bucket; use generic caption if absent; verify day boundary/DST. |
| Chart zero buckets mistaken for workouts | Medium | Medium | Keep chart source; count/recent list only from actual summary and filtered HealthKit workouts. |
| Type badge or grid clips at max AX/Duo | Medium | Medium | Adaptive layout and native viewport/PNG review. |
| Audit tap image mislabeled as Week A07 | Medium | High | Inspect root ID and picker in exact PNG/AX; distinguish Month teardown and A06 route. |

## Confidence Assessment

- **Overall**: Medium.
- **Reasoning**: Source identity, query, aggregation, optional units, chart and existing selector are authenticated. A fresh before capture and a second seeded HealthKit type route have not yet been verified. The prior date caption needs source-anchor/native date-boundary validation.
