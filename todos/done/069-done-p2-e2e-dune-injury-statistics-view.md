---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNE InjuryStatisticsView

- Target: `DUNE`
- Source: `DUNE/Presentation/Injury/InjuryStatisticsView.swift`
- Entry: `InjuryHistoryView` statistics route
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: `injury-statistics-screen` anchor를 추가해 history -> statistics route를 안정화했다. chart content deep assertion은 후속 범위다.
