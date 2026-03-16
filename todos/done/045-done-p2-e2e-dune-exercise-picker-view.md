---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNE ExercisePickerView

- Target: `DUNE`
- Source: `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift`
- Entry: activity toolbar add or exercise add actions
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: PR smoke는 기존 open/search 검증을 유지하고, quick start hub/full picker filter 회귀는 dedicated full regression으로 분리했다.
- Implementation: `DUNEUITests/Full/ActivityExercisePickerRegressionTests.swift`
