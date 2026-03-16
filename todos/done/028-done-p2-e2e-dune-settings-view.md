---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-16
---

# E2E Surface: DUNE SettingsView

- Target: `DUNE`
- Source: `DUNE/Presentation/Settings/SettingsView.swift`
- Entry: dashboard toolbar settings tap
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: PR gate smoke는 `DUNEUITests/Smoke/SettingsSmokeTests.swift`가 유지하고, phase 2 closeout에 필요한 core row reachability는 `DUNEUITests/Full/TodaySettingsRegressionTests.swift`에서 seeded Today entry 기준으로 확인한다.
- Implementation: `DUNEUITests/Smoke/SettingsSmokeTests.swift`, `DUNEUITests/Full/TodaySettingsRegressionTests.swift`
