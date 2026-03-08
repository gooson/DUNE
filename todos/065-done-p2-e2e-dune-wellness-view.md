---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNE WellnessView

- Target: `DUNE`
- Source: `DUNE/Presentation/Wellness/WellnessView.swift`
- Entry: `Wellness` tab root
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: `DUNEUITests/Full/WellnessRegressionTests.swift`에서 hero, HRV card, body/injury history route를 full lane으로 고정했다. UI runtime 검증은 CoreSimulatorService 장애로 끝까지 완료하지 못했다.
