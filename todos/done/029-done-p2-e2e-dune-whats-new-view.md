---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-16
---

# E2E Surface: DUNE WhatsNewView

- Target: `DUNE`
- Source: `DUNE/Presentation/WhatsNew/WhatsNewView.swift`
- Entry: dashboard toolbar or settings row
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: toolbar/settings entry와 release detail smoke는 `DUNEUITests/Smoke/DashboardSmokeTests.swift` 및 `DUNEUITests/Smoke/SettingsSmokeTests.swift`에서 유지한다. deeper release-card permutations는 현재 smoke/detail lane 범위 안에서 계속 관리한다.
- Implementation: `DUNEUITests/Smoke/DashboardSmokeTests.swift`, `DUNEUITests/Smoke/SettingsSmokeTests.swift`
