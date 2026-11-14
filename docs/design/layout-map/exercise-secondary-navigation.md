# ExerciseView secondary navigation · iPad

This is a component navigation contract for `ExerciseView`, reached from Activity → Recent Workouts → See All. It does not introduce a catalog screen ID and does not describe the exercise library (W01).

- iPad: top-leading More menu contains Templates (`list.clipboard`) and Categories (`tag`). Each choice opens the existing destination from `ExerciseView`.
- iPhone: top-leading Templates and Categories remain direct toolbar links.
- Templates keeps `WorkoutTemplateListView` and the existing `startFromTemplate` callback; Categories keeps `UserCategoryManagementView`.
- The system Menu may render its own visual treatment. The selected entry must be visible and tappable at normal and maximum text sizes.

Actual iPad menu and destination captures: [2026-11-14 supplemental gallery](../phone-design-map/actual/route-support-2026-11-14/index.html). Those are native XCTest PNG+AX evidence for the component route, not new screen-count entries. W12 and W29 remain the destinations' catalog identities.
