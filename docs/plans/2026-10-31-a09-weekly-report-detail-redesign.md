---
topic: A09 weekly workout report detail redesign
date: 2026-10-31
status: draft
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-22-weekly-report-healthkit-data-gap.md
related_brainstorms: []
---

# Implementation Plan: A09 Weekly Workout Report Detail

## Context

A09 is the Activity **Weekly Report** destination, separate from A05 Weekly Stats and T10 Daily Digest. Its optional `WorkoutReport` already supplies a dated rolling-week report, six conditional/current stat slots, a generated summary, typed highlights and optional muscle breakdown. The detail is presentation-only: it has no ViewModel, query, chart, period picker or retry control. A09 should make the actual report easier to read with a strong opaque report hero, consistent native metric icons and adaptive stat rows while retaining all data and conditional branches.

Read-only source inventory is preserved in rollout evidence. The [A09 layout proposal](../design/layout-map/activity-weekly-report-detail-a09.html) and [DUNE theme proposal](../design/theme-map/themes/dune-weekly-report-detail-a09.html) are browser contracts, not native captures. The original `WorkoutReportDetailView.swift` Git blob is `f535eed32ba1a47c727f10e256f7d756143808e5` at both `672d5fdb` and `1f7f9900`; protected card `bcda227d14f42aba9904d6eba1109044d50a3e48`, `ActivityViewModel` `19501095e6e6b780d7fec9b03dabf447410cd4b1`, report model `74d07a3678f38bf439851f622e6c3125f5fe9184`, use case `c744db71dbecd68d220929cbcfa83645b48c65b7`, report formatter protocol `5fabef3903520c53b03298354217163df14c9a88` and its production/fallback implementations are frozen. Historical `443a32ca…` A09 images are reference only. A fresh original iPad run on unchanged A09 source completed **2/2 methods passed**, including `ActivityExerciseRegressionTests/testActivityRiskAndReportRoutesOpen`. T08 inspected the loaded report root and screenshot `87B3CA7E-CBAA-48B8-A669-59188561830E.png` under `.codex-checks/a09/evidence/ui-ipad-original-before-current`; it shows the DEBUG fixture's 3 sessions, 3 active days, 2.4k volume, **5400 min**, 72% intensity and +12% change. The prior A08 risk image is a separate checkpoint. This is valid original iPad/fixture evidence only, not an A09 after pass or phone/Duo baseline.

## Requirements

### Functional

- Preserve Activity `weeklyReport != nil` navigation guard, `ActivityDetailDestination.weeklyReport`, native Back, root ID `activity-weekly-report-detail-screen`, and optional nil detail empty state. Parent generates `.weekly`; the model also supports `.monthly`, so render the actual `report.period.displayName` without hard-coding a picker or assuming calendar-week boundaries. Keep original formatted `startDate…endDate` **once** in the report header.
- Preserve all real stats and source units: sessions count, active days count, strength `totalVolume` in kg/k, `totalDuration` in minutes, normalized `averageIntensity` as the original integer percent, and conditional `volumeChangePercent` only when present. The change fraction is calculated by the use case from positive previous volume, clamped −1…+10, and multiplied by 100 only for display. Do not fabricate a comparison when nil or extrapolate a prior session count.
- Promote the existing current total volume into a report hero only as this app's computed completed-set weight×reps aggregate. It may be zero for HealthKit-only sessions; do not imply HealthKit duration/distance supplied sets or kg. Keep the other three user-facing core counts/duration visible as adaptive metric rows with leading SF symbols, then preserve average intensity and conditional change in the same reading flow. `averageIntensity` is normalized from recorded weight values, not a physiological exertion estimate; avoid stronger wording or confidence claims.
- Preserve `formattedSummary` exactly when nonempty and omit when nil/empty; retain formatter fallback behavior. Preserve all `report.highlights` in their supplied order, the original descriptions, the explicit no-highlights message, and original icon mapping: PR `trophy.fill`, streak `flame.fill`, volume increase `chart.line.uptrend.xyaxis`, consistency `calendar.badge.checkmark`, new exercise `star.fill`.
- Preserve optional muscle breakdown, order and source values. Bars are relative to the actual maximum muscle volume, guarded for nonpositive max; kg/k labels remain actual source format. Primary muscle receives full volume, secondary half in the protected use case. Do not depict these bars as percentages of total report or create cardio strength volume.
- Keep all existing source copy, level of detail, navigation, `DetailWaveBackground`, and `doc.text` nil icon. No chart, date arrows, period selector, fictional history, new CTA or duplicated dates.

