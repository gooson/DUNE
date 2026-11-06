# B12 W10/W11/W26/W27/W28 private preparation

Baseline: latest fetched `origin/main` at `7c7e21fa5c11ef1585e493288f258bbe0eb082d8`. All five target files match this revision in the reused worktree despite B11 dirty changes in other files. `manifest.json` records baseline and candidate SHA-256; separate patches and full candidates are under each screen directory. `git apply --check` passed for all five patches. No repository edit, SDK, simulator, or native pass claim.

## Screen identity and visual scope

- W10 WorkoutCompletionSheet: completion sheet after a saved single/template/compound workout. Candidate caps iPad content width and stacks PR row content at accessibility sizes; title, effort suggestion/value, share preview, Share Workout and Done remain.
- W11 ShareImageSheet: image sharing from W26 history and personal records. Candidate caps iPad width, reduces image height at accessibility sizes and allows Share label to wrap. UIImage and ShareLink item/preview remain.
- W26 ExerciseHistoryView: per-exercise chart/stats/session list. Candidate changes stats grid to one column at accessibility sizes and lets values wrap. Metric selection, chart data, unit conversion, reverse session order, share and delete confirmation remain.
- W27 ExerciseSessionDetailView: stored exercise session details. Candidate stacks title header and set rows at accessibility sizes. Set values/RPE, HealthKit linkage, history link, date and equipment icon remain.
- W28 HealthKitWorkoutDetailView: imported workout details. Candidate stacks header summary and stats cards at accessibility sizes and permits a larger title-edit sheet. Step range, resolved/corrected title, save/cancel, HealthKit-backed loading, badges and icons remain.

Each `layout-theme.html` is a private proposal diagram, not a current capture. Mapping came from `docs/design/full-redesign-map/index.html` W10/W11/W26/W27/W28 and `docs/design/phone-design-map/screen-inventory.md`; existing regular/iPad/Duo images in actual map are historical. Applied work must create or update linked screen-specific layout maps, review theme map, and refresh relevant actual captures. No theme token, catalog, or localized copy edit is proposed.

## Source and data boundaries

- W10 consumers: WorkoutSessionView, CompoundWorkoutView, TemplateWorkoutView (source-only legacy path). W11 consumers: ExerciseHistoryView and PersonalRecordsDetailView. W26 is reached from W27 history link; W27 is reached from ExerciseView, Activity exercise list and Health Query record detail; W28 from ExerciseView, Activity recent/insights, Health Query and training-volume views.
- No model, seeder, query, persistence, HealthKit service, share-image rendering or Watch source change. All candidate changes are presentation layout only. Source review still must verify icon/value hit regions and iPad sheets before integration.

## Focused test plan

1. **W26→W27 record path, normal/MAX**: reuse `ActivityExerciseRegressionTests/testVisualAuditExerciseHistoryFromSelectedWorkout` entry (Exercise recent Bench Press → W27 detail → View History W26); append narrow opt-in normal/MAX captures for W27 header/set values and W26 metric/chart/stats/session list, then navigate to one history session detail. Keep original sort, selected metric, unit and no delete assertions. Existing `testExerciseHistoryAtMaximumAccessibilityTextSize` covers the Exercise library, not W26.
2. **W10→share, normal/MAX**: reuse existing `ActivityExerciseRegressionTests/testVisualAuditWorkoutSharePreview` and `testManualWorkoutSessionSavesAndDismissesCompletionSheet` helpers, which already complete one isolated seeded set and assert W10 summary/Share/Done. Add only MAX capture/reachability if new selector needed. This route saves an isolated test record by design; no fixture or production seeder changes. W11 `ShareImageSheet` itself is reached from W26 history Share and from `testVisualAuditPersonalRecordShareSheet`; workout-completion ShareLink is a system share route and does not prove W11.
3. **W28 imported HealthKit detail, normal/MAX**: existing `CardioAtlasUITests` notification route `testImportedCardioDetailPreservesAnalysis` and `ActivityExerciseRegressionTests/testNotificationWorkoutRouteOpensHealthKitDetailAndTitleEditor` reach the detail; append narrow seeded normal/MAX capture for header/stats and title editor Cancel, preserving Save behavior static. Avoid broad HealthKit ingestion/live data flow.

Do not select all tests at once or claim W11 from W10 ShareLink. Suggested execution is affected selectors only on one owned device at a time, per `.codex/skill-compat.md`; actual device coverage and maps remain parent work.

## Review risks

- W10 PR row grows taller at MAX; confirm effort and Done remain reachable by scrolling.
- W11 medium detent may still require scrolling or a larger detent at MAX; current candidate narrows image but does not change caller detent. Do not call this validated until actual native capture.
- W26 session row metadata remains horizontally composed; inspect long localized values at MAX before accepting.
- W27 other cardio metric pairs and heart-rate chart are outside this narrow patch; check if seeded chosen record exposes them.
- W28 title editor is an AppStorage correction flow; test Cancel before Save to avoid mutating shared correction state. Check step-range control at MAX if walking fixture used.

## W27 shared execution contract

Apply maps before app. Reuse one worktree and incremental UI compile, exact normal/MAX flows only. W27 inside first-tap manual-record inspector→W26 existing history→W11 actual image Share context action. W10 isolated one-set normal save/effort/Done; its systemShareLink doesnotproveW11. W28 importedseedednotification detail/titleeditorCancel. Newnative PNG/AX for changed lower areas, independentreview, actualmap, compound and separatePRs; no fullregression. PhonepreviousB11closedlimits and H08/P03/P08/S03/W04/W31 remain. CurrentDuounavailableafterrecordedmigrationfailure; historicalPNGs neverafter.

## Scoped result

[Original receipts and scoped passed PNG+AX](../design/full-redesign-map/review/exercise-session-detail-w27-2026-11-07/index.html). Duo current-source captures remain pending. App scope SHA-256: `5eabaa63c0cf98c25710a25058ae543e2d86f5f2224507ae0559ae616b8fbcfa`.
