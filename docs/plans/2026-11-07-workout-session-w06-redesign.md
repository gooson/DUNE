# B10 W05 / W06 / W31 private source preparation

Frozen baseline: `f049504adacaf170e7e7b41eb54fd781eef5fb04` in `/Users/shanks/.codex/worktrees/detail-posture-b05/Health`. Private source-only candidates; no repository edit, SDK/simulator use, runtime pass, model/data change, or `.claude/**` edit.

| Screen | Source | Baseline SHA-256 | Candidate SHA-256 | Private patch |
|---|---|---|---|---|
| W05 Exercise Start | `DUNE/Presentation/Exercise/ExerciseStartView.swift` | `bb070f3b9a44a1fe3c129e3230ef4c3bfa5bb4606a5353fd80f74139d4add9b1` | `2dc232282663f7f917a9caf993bc6643858c8d4f221a2c52a237c05b33388b9d` | `W05/ExerciseStartView.swift.patch` |
| W06 Workout Session | `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | `98412f54664513b24457cb3bbedaa692fc63cf0bfaf4fc9f612c7a4a423d5a48` | `2f9b9a27c4ff31c8bd25144c9777a4d74c43d1bab142c1db2ac05a747eafb655` | `W06/WorkoutSessionView.swift.patch` |
| W31 All Sets Done sheet | Same `WorkoutSessionView.swift` baseline | `98412f54664513b24457cb3bbedaa692fc63cf0bfaf4fc9f612c7a4a423d5a48` | `e30f998c930ca0b480adfbe9529c01dd77a9fddcbf1c3cc7007dc39ab800c5b8` | `W31/WorkoutSessionView.swift.patch` |

W06 and W31 are independent hunks in the same source file; apply together after parent review. Each directory also contains a full candidate Swift file, `layout-direction.html`, `theme-direction.html`, and copied historical regular/iPad before PNGs. These static HTML pages are proposals, not actual captures. Full-redesign map identifies W05 as `ExerciseStartView`, W06 as `WorkoutSessionView`, and W31 as the inline last-set sheet in W06. Existing theme direction is stable sheet surface and reduced motif for W05/W31, data contrast for W06. No new palette, icon, score, copy, catalog key, parser, or period control.

## W05

Candidate adds `dynamicTypeSize` only to choose an `AnyLayout` for the existing exercise icon/name/category header and equipment/default-set summary. Normal size remains horizontal; MAX stacks those existing elements vertically and permits a multiline localized exercise name. FlowLayout muscle chips, source exercise definition, template default set count, Cancel, fixed Start Workout CTA, `showSession`, cardio routing, and W06 navigation stay unchanged. Existing consumers: `ActivityView` recommendation/start sheet and `ExerciseView` picker/start sheet. Focused selectors: `ActivityExerciseRegressionTests/testRecommendedRoutineCardOpensExerciseStart` and `testCrunchCanAddAndRemoveWeightDuringSession`; a new normal/MAX capture should inspect icon/name/defaults and fixed CTA.

Risk: a long name and many muscle chips extend the sheet; scroll access and pinned CTA need native review. `AnyLayout` is expected on the current iOS target but was not compiled in this private pass.

## W06

Candidate replaces a MAX-only plain exercise name with the same existing `Label` (original activity icon + localized name) used at regular sizes, with multiline vertical fit. It changes no input, unit conversion, progress dots, set completion, rest timer, previous-set query, draft restoration/autosave, save, insights, template callback, or adaptive iPad layout. Existing consumers: W05 navigation and `TemplateWorkoutContainerView`. Focused selectors: `ActivityExerciseRegressionTests/testWorkoutDraftAndRestTimerAtMaximumAccessibilityTextSize`, `testCrunchCanAddAndRemoveWeightDuringSession`, and `testManualWorkoutSessionSavesAndDismissesCompletionSheet`. Native MAX check must verify the icon and title fit without crowding the set controls.

Risk: the restored icon may raise the overview height on compact/MAX layouts; only actual viewport and AX captures can settle this.

## W31

Candidate wraps only `allSetsDoneContent` in a ScrollView with `.scrollBounceBehavior(.basedOnSize)` and bottom spacing. The original title/check icon, optional level-up message, +1 Set action, Finish Workout/Next Exercise branch, 44 pt button minimum, sheet detents, drag indicator, and interactive-dismiss prevention remain. The ScrollView makes the action choices reachable when MAX text or a medium detent is shorter than content. W31 is an inline presentation owned by W06; no separate model or service. Focused selector: `ActivityExerciseRegressionTests/testVisualAuditLastSetOptions`; combine with targeted MAX capture/scroll and existing add-set/finish assertions if the parent adds a focused test.

Risk: ScrollView may change initial vertical placement or swipe behavior inside a medium detent; inspect both medium and large, normal and MAX. It should not change commit semantics.

## Static security/data boundaries

No added data source, state variable, permission, network call, HealthKit read, persistence path, deletion, or external action. W05 reads the same supplied exercise/template data. W06 and W31 leave `completeCurrentSet`, `addExtraSet`, `persistSessionDraft`, and `saveWorkout` byte-identical. No input validation or numeric formatting changed. Static review cannot claim Swift compilation or native readability. Before implementation, reconcile dedicated layout/theme maps in the repository under AGENTS, then after implementation capture affected regular/iPad/Duo states and update actual maps; do not relabel historical before screenshots as after.

## W06 B10 shared core contract

Map before code. Combine W05→W06→W31 normal/MAX twoexact phone selectors; affected iPad subset, one owned heavySDK at a time. Reuseincremental compile. Preserve Start/Cancel/icons/inputs/draft/sets/+1/Finish/Next; actualPNGAX nativeview andindependentreviews. Do notFinish/save invisualtests; originalactiontails staticbyteequal. Per-screen sourcehunks and PRs, compound andactualmap; no full localregression. CurrentDuo capture remains pending after failed freshdevice migration, historicalimages not currentevidence. PriorheldP03/P08/S03/H08 counterspreserved.

## Scoped result

[Source-scoped native proof and original mixed results](../design/full-redesign-map/review/workout-session-w06-2026-11-07/index.html). iPadnormal+MAXcorepassed; Phone2failedruns remain diagnostic, no selectorpass; W31Phoneheld. Sameappbytes and no phase rebuild.
