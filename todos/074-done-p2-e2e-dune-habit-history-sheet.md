---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNE HabitHistorySheet

- Target: `DUNE`
- Source: `DUNE/Presentation/Life/LifeView.swift`
- Entry: `LifeView` habit history action
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: `life-habit-history-screen`, `life-habit-history-empty`, `life-habit-history-close`, `life-habit-history-row-*` anchor를 추가했고, seeded populated/empty history assertions를 `LifeRegressionTests`에 연결했다.
