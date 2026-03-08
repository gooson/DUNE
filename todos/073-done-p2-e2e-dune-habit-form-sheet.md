---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNE HabitFormSheet

- Target: `DUNE`
- Source: `DUNE/Presentation/Life/HabitFormSheet.swift`
- Entry: `LifeView` add or edit habit flow
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: 기존 form field/action AXID를 재사용해 `LifeRegressionTests`에서 add save와 edit rename flow를 full regression으로 연결했다. validation/frequency switching은 기존 smoke coverage가 계속 담당한다.
