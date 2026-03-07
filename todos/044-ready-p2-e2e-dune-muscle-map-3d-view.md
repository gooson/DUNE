---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: ready
created: 2026-03-08
updated: 2026-03-08
---

# E2E Surface: DUNE MuscleMap3DView

- Target: `DUNE`
- Source: `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift`
- Entry: `MuscleMapDetailView` 3D route
- [ ] entry route와 target lane을 정의한다.
- [ ] AXID / selector inventory를 고정한다.
- [ ] 주요 state와 assertion 범위를 정리한다.
- [ ] PR gate / nightly 배치를 확정한다.
- Notes: 3D rendering path is must-have on iOS, but needs simulator-safe assertions
