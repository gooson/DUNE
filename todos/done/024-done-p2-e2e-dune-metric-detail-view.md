---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-16
---

# E2E Surface: DUNE MetricDetailView

- Target: `DUNE`
- Source: `DUNE/Presentation/Shared/Detail/MetricDetailView.swift`
- Entry: dashboard / wellness metric card tap
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: phase 2 closeout은 Today `sleep` metric route를 기준으로 `DUNEUITests/Full/TodaySettingsRegressionTests.swift`에서 검증했고, chart gesture 및 cross-category shared detail behavior는 dedicated regression suites가 계속 추적한다.
- Implementation: `DUNEUITests/Full/TodaySettingsRegressionTests.swift`