### Non-functional

- Private View composition with `ScoreHeroPalette`/DS opaque surface and palette ink; semantic stat accents and consistent native leading icon slots. Use inline native title so the report header does not duplicate a large title. Keep regular width bounded around 680pt. At maximum Dynamic Type/narrow Duo, use one column and natural card heights rather than the original fixed three-column grid or 80/50pt muscle-label/value widths; all values/units/summary/highlights stay readable.
- Freeze `ActivityViewModel`, report model/use case/formatter, shared root card, source merge/de-duplication and upstream HealthKit query. Any new user copy requires `copy-voice`, UX-writing and en/ko/ja catalog formatting; prefer existing labels.

## Approach

Refactor only `WorkoutReportDetailView`: a private opaque hero presents the actual report period, date once, original total-volume value and conditional change. Use a small adaptive metric composition for sessions, active days, duration and average intensity, preserving every original value/formatter. Keep the supplied summary, highlights and muscle breakdown in source order, improving their icon alignment and max-AX wrapping without changing relative-bar math. The parent remains sole owner of report generation and nil-route behavior.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| Import A05 period picker/comparison or T10 daily chart | More controls | No A09 query/history source, changes product semantics | Reject |
| Recompute snapshots, highlight thresholds or muscle allocation in View | Flexible visual numbers | Duplicates and risks protected domain math | Reject |
| Detail-local hero and adaptive rows | Clear hierarchy from actual report | Requires AX/native density verification | Choose |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `DUNE/Presentation/Activity/WorkoutReportDetail/WorkoutReportDetailView.swift` | Modify | Private opaque hero, adaptive metric/highlight/muscle presentation; original data/branches. |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | Conditional focused contract | Extend exact report route for loaded fixture values, summary/highlight and Back if meaningful. |
| `Shared/Resources/Localizable.xcstrings` | Conditional | Only if an essential new label is required; translate en/ko/ja and format/manual-check. |
| `docs/design/layout-map/activity-weekly-report-detail-a09.html`, index/README | Plan phase | Separate source/states/layout proposal, explicitly not native. |
| `docs/design/theme-map/themes/dune-weekly-report-detail-a09.html`, manifest/index/README | Plan phase | DUNE light/dark direction, illustrative values labeled. |
| `docs/design/phone-design-map/actual/index.html`, new A09 PNGs | After native | Fresh source-matched actual after states/device tiers only. |

## Implementation Steps

### Step 1: Source closure, original capture and proposal maps

- **Files**: ignored source/capture evidence, formal plan, separate layout/theme proposals.
- **Changes**: Confirm original/protected hashes and exact route `ActivityExerciseRegressionTests/testActivityRiskAndReportRoutesOpen` on unchanged `1f7f9900` or source-identical `672d5fdb`. Its `--ui-design-map-activity-routes` branch injects a fixed **DEBUG presentation fixture**, not product-derived records: 3 sessions, 2,400 kg, 5,400 min, 3 active days, .72 normalized intensity, .12 volume change, one consistency highlight, supplied summary, and two muscles. The `reportLink.auditTap()` checkpoint and final teardown are A09 candidates; inspect actual PNG/AX for root, loaded content and report period. The earlier risk auditTap is A08. Do not label the whole native batch passed if another selector fails. Historical `443a32ca…` A09 images are not current before.
- **Verification**: Record source/fixture, device, locale/theme/type size, A09 root and actual visible date/value state for each accepted before. The iPad original report auditTap has an official 2/2 result and verified loaded root/image identity; record phone/Duo before only when separately captured.

### Step 2: Compose real report hierarchy

- **Files**: A09 View, optional catalog and proposal maps.
- **Changes**: Preserve nil/summary/highlight/muscle conditionals, root/Back/background, source period/date formatter, all six stat semantics and original formatting. Add private useful hero and aligned stat icons. Replace three-column max-AX squeeze with adaptive stack; remove fixed muscle row widths at AX without changing the guarded `volume / maxVolume` calculation. Reuse original highlight icons/descriptions and generated summary. No period/chart or new math.
- **Verification**: Swift parse, diff, protected source hashes, catalog format/manual check if touched; parent-controlled build later.

