---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-16
---

# E2E Surface: DUNE CloudSyncConsentView

- Target: `DUNE`
- Source: `DUNE/Presentation/Shared/CloudSyncConsentView.swift`
- Entry: cloud-sync consent route from app launch or settings
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: force-show launch hook route는 `DUNEUITests/Full/CloudSyncConsentRegressionTests.swift`에서 닫았고, real launch branching / sync decision permutations는 specialized follow-up lane으로 유지한다.
- Implementation: `DUNEUITests/Full/CloudSyncConsentRegressionTests.swift`
