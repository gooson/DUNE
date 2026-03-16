---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-16
---

# E2E Surface: DUNE DashboardView

- Target: `DUNE`
- Source: `DUNE/Presentation/Dashboard/DashboardView.swift`
- Entry: `Today` tab root
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: PR gate는 `DUNEUITests/Smoke/DashboardSmokeTests.swift`로 root toolbar/render를 유지하고, seeded scroll-to-top closeout은 `DUNEUITests/Full/TodaySettingsRegressionTests.swift`에서 nightly lane으로 검증한다.
- Implementation: `DUNEUITests/Smoke/DashboardSmokeTests.swift`, `DUNEUITests/Full/TodaySettingsRegressionTests.swift`
