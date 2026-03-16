---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-16
---

# E2E Surface: DUNE ExerciseDefaultsListView

- Target: `DUNE`
- Source: `DUNE/Presentation/Settings/Components/ExerciseDefaultsListView.swift`
- Entry: `SettingsView` > Exercise Defaults
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: settings child surface with list / row routing coverage pending
- Implementation: `DUNEUITests/Full/TodaySettingsRegressionTests.swift`
- Lane: full regression seeded settings flow
