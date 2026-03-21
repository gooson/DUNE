---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-21
---

# E2E Surface: DUNE ExerciseMixDetailView

- Target: `DUNE`
- Source: `DUNE/Presentation/Activity/ExerciseMix/ExerciseMixDetailView.swift`
- Entry: `ActivityView` exercise mix section tap
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: exercise mix detail route open coverage is fixed; deeper chart rendering and seeded distribution assertions remain deferred.
- Implementation: `DUNEUITests/Full/ActivityExerciseRegressionTests.swift`
- Lane: full regression seeded activity detail flow
