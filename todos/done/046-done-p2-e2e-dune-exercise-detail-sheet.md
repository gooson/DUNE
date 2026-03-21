---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-21
---

# E2E Surface: DUNE ExerciseDetailSheet

- Target: `DUNE`
- Source: `DUNE/Presentation/Exercise/Components/ExerciseDetailSheet.swift`
- Entry: `ExercisePickerView` detail action
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: detail sheet open, close, and start split are covered from both quick start and full picker lanes.
- Implementation: `DUNEUITests/Full/ActivityExerciseRegressionTests.swift`, `DUNEUITests/Full/ActivityExercisePickerRegressionTests.swift`
- Lane: full regression seeded picker search and quick start flow
