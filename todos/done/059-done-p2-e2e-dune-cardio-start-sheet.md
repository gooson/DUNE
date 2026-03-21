---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-21
---

# E2E Surface: DUNE CardioStartSheet

- Target: `DUNE`
- Source: `DUNE/Presentation/Exercise/CardioSession/CardioStartSheet.swift`
- Entry: cardio quick-start branch
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: cardio detail-to-start-sheet route and indoor branch are covered; permission-sensitive outdoor nuances remain documented follow-up.
- Implementation: `DUNEUITests/Full/ActivityExerciseRegressionTests.swift`
- Lane: full regression seeded cardio start flow
