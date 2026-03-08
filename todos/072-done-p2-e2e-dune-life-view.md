---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNE LifeView

- Target: `DUNE`
- Source: `DUNE/Presentation/Life/LifeView.swift`
- Entry: `Life` tab root
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: existing `DUNEUITests/Smoke/LifeSmokeTests.swift`는 PR gate smoke로 유지하고, `DUNEUITests/Full/LifeRegressionTests.swift`가 seeded root/add path를 nightly full lane에 고정한다.
