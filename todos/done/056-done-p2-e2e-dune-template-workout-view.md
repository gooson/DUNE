---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-21
---

# E2E Surface: DUNE TemplateWorkoutView

- Target: `DUNE`
- Source: `DUNE/Presentation/Exercise/TemplateWorkoutView.swift`
- Entry: `TemplateWorkoutContainerView` core screen
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: current app wiring no longer instantiates `TemplateWorkoutView.swift` directly; closeout is anchored to the active `TemplateWorkoutContainerView` -> `WorkoutSessionView` route and this file is treated as legacy/orphaned surface inventory.
- Implementation: `DUNEUITests/Full/ActivityExerciseRegressionTests.swift`
- Lane: legacy template lane validated through current container and session flow
