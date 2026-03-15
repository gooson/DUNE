---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-16
---

# E2E Surface: DUNE ConditionScoreDetailView

- Target: `DUNE`
- Source: `DUNE/Presentation/Dashboard/ConditionScoreDetailView.swift`
- Entry: `DashboardView` hero card tap
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: seeded Today hero route는 `DUNEUITests/Full/TodaySettingsRegressionTests.swift`에서 closeout했고, deeper chart/detail interaction coverage는 dedicated condition/chart regressions가 계속 담당한다.
- Implementation: `DUNEUITests/Full/TodaySettingsRegressionTests.swift`
