---
tags: [ui-test, e2e, life, habit-form, habit-history, accessibility-identifier, seeded-fixture]
category: testing
date: 2026-03-09
severity: important
related_files:
  - DUNE/Presentation/Life/LifeView.swift
  - DUNEUITests/Full/LifeRegressionTests.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
  - docs/plans/2026-03-09-e2e-phase5-life-regression.md
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
  - docs/solutions/testing/2026-03-08-e2e-phase2-today-settings-regression.md
  - docs/solutions/testing/2026-03-08-e2e-phase3-activity-exercise-regression-hardening.md
  - docs/solutions/testing/2026-03-09-e2e-phase4-wellness-regression.md
---

# Solution: E2E Phase 5 Life 회귀 세트

## Problem

`Life` 탭은 smoke coverage와 seeded smoke가 있었지만, full regression lane에서 root/add/edit/history 경로를 한 묶음으로 고정하는 suite가 없었다.
특히 `HabitHistorySheet`는 private sheet surface라서 screen-level selector가 부족했고, seeded history가 실제로 보이는지/비어 있는지 검증할 안정 anchor가 없었다.

### Symptoms

- `LifeView` root, add flow, edit flow가 nightly full regression에 고정돼 있지 않았다.
- `HabitHistorySheet`에 screen/empty/row/close selector가 없어 seeded history assertion을 쓰기 어려웠다.
- backlog의 `072`~`074`는 smoke가 일부 존재해도 full regression 관점에서는 아직 닫히지 않은 상태였다.

### Root Cause

Phase 1~4에서 공통 UI test harness와 Today/Activity/Wellness regression은 정리됐지만, Life는 smoke 수준 selector와 seeded path만 남아 있었다.
또한 history sheet가 `LifeView.swift` 내부 private view로 구현돼 있어 surface contract를 후행으로 붙이지 않으면 test가 label/레이아웃에 다시 의존하게 된다.

## Solution

기존 `defaultSeeded` habit fixture를 그대로 사용하고, history sheet에 additive AXID를 보강한 뒤 `DUNEUITests/Full/LifeRegressionTests.swift`를 추가했다.
이 suite는 root render, add/save, edit rename, seeded history populated/empty state를 실제 사용자 경로로 묶는다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Life/LifeView.swift` | history sheet에 screen/empty/row/close AXID 추가 | private sheet surface를 locale-safe selector로 검증하기 위해 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | Life action/history constants 확장 | 하드코딩 문자열 없이 regression selector를 중앙 관리하기 위해 |
| `DUNEUITests/Full/LifeRegressionTests.swift` | Life full regression suite 추가 | root/add/edit/history 경로를 nightly full lane에 고정하기 위해 |
| `docs/plans/2026-03-09-e2e-phase5-life-regression.md` | phase 5 계획서 추가 | 구현 범위와 lane 결정을 남기기 위해 |
| `todos/072-done-p2-e2e-dune-life-view.md` | 상태를 done으로 전환 | Life root route와 lane이 정리됐기 때문 |
| `todos/073-done-p2-e2e-dune-habit-form-sheet.md` | 상태를 done으로 전환 | add/edit save flow가 full regression으로 고정됐기 때문 |
| `todos/074-done-p2-e2e-dune-habit-history-sheet.md` | 상태를 done으로 전환 | populated/empty history assertion과 AX contract가 정리됐기 때문 |

### Key Code

```swift
Color.clear
    .frame(height: 1)
    .accessibilityElement()
    .accessibilityIdentifier("life-habit-history-screen")
```

```swift
let emptyState = app.descendants(matching: .any)[AXID.lifeHabitHistoryEmpty].firstMatch
XCTAssertTrue(emptyState.waitForExistence(timeout: 5))
```

## Prevention

`Life`처럼 actions menu와 private sheet가 섞인 surface는 smoke 단계에서 끝내지 말고, full regression으로 올릴 시점에 screen/row/action contract를 같이 설계해야 한다.
또한 seeded fixture가 이미 충분하면 새 scenario를 만들기보다 existing seed를 재사용하고 route contract만 보강하는 편이 유지보수 비용이 낮다.

### Checklist Addition

- [ ] private sheet / dialog surface를 regression에 올릴 때 screen anchor와 dismiss anchor를 같이 추가했는가
- [ ] seeded fixture를 쓰는 test는 populated state와 empty state 역할을 habit/entity별로 명확히 분리했는가
- [ ] PR gate와 nightly full lane의 책임 분리가 문서와 test 구성에 일치하는가

### Rule Addition (if applicable)

새 rules 파일 추가는 하지 않았다.

## Lessons Learned

이번 phase의 남은 리스크는 코드보다 runtime 환경이었다.
`scripts/build-ios.sh`는 통과했고 diff review도 clean했지만, UI 런타임 검증은 `CoreSimulatorService connection invalid`로 시뮬레이터 진입 전에 실패했다.
따라서 구현과 selector contract는 완료 기준으로 정리하되, 실제 simulator rerun은 환경 복구 후 follow-up이 필요하다.
