---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-16
---

# E2E Surface: DUNE WeatherDetailView

- Target: `DUNE`
- Source: `DUNE/Presentation/Dashboard/WeatherDetailView.swift`
- Entry: `DashboardView` weather card tap
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: seeded weather-card route는 `DUNEUITests/Full/TodaySettingsRegressionTests.swift`에서 고정했고, weather permission / empty-state branch는 기존 메모대로 specialized follow-up lane으로 유지한다.
- Implementation: `DUNEUITests/Full/TodaySettingsRegressionTests.swift`
