---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-16
---

# E2E Surface: DUNE ActivityView

- Target: `DUNE`
- Source: `DUNE/Presentation/Activity/ActivityView.swift`
- Entry: `Activity` tab root
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: existing smoke coverage in `DUNEUITests/Smoke/ActivitySmokeTests.swift`
- Implementation: `DUNEUITests/Smoke/ActivitySmokeTests.swift`, `DUNEUITests/Full/ActivityExerciseRegressionTests.swift`
- Lane: PR smoke + full regression seeded activity flow
