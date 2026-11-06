# B09 W02 · Exercise selection private preparation

Status: source-only candidate; no repository edit, SDK, simulator, or capture. Baseline `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift` SHA-256 `1b15459f0d459f1ebfd72048e49be92ef79e61c72da66ec413c36aa0f87ab2e7`. Recheck hash before applying `W02.patch`.

## Screen and current contract

W02 is the Quick Start/Select Exercise picker `picker-root-list`. Historical actual-map W02 captures live at `docs/design/phone-design-map/actual/{profile}/images/W02.png`. The regular image records a filtered Deadlift Quick Start sheet; iPad and Duo images record the picker root. These are older-source evidence only. Source consumers: `ExerciseView.swift:172`, `CompoundWorkoutSetupView.swift:158`, `CreateTemplateView.swift:557`, `ActivityView.swift:254`. Preserve quick/full modes, native List virtualization, sections, search, templates, recent/preferred/popular priority, category/muscle/equipment filters, custom creation, detail and select callbacks, and original equipment SVG icon.

## Candidate and boundaries

`W02.patch` adds a Dynamic Type environment to the picker row. At accessibility sizes, the exercise name and Custom badge, then primary muscles and equipment, stack vertically; normal sizes retain the original horizontal hierarchy and bullet. Name/muscle text grows vertically. The existing info detail button label gets a 44pt minimum frame plus a rectangular content shape, so the hit region matches the visible layout area. Its action, identifier and icon stay intact. No copied row model, sort/filter/query change, new string, or new icon.

`W02-layout.html` and `W02-theme.html` are static proposals, not native screenshots. Reconcile into a dedicated layout-map page/index plus theme-map theme/manifest/README before source code, then run theme-map build/check. Preserve historical W02 actual captures as baseline and recapture fresh current-source regular iPhone, iPad and Duo closed/open for picker root, filtered result and accessibility MAX; verify text, equipment icon, info tap and selection route.

## Focused verification and risk

Existing selectors: `ActivityExerciseRegressionTests/testQuickStartPickerShowsDetailAndSearchResults` covers search, detail and row reachability; `testVisualAuditExercisePicker` captures initial picker; `testVisualAuditTemplateFromActivityPicker` covers the quick-start template branch; `testCompoundWorkoutSetupStartsWorkoutAndFinishesFlow` reaches a full-mode picker through compound setup. New MAX fit assertion only if targeted native audit finds a gap. Risk: larger rows may change scroll position and the adjacent info button could compress very long titles; inspect Korean/Japanese and custom badge. Both normal and accessibility layout branches need native proof. No native pass is claimed here.

## B09 shared core contract

W01/W02/W03 normal and MAX library→picker→detail→Close; native Cancel or original exercise selection. W04 normal/MAX existing Category selection and InputType reset, disabled empty Create, Cancel; unchanged parser/persistence statically reviewed. Exact four phone selectors in ActivityExercisePickerRegressionTests; affected iPad subset after phone. Same target incremental build reused, no separate phase builds or full local regression. Fresh PNG/AX and per-screen actual-map/independent reviews/compound/PR/normal merge. No currentDuo execution after fresh owned migrationfailure; markmissing, never relabeloldPNG. P03/P08/S03/H08 limits preserved.

## Scoped result

[Native PNG/AX, source equivalence, original counts and explicit limits](../design/full-redesign-map/review/exercise-picker-w02-2026-11-07/index.html). Sharedphone4:3pass1fail, failedcase-onlyretry1/1; iPad exact4, rawreceipt authoritative. No whole-regression or all-device claim.
