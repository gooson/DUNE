---
source: brainstorm/e2e-ui-test-plan-all-targets
priority: p2
status: done
created: 2026-03-08
updated: 2026-03-09
---

# E2E Surface: DUNE BodyCompositionFormSheet

- Target: `DUNE`
- Source: `DUNE/Presentation/BodyComposition/BodyCompositionFormSheet.swift`
- Entry: `WellnessView` add menu > Body Record
- [x] entry route와 target lane을 정의한다.
- [x] AXID / selector inventory를 고정한다.
- [x] 주요 state와 assertion 범위를 정리한다.
- [x] PR gate / nightly 배치를 확정한다.
- Notes: `body-form-screen` anchor를 추가했고 add/edit/save flow를 full regression에 연결했다. cancel path는 이번 batch의 핵심 assertion에는 포함하지 않았다.
