# B09 W01 · Exercise list private preparation

Status: source-only candidate; no repository edit, SDK, simulator, or capture. Baseline `DUNE/Presentation/Shared/Components/UnifiedWorkoutRow.swift` SHA-256 `55ad61bbd8b9b74e82892e22f0881dd2751fdcf59ef4a66d480fc2495eb4f2d7`. Recheck hash before applying `W01.patch`.

## Screen and current contract

W01 is Exercise list `exercise-view-screen`, reached from Activity recent “See All” in the actual-map capture. Historical regular/iPad/Duo/Duo-open PNGs are in `docs/design/phone-design-map/actual/{profile}/images/W01.png`; they are not current-source approval. The 4-tab layout map and current DUNE theme map establish the existing wave, activity color, suggestion section and record list. `ExerciseView` owns the native `List`, load/pagination, pending draft, recommendation, toolbar, inspector, delete, sheet and workout routes. `UnifiedWorkoutRow(style: .full)` is used at the two W01 call sites in `ExerciseView.swift:228,235`; `style: .compact` belongs to Activity and stays at one-line normal title.

## Candidate and boundaries

`W01.patch` changes only full-style record title line limit from one to two at ordinary Dynamic Type. Accessibility sizes remain unlimited; compact Activity rows remain one line. Original activity/equipment icons, HealthKit badge, PR emphasis, metrics, date, row identity, List virtualization, button action, pagination, and swipe actions remain. This is a narrow readability improvement for long real workout names; no sample score/count or new copy.

`W01-layout.html` and `W01-theme.html` are explanatory static proposals with placeholder icon shapes, not native captures. Reconcile them into a dedicated `docs/design/layout-map/` page/index and theme-map theme/manifest/README before source changes; build/check the theme map. Compare the existing actual W01 captures before applying. Then recapture affected regular iPhone, iPad and Duo closed/open current-source screens; inspect a long real/fixture title at normal and MAX, including badges/trailing calorie/date.

## Focused verification and risk

Existing route/behavior selector: `ActivityExerciseRegressionTests/testCompoundWorkoutSetupStartsWorkoutAndFinishesFlow` begins with `openExerciseViewFromRecentWorkouts()` and tests add-menu flow; `testManualWorkoutSessionSavesAndDismissesCompletionSheet` also reaches W01. A focused visual title assertion/capture may be needed because neither existing selector establishes two-line fit. Risk: a two-line title can raise row height and move trailing date or badge; visual inspect on compact width and iPad. No model/query/services changes.

## B09 shared core contract

W01/W02/W03 normal and MAX library→picker→detail→Close; native Cancel or original exercise selection. W04 normal/MAX existing Category selection and InputType reset, disabled empty Create, Cancel; unchanged parser/persistence statically reviewed. Exact four phone selectors in ActivityExercisePickerRegressionTests; affected iPad subset after phone. Same target incremental build reused, no separate phase builds or full local regression. Fresh PNG/AX and per-screen actual-map/independent reviews/compound/PR/normal merge. No currentDuo execution after fresh owned migrationfailure; markmissing, never relabeloldPNG. P03/P08/S03/H08 limits preserved.

## Scoped result

[Native PNG/AX, source equivalence, original counts and explicit limits](../design/full-redesign-map/review/exercise-library-w01-2026-11-07/index.html). Sharedphone4:3pass1fail, failedcase-onlyretry1/1; iPad exact4, rawreceipt authoritative. No whole-regression or all-device claim.
