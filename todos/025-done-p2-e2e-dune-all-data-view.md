---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-16
---

# E2E Surface: DUNE AllDataView

- Target: `DUNE`
- Source: `DUNE/Presentation/Shared/Detail/AllDataView.swift`
- Entry: dashboard / wellness all-data routes
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: phase 2 closeout은 Today `sleep` metric detail의 `Show All Data` route를 `DUNEUITests/Full/TodaySettingsRegressionTests.swift`에서 닫았고, empty-state 또는 category-specific list semantics는 shared metric follow-up에서 계속 확장한다.
- Implementation: `DUNEUITests/Full/TodaySettingsRegressionTests.swift`
