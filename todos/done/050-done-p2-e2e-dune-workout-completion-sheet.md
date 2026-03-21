---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-21
---

# E2E Surface: DUNE WorkoutCompletionSheet

- Target: `DUNE`
- Source: `DUNE/Presentation/Exercise/Components/WorkoutCompletionSheet.swift`
- Entry: `WorkoutSessionView` finish action
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: completion presentation and dismissal back to Exercise root are covered; share follow-up remains outside this closeout.
- Implementation: `DUNEUITests/Full/ActivityExerciseRegressionTests.swift`
- Lane: full regression seeded manual workout completion flow
