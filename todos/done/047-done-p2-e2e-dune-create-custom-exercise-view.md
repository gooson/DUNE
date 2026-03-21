---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-21
---

# E2E Surface: DUNE CreateCustomExerciseView

- Target: `DUNE`
- Source: `DUNE/Presentation/Exercise/Components/CreateCustomExerciseView.swift`
- Entry: `ExercisePickerView` custom create flow
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: create form input and save-return route are covered from the template authoring flow.
- Implementation: `DUNEUITests/Full/ActivityExerciseRegressionTests.swift`
- Lane: full regression seeded template authoring flow
