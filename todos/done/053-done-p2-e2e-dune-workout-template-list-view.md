---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-21
---

# E2E Surface: DUNE WorkoutTemplateListView

- Target: `DUNE`
- Source: `DUNE/Presentation/Exercise/Components/WorkoutTemplateListView.swift`
- Entry: `ExerciseView` templates action
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: template list root, create, edit, and start handoff are covered in seeded template flows.
- Implementation: `DUNEUITests/Full/ActivityExerciseRegressionTests.swift`
- Lane: full regression seeded template management flow
