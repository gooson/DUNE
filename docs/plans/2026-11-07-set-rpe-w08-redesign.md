# B11 W07/W08/W09 private source candidates

Source freeze: `4fd3b3aadfa39908948538587aea81856ad14c48` in `/Users/shanks/.codex/worktrees/detail-posture-b05/Health`. These three files were unchanged from earlier app source, verified by SHA-256 in `manifest.json`. All files here are private preparation; no repository edit or SDK run.

## Screen mapping and visual scope

- W07 `RestTimerView.swift`: in-session rest card. At accessibility text sizes, stack existing +30s and Skip controls, preserve timer readout/progress/stop/addTime and original iconless buttons. Source consumers: `TemplateWorkoutView`, `CompoundWorkoutView`. The current reachable flow is Compound; no `TemplateWorkoutView(` instantiation was found in app source. The Activity multi-template route uses `TemplateWorkoutContainerView` → `WorkoutSessionView`, whose inline rest timer is different, so its rest tests do not prove W07.
- W08 `SetRPEPickerView.swift`: set RPE control. At accessibility sizes, stack value and descriptive label and allow all five original category labels to scroll horizontally. Preserve 6–10, 0.5 step, color levels, `rpe` Binding, activate/clear/help and existing questionmark/xmark icons. Source consumers: single, template, compound session views; the reachable W07 + W08 combined route is Compound.
- W09 `RPEHelpSheet.swift`: help sheet opened from W08. At accessibility sizes, stack each row instead of fixed 40/80 point columns and permit large sheet detent. Preserve row order, RIR meanings, Done/dismiss, medium detent, lightbulb and wave background. Only W08 opens it.

`layout-theme.html` in each directory is a proposal diagram, **not** an actual capture. Actual/full inventory: `docs/design/full-redesign-map/index.html` W07–W09; existing actual screenshots under `docs/design/phone-design-map/actual/{regular,ipad,duo,duo-open}/images/W0*.png`. The 4-tab layout and theme maps are the current design references; implementation must create linked screen-specific layout maps and refresh affected actual maps from new captures. No theme token or localized string changes are proposed.

## Static boundaries and focused selectors

- No model, persistence, draft serialization, Live Activity, Watch, timer model, RPELevel, localization, or navigation changes. Watch has no direct consumer of these three iOS components. Session consumers listed above must be checked after application.
- Existing `ActivityExerciseRegressionTests/testVisualAuditSetRPEAndHelp` covers W08 active slider and W09 sheet, normal text. Existing `testCompoundWorkoutSetupStartsWorkoutAndFinishesFlow` reaches W07 Skip after completing a set. `testVisualAuditTemplateWorkoutFirstSession` enters `WorkoutSessionView` through `TemplateWorkoutContainerView` and does not cover W07. The added private test candidate uses the Compound route. A new narrow normal/MAX capture selector should exercise W07 Skip and W08 active/Help/Done at accessibility size; do not claim current tests prove MAX.
- Scope gate: one focused build and only the selectors relevant to the applied screens, one owned simulator at a time. Parent owns test design, execution and actual-map reconciliation. Duo remains pending if no owned device is available.

## Risks for review

- W07 vertical buttons increase rest card height in template and compound session scroll containers; verify Skip is reachable at MAX.
- W08 horizontal legend is nested in vertical session scroll; verify all five labels and slider hit region remain reachable at MAX. Original numeric RPE mapping is untouched.
- W09 medium sheet may initially show fewer rows at MAX; verify scrolling and optional large detent expose all rows and Done. No runtime claim is made here.

Parent source review: W09 AX rows use full-width leading frames so intrinsic-width VStack cards do not center each range at different x positions. Regular HStack already had Spacer; no data/action change. Candidate and patch hashes refreshed before implementation.

Pre-SDK review correction: the MAX-only W08 horizontal category ScrollView now has `set-rpe-category-labels` as an accessibility identifier. This has no visual, binding, or string effect; the focused MAX test pans to the original final `Max` category and captures the end state.

## B11 exact core contract

Map before app. Two opt-in normal/MAX Compound cases: existing setup→first set complete→W07 +30/Skip→W08 activate+legend/slider→W09 allfourrows/Done. RPE onlyrenderscompletedrows; TemplateWorkoutView uninstantiated and QuickStarttemplate→W6inline rest cannot proveW07. NoFinish/save, no newfixtures, no closedB10Phone/W31 selector. OneownedSDKdeadline, sameincrementalcache. Newnative PNGAX/independentreviews/actualmap/compound/per-screen PRs. Original H08/P03/P08/S03/W04/W31 failurelimits remain. Duo current captures absent after freshdevice migrationfailure; do notpromoteoldPNGs. Apply only B11testpatch to currentmain; full private testcandidate includesB10draft harness and mustnotcopywholesale.

## Scoped result

[Original receipts: Phone MAX and iPad normal/MAX native PNG/AX](../design/full-redesign-map/review/set-rpe-w08-2026-11-07/index.html). Phone normal and Duo captures remain pending; historical images are not after evidence. App scope SHA-256: `0c438d0b6858f781386d906ba928612a2ce6aa9b9831ac8683cad640f264bff0`.
