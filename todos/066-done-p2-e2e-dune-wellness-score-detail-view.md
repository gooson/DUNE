---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNE WellnessScoreDetailView

- Target: `DUNE`
- Source: `DUNE/Presentation/Wellness/WellnessScoreDetailView.swift`
- Entry: `WellnessView` hero card tap
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: hero -> detail route용 `wellness-score-detail-screen` anchor를 추가했다. score breakdown/chart assertion 확장은 후속 범위다.
