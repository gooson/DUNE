# B13 private template authoring preparation

Baseline: latest fetched `origin/main` `770809e12b8f2b797be56ab2e8d401bb8f9ae8d8`. Exact baseline/candidate hashes and member scopes are in `manifest.json`. W12/W13/W15 have separate full candidate sources and patches; W14 and W34 have explicit no-patch decisions. All three patches pass `git apply --check` and private Swift candidates pass `xcrun swiftc -frontend -parse`. No app repository edit, SDK, simulator, new worktree or native pass.

## Screen identity, source and scope

- W12: `WorkoutTemplateListView.templateRow` in the template list. MAX stacks exercise count and first three exercise names and allows name wrapping; existing native `List`, query order, Watch sync, Start, swipe Edit/Delete and confirmation are unchanged.
- W13: `CreateTemplateView.swift` `TemplateFormView.entryRow` and `sessionDrivenSummary` only. MAX allows long exercise name and session-driven summary labels to wrap/stack. Existing strength sets/reps/weight/rest controls, binding, validation, AI generator, Save/Cancel, order/move/delete and stored values are unchanged.
- W14: same source file, `TemplateExercisePickerSheet` member only. This is a thin wrapper around the shared `ExercisePickerView(mode: .full)`, already redesigned as W02. No W14-specific display layout or data transformation exists to change safely, so candidate is a focused test/map proof with **no app patch**. The W13 patch does not touch this member.
- W15: `WeeklyWorkoutPlanView` day row and week arrow hit regions. MAX stacks day and template name; arrows get 44pt frames. Seven-day period calculation, selected date, adaptive panes, local plan encoding, template assignment/removal, drag/drop and Start remain unchanged.
- W34: queue ID exists, but no identity/source in full-redesign map, screen inventory, actual capture indices, or handoff notes. Held as unmapped; no invented app source, HTML screen contract or runtime claim.

The per-screen `layout-theme.html` files are static private before/proposal diagrams, **not** actual captures. W12–W15 identity came from `docs/design/full-redesign-map/index.html` and `docs/design/phone-design-map/screen-inventory.md`; current 4-tab layout and theme maps remain references. Applied work must define linked screen-specific layout maps and refresh affected actual maps from fresh native PNG/AX. No new theme token, localized key, icon, score or default value is proposed.

## Source-only data, UX and performance proof

- `WorkoutTemplateListView` keeps `@Query(sort: updatedAt, order: .reverse)` and List virtualization. Row view reads each template; no new per-row fetch or card wrapper. Watch sync callbacks are untouched.
- `TemplateFormView` retains all state bindings and `saveTemplate()` validation/clamping/insert/edit. The W13 patch changes only text layout in display members. W14 wrapper still appends `TemplateExerciseResolver.defaultEntry(for:)` and dismisses picker after selection.
- `WeeklyWorkoutPlanView` retains `@AppStorage("workout.weeklyPlan.v1")`, `days` week computation, `assign`, `shiftWeek` and two-pane `AdaptivePaneView`; only day label layout and navigation button frame change.
- No Watch, HealthKit, services, models, seeder, parser, file format, localization or navigation destination changes. W12 large titles may increase List row height, W13 Form may need more scrolling at MAX, W15 two-pane balance must be reviewed on iPad. These are native risks, not verified failures.

## Focused test plan

1. **W13→W14, normal/MAX (phone+iPad)**: use existing Activity AI Workout Builder entry (`testActivityAIWorkoutBuilderOpensTemplateForm`) to open a blank form without Exercise Templates toolbar. Assert empty Save disabled, tap existing Add Exercise, capture full shared picker with Create Custom and a seeded exercise row, select a known exercise, assert form return and default controls/Save enabled, capture long name/defaults, then Cancel. No AI generation, custom creation, or persistence write. This route avoids the closed B09 iPad native More/`exercise-toolbar-templates` failure.
2. **W12→W15, normal/MAX (phone)**: reuse existing `openTemplateList` / `testWeeklyPlanAssignsTemplateToSelectedDay` entry after its direct toolbar button is observed. Capture native List row name/count/first three names, open Weekly Workout Plan, capture seven-day list and selected pane, shift week forward/back, select seeded template and Remove only if using isolated fixture. Avoid full `testTemplateListSupportsCreateEditAndTemplateStart` flow and its W04 custom-create path. iPad W12/W15 remains pending until the known native More route has a new source-grounded fix; do not rerun the closed B09 failure merely for this batch.
3. W34 is not test-selectable until its screen identity and entry route are documented. No selector is invented.

Existing exact methods: `ActivityExerciseRegressionTests/testActivityAIWorkoutBuilderOpensTemplateForm`, `testWeeklyPlanAssignsTemplateToSelectedDay`, `testTemplateEntryDefaultsRemainEditableAtMaximumAccessibilityTextSize`, and `testTemplateListSupportsCreateEditAndTemplateStart` (last is broad and not selected). Minimal new cases would be four selectors, two per flow at normal/MAX. Parent owns test implementation and runtime gates.

## W12 실행 계약

맵 등록 후 구현한다. W12/W15는 Phone 일반·MAX, W13/W14는 Phone+iPad 일반·MAX로 필요한 4+2 selectors만 증분 빌드와 묶어 실행한다. W12/W15 iPad는 이전 More 진입 실패 한도를 유지하며 같은 경로를 재실행하지 않는다. W14는 W02 공유 picker 소비자라 앱 소스 변경 없이 새 진입 경로·선택·실제 캡처만 증빙한다. W34는 식별 미확인이므로 구현·캡처를 만들지 않는다. 기존 값·기능·아이콘·기간·시각 강조·Save 검증을 보존한다. 원본 실패와 PNG/AX, 독립 리뷰, 실제맵·문서화·화면별 PR을 유지한다. Duo새캡처는 불가상태를 명시한다. H08/P03/P08/S03/W04/W31/W11/W26 및 B12Phone의 닫힌 한도는 유지한다.
