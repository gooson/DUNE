---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-16
---

# E2E Surface: DUNE PinnedMetricsEditorView

- Target: `DUNE`
- Source: `DUNE/Presentation/Dashboard/Components/PinnedMetricsEditorView.swift`
- Entry: dashboard pinned metrics edit action
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: phase 2 closeout은 `DUNEUITests/Full/TodaySettingsRegressionTests.swift`에서 open/dismiss path를 닫았고, pinned selection persistence 같은 deeper state assertions는 기존 메모대로 후속 lane으로 남긴다.
- Implementation: `DUNEUITests/Full/TodaySettingsRegressionTests.swift`