### Step 3: Focused native and actual map

- **Files**: existing route test if needed, native PNGs/AX and actual design map.
- **Changes**: Check source-backed DEBUG fixture values in the loaded A09 screen, one date range, one consistency highlight, formatted summary, chest/quadriceps bars (the unsorted DEBUG fixture is 1,100/1,300, so the bars should be approximately 85%/100%) and native Back. Validate real conditional/no-highlight/nil states only with deterministic existing fixtures or source-level unit tests, without inventing a new product fallback. Inspect light/dark/max AX and phone/iPad/Duo folded/open where affected.
- **Verification**: Exact route selector plus only changed-behavior checks; existing `GenerateWorkoutReportUseCaseTests` and `ActivityViewModelTests.weeklyReportIncludesHealthKitWorkouts`/`weeklyReportMergesWithoutDuplication` are math/merge authority and need rerun only if source behavior changes. Review actual PNG/AX for truncation, unit truth and the 1,100/1,300 relative bar widths. Redesigned native work remains pending; the original iPad before is already accepted.

## Edge Cases

| Case | Handling |
|---|---|
| Report nil | Parent offers no link; detail keeps `doc.text` and existing empty message if opened directly. |
| Summary nil/empty | Omit section; do not fabricate formatter output. |
| Highlights empty | Show original “No highlights this period”; do not synthesize PR/new exercise, which current production caller supplies as 0/empty. |
| Prior volume nil/zero | Omit volume change; no 0% comparison or invented previous values. |
| HealthKit-only duration with zero kg | Keep real sessions/duration and source `0kg` total; do not imply measured strength volume. |
| Muscle breakdown empty/nonpositive | Omit section or preserve guarded zero bar; no divide-by-zero. |
| Monthly model (if passed by another caller) | Render actual period/name/date and existing stats without claiming this Activity route generates monthly reports. |
| Max AX/Duo folded | Stack stat cells and muscle names/values; retain all original text, highlights and Back. |

## Testing Strategy

- **Original/before**: Exact `ActivityExerciseRegressionTests/testActivityRiskAndReportRoutesOpen` risk→Back→report path on source-matched original. Inspect report auditTap and A09 teardown, separate from A08 risk image. The original iPad 2/2 run and A09 loaded root/PNG/AX are confirmed; do not extrapolate to phone/Duo or redesigned after.
- **Focused after**: Re-run exact route selector with a small assertion of test-only fixture totals/highlight and report root, then native Back/scroll if the test is extended. Avoid mirroring six static labels or hardcoding prototype data. Existing use-case/VM tests are source math authority; View-only redesign need not rerun all report algorithms.
- **Visual**: Source/fixture-matched iPhone, iPad, Duo folded/open, plus affected dark/max AX. Check one date caption, actual kg/min/% units, all highlight icons, no clipped summary or muscle names. No Watch change.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| DEBUG fixture numbers mistaken for production report | High | High | Label fixture in plan/tests/captures; never embed literals in View. |
| 5,400 fixture minutes silently converted to hours or mislabeled | Medium | High | Preserve source `totalDuration` format and actual `min` unit. |
| Average intensity read as physiological confidence | Medium | Medium | Keep original normalized metric label/value; no new clinical wording. |
| An unsorted report makes first-row normalization falsely equal after clipping | Medium | High | Normalize bars by the actual maximum across rows once; fixture Chest 1,100 before Quadriceps 1,300 should render about 85%/100%. |
| 3-column/fixed-width source clipping at AX | High | Medium | Adaptive metric and muscle rows; inspect actual max-AX viewport. |
| A08 audit or A09 teardown misattributed | Medium | High | Inspect exact PNG/AX root and route checkpoint before pairing. |

## Confidence Assessment

- **Overall**: Medium.
- **Reasoning**: Report source, math, conditional sections, DEBUG fixture and route capture timing are authenticated. Fresh original iPad A09 loaded image and AX are confirmed; original phone/Duo and redesigned device/AX readability remain pending native evidence.
