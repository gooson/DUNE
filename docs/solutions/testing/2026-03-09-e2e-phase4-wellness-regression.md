---
tags: [ui-test, e2e, wellness, injury, body-composition, accessibility-identifier, seeded-fixture]
category: testing
date: 2026-03-09
severity: important
related_files:
  - DUNE/Presentation/BodyComposition/BodyCompositionFormSheet.swift
  - DUNE/Presentation/Injury/InjuryFormSheet.swift
  - DUNE/Presentation/Injury/InjuryHistoryView.swift
  - DUNE/Presentation/Injury/InjuryStatisticsView.swift
  - DUNE/Presentation/Wellness/BodyHistoryDetailView.swift
  - DUNE/Presentation/Wellness/WellnessScoreDetailView.swift
  - DUNE/Presentation/Wellness/WellnessView.swift
  - DUNEUITests/Full/WellnessRegressionTests.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
  - scripts/test-ui.sh
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
  - docs/solutions/testing/2026-03-08-e2e-phase2-today-settings-regression.md
  - docs/solutions/testing/2026-03-08-e2e-phase3-activity-exercise-regression-hardening.md
---

# Solution: E2E Phase 4 Wellness 회귀 세트

## Problem

Wellness 탭은 smoke coverage와 일부 chart regression은 있었지만, hero detail, body/injury history route, statistics route, form add/edit save 흐름이 full regression lane에 고정되어 있지 않았다.

### Symptoms

- Wellness hero -> detail route가 full regression에 고정돼 있지 않았다.
- Body history / injury history / statistics route를 locale-safe selector로 탐색하기 어려웠다.
- Body/Injury form과 history/detail surface에 screen-level anchor가 부족했다.
- UI test 실행 전 lingering AUT 때문에 `app.terminate()` setup failure가 발생하는 경우가 있었다.

### Root Cause

Phase 4 surface는 smoke 수준의 selector만 있었고, full regression이 요구하는 screen anchor, row/action identifier, seeded route contract가 아직 정리되지 않았다.
또한 UI runtime은 시뮬레이터 상태에 민감해서 실행 전 AUT 정리가 필요했다.

## Solution

Wellness seeded flow를 `default-seeded` 기준으로 다시 고정하고, body/injury/history/detail/form surface에 필요한 AXID를 추가했다.
새 `WellnessRegressionTests`를 추가해 hero, HRV metric detail, body add/edit, injury add/edit, injury statistics route를 한 묶음으로 구성했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Wellness/WellnessView.swift` | body/injury history link AXID 추가 | Wellness root에서 deterministic route 탐색을 가능하게 하기 위해 |
| `DUNE/Presentation/Wellness/WellnessScoreDetailView.swift` | detail screen anchor 추가 | hero route 검증을 안정화하기 위해 |
| `DUNE/Presentation/Wellness/BodyHistoryDetailView.swift` | screen anchor, manual row AXID, context-menu edit action AXID 추가 | body history edit flow를 locale-safe하게 검증하기 위해 |
| `DUNE/Presentation/BodyComposition/BodyCompositionFormSheet.swift` | form screen anchor 추가 | add/edit sheet dismiss와 persistence 확인을 안정화하기 위해 |
| `DUNE/Presentation/Injury/InjuryHistoryView.swift` | history screen, row, stats button, detail toolbar AXID 추가 | injury history/detail/statistics route를 full regression으로 묶기 위해 |
| `DUNE/Presentation/Injury/InjuryStatisticsView.swift` | statistics screen anchor 추가 | history -> statistics route를 고정하기 위해 |
| `DUNE/Presentation/Injury/InjuryFormSheet.swift` | form screen anchor 추가 | recovered toggle 및 add/edit flow 검증을 안정화하기 위해 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | Wellness/body/injury regression용 AXID 상수 추가 | 테스트 selector를 중앙 관리하기 위해 |
| `DUNEUITests/Full/WellnessRegressionTests.swift` | Wellness full regression suite 추가 | Phase 4 user path를 full lane에 고정하기 위해 |
| `scripts/test-ui.sh` | 실행 전 AUT `simctl terminate` 추가 | lingering app instance로 인한 setup failure를 줄이기 위해 |

### Key Code

```swift
Color.clear
    .frame(height: 1)
    .accessibilityElement()
    .accessibilityIdentifier("body-form-screen")
```

```swift
let rows = app.descendants(matching: .any)
    .matching(NSPredicate(format: "identifier BEGINSWITH %@", "injury-history-row-"))
XCTAssertGreaterThanOrEqual(rows.count, 2)
```

## Prevention

Wellness처럼 multiple route가 한 탭 안에 모여 있는 surface는 section label보다 route contract를 직접 대표하는 AXID를 우선적으로 부여하는 편이 안전하다.
특히 history/detail/form은 screen anchor와 row/action selector를 같이 설계해야 full regression으로 닫히기 쉽다.

### Checklist Addition

- [ ] seeded scenario에 실제로 존재하는 surface만 full regression root assertion에 사용하고 있는가?
- [ ] history/detail/form route에는 screen anchor와 row/action AXID가 함께 있는가?
- [ ] context menu나 toolbar action은 localized label 대신 stable AXID로 접근 가능한가?
- [ ] UI 실행 전 lingering AUT를 정리해 setup failure를 줄이고 있는가?

### Rule Addition (if applicable)

새 rules 파일 추가는 하지 않았다.

## Lessons Learned

이번 phase의 blocker는 코드보다 시뮬레이터 런타임이었다.
`scripts/build-ios.sh`는 통과했지만, UI verification은 CoreSimulatorService 장애로 끝까지 완료하지 못했다.
또한 `build-for-testing`은 이번 변경과 별개로 `DUNEWidget` asset catalog 단계에서 실패했다.
따라서 이번 ship은 구현 완료 기준으로 진행하고, UI runtime 재검증은 별도 follow-up이 필요하다.
