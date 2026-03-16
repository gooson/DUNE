---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-16
---

# E2E Surface: DUNE WeeklyStatsDetailView

- Target: `DUNE`
- Source: `DUNE/Presentation/Activity/WeeklyStats/WeeklyStatsDetailView.swift`
- Entry: `ActivityView` weekly stats section tap
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: chart, period switching, and iPad layout parity need coverage
- Implementation: `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift`
- Lane: full regression seeded chart interaction flow
