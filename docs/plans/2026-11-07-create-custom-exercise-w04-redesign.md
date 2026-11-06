# B09 W03 / W04 private source preparation

Frozen source: `2e17b2e3f0769980d340e308f41dd2f7f1d25e66` in `/Users/shanks/.codex/worktrees/detail-posture-b05/Health`. This directory is a private candidate only. No repository files, SDK, simulator, or `.claude/**` files were changed. No runtime pass is claimed.

| Screen | Source | Baseline SHA-256 | Candidate SHA-256 | Private files |
|---|---|---|---|---|
| W03 Exercise detail sheet | `DUNE/Presentation/Exercise/Components/ExerciseDetailSheet.swift` | `61052b601234a318c1cc82e782b8c83ca5525da287b610e341cc21e3e7f35607` | `9637eac2dbf5d52b978cc4590d5327cfb4e26a15b8794d5e8cef14c022570e8d` | `W03/ExerciseDetailSheet.swift`, `W03/ExerciseDetailSheet.swift.patch`, `W03/layout-direction.html` |
| W04 Custom exercise form | `DUNE/Presentation/Exercise/Components/CreateCustomExerciseView.swift` | `a414c0533a9d08c6a951577afda8064142eb65b8dc6a34f4f6bb0dbb19f47957` | `addd52da14aab7f5b50b0894e3587455ab4e7b51cc9b6a7aaaa29d99786f1ad0` | `W04/CreateCustomExerciseView.swift`, `W04/CreateCustomExerciseView.swift.patch`, `W04/layout-direction.html` |

Both patches passed `git apply --check` against the frozen worktree. They have **not** been applied or built.

## Map and visual basis

The full redesign index maps W03 to ExerciseDetailSheet and W04 to CreateCustomExerciseView, with “stable surface / reduced motif” direction. Existing regular/iPad native before PNGs are copied beside each private HTML direction map; these are historical captures, not B09 after proof. The theme map's Desert Horizon direction and sheet wave surface remain the basis. No new color, asset, string key, metric, score, or synthetic exercise is proposed. Before repo implementation, create/link dedicated `docs/design/layout-map/exercise-detail-w03.html` and `.../create-custom-exercise-w04.html`, plus theme direction as required by AGENTS; after implementation, fresh impacted-device actual captures and map reconciliation remain required.

## W03 candidate

- Preserve the sheet NavigationStack, Close and Start toolbar actions and order (`dismiss()` then `onSelect()`), equipment SVGs, localized names, category/equipment metadata, description/form cues, muscle map and legend, equipment explanation, input type and MET.
- At accessibility text sizes, stack the icon above names and category/equipment metadata vertically; at regular sizes retain the existing HStack. Give the title a multiline vertical fit, cue-number circles a 24 pt minimum, and Input/MET separate rows at accessibility sizes.
- Data/period contract: W03 displays the supplied ExerciseDefinition and has no period picker. No data query, formatter, persistence, or model changes.
- Existing consumers: ExercisePickerView sheet, SuggestedWorkoutCard, Activity SuggestedWorkoutSection. Focused existing selectors: `ActivityExerciseRegressionTests/testQuickStartPickerShowsDetailAndSearchResults` and `ActivityExercisePickerRegressionTests/testQuickStartPickerCanRevealAllExercisesAndOpenDetail`. New opt-in normal/MAX visual capture is warranted because the candidate changes Dynamic Type layout.
- Risk: long Korean/Japanese labels and the equipment description can still require scroll on small sheets; native MAX capture is needed. Header extraction should retain both labels and SVG in AX.

## W04 candidate

- Preserve Form, name field, category state transition, user-category choice, input type/cardio unit pickers, muscle selection, equipment picker, Cancel/Create, all validation guards, CustomExercise insertion, dismiss/onCreated sequence, and persisted values.
- Keep the five-category segmented picker at ordinary text sizes; use a native menu only at accessibility text sizes so full labels are reachable. Mark selected custom-category and muscle chips with AX selected traits; preserve their buttons and IDs. Existing one-column muscle grid at accessibility sizes remains.
- Data/period contract: no period control here. `@Query` user categories, selected types and equipment, validation and SwiftData write are untouched. No new external state or data exposure.
- Existing consumers: ExercisePickerView custom-create sheet. Focused existing selectors: `ActivityExerciseRegressionTests/testVisualAuditNewExerciseAtDefaultTextSize`, `testVisualAuditCustomMuscleChipFoldReadability`, plus the custom-create path in `testTemplateListSupportsCreateEditAndTemplateStart`. The fold audit is opt-in and should only be run under its existing device gate; no replay of prior failed states is proposed.
- Risk: accessibility menu representation changes the native control type at MAX; targeted native AX and selection readback should confirm all five categories and the input-type reset. The user-category horizontal list remains scrollable.

## Static security/data review

No new network, HealthKit, storage, permissions, user input parser, deletion, or navigation destination is introduced. W03 is presentation-only. W04 changes picker presentation and AX traits; `onChange` remains attached to the same `selectedCategory` binding, and validation/persistence code is byte-identical. Existing localized UI strings and catalog keys are reused. Source-only review cannot establish native layout, hit targets, VoiceOver order, or SDK compilation.

## B09 shared core contract

W01/W02/W03 normal and MAX library→picker→detail→Close; native Cancel or original exercise selection. W04 normal/MAX existing Category selection and InputType reset, disabled empty Create, Cancel; unchanged parser/persistence statically reviewed. Exact four phone selectors in ActivityExercisePickerRegressionTests; affected iPad subset after phone. Same target incremental build reused, no separate phase builds or full local regression. Fresh PNG/AX and per-screen actual-map/independent reviews/compound/PR/normal merge. No currentDuo execution after fresh owned migrationfailure; markmissing, never relabeloldPNG. P03/P08/S03/H08 limits preserved.
