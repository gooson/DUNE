---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-16
---

# E2E Surface: DUNE NotificationHubView

- Target: `DUNE`
- Source: `DUNE/Presentation/Dashboard/NotificationHubView.swift`
- Entry: dashboard toolbar notification tap
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: PR gate는 `DUNEUITests/Smoke/DashboardSmokeTests.swift`에서 hub open/control 존재를 유지하고, nightly lane은 `DUNEUITests/Full/TodaySettingsRegressionTests.swift` + `DUNEUITests/Full/TodaySettingsEmptyStateRegressionTests.swift`로 seeded control transition과 empty state를 닫는다.
- Implementation: `DUNEUITests/Smoke/DashboardSmokeTests.swift`, `DUNEUITests/Full/TodaySettingsRegressionTests.swift`, `DUNEUITests/Full/TodaySettingsEmptyStateRegressionTests.swift`
