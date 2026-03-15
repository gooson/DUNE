---
tags: [testing, xcuitest, accessibility, seeded-fixtures, settings, activity]
category: testing
date: 2026-03-16
severity: important
related_files:
  - DUNE/App/TestDataSeeder.swift
  - DUNEUITests/Full/TodaySettingsRegressionTests.swift
  - DUNEUITests/Full/ActivityExerciseRegressionTests.swift
  - DUNEUITests/Regression/ChartInteractionRegressionUITests.swift
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
  - docs/solutions/testing/2026-03-14-simulator-mock-host-parity-and-loading-guard.md
---

# Solution: E2E Settings and Activity Surface Contracts

## Problem

Today/Settings와 Activity detail surface 일부가 phase 0 E2E backlog에 남아 있었고, 기존 UI 테스트로는 화면 진입은 가능해도 안정적인 selector와 seeded state가 부족해 회귀를 고정하기 어려웠다.

### Symptoms

- Settings 하위 화면이 locale/레이아웃에 따라 row, toggle, text field를 안정적으로 찾지 못했다.
- Activity detail 화면은 chart/list/picker가 accessibility tree에서 일관된 anchor를 갖지 않아 surface assertion이 흔들렸다.
- `activity-exercise-seeded` 시나리오가 advanced mock workout data를 켜지 않아 일부 Activity detail flow가 비결정적으로 비었다.

### Root Cause

- surface-level AXID가 screen/card/list/row/control 단위로 충분히 정의되지 않았다.
- seeded scenario가 화면 계약을 검증하기 위한 최소 fixture를 모두 제공하지 않았다.
- XCTest가 segmented picker value, searchable keyboard, SwiftUI row hittability를 기본 상태만으로는 안정적으로 다루지 못했다.

## Solution

Settings/Activity 대상 화면에 stable accessibility identifier를 보강하고, UI tests는 seeded fixture를 직접 확장해 “진입 가능성 + 핵심 surface contract”를 검증하는 방식으로 정리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/TestDataSeeder.swift` | default/activity seeded scenario에 exercise default fixture와 advanced mock enable 반영 | Settings/Activity detail flow를 deterministic하게 만들기 위해 |
| `DUNE/Presentation/Settings/...` | screen, row, field, toggle, action AXID 추가 | Settings child surface selector를 고정하기 위해 |
| `DUNE/Presentation/Activity/...` | picker, chart, list, history, reward, calendar AXID 추가 | Activity detail surface contract를 직접 검증하기 위해 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | AXID 상수, keyboard/switch helper 강화 | flaky interaction을 줄이기 위해 |
| `DUNEUITests/Full/TodaySettingsRegressionTests.swift` | Exercise Defaults / Preferred Exercises regression 추가 | TODO 032~034 closeout |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | Activity / readiness / exercise-type / PR / consistency regression 추가 | TODO 035~041 closeout |
| `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift` | weekly stats / training volume surface assertions 추가 | chart detail surface contract 보강 |

### Key Code

```swift
private static func configureSimulatorAdvancedMockData(
    for scenario: UITestSeedScenario,
    defaults: UserDefaults = .standard,
    referenceDate: Date = Date()
) {
    SimulatorAdvancedMockDataModeStore.setEnabled(false, defaults: defaults)
    SimulatorAdvancedMockDataModeStore.setReferenceDate(nil, defaults: defaults)

    guard scenario != .empty else { return }

    SimulatorAdvancedMockDataModeStore.setReferenceDate(referenceDate, defaults: defaults)
    SimulatorAdvancedMockDataModeStore.setEnabled(true, defaults: defaults)
}
```

```swift
XCTAssertTrue(
    app.scrollToHittableElementIfNeeded(
        AXID.activityTrainingVolumeRow(Fixture.manualStrengthTypeKey),
        maxSwipes: 10
    ),
    "Manual strength row should be reachable in Training Volume detail"
)
```

## Prevention

새 surface TODO를 닫을 때는 “진입 screen AXID, 핵심 section AXID, action/control AXID, deterministic seeded fixture” 4가지를 함께 맞춰야 한다.

### Checklist Addition

- [ ] surface 테스트를 추가할 때 screen/section/control 3단계 AXID가 모두 있는지 확인한다.
- [ ] `--ui-scenario` 기반 seeded flow가 필요한 mock data를 실제로 켜는지 확인한다.
- [ ] segmented picker/switch/search UI는 raw label이 아니라 AXID 또는 explicit accessibility value로 검증한다.
- [ ] 테스트 이름은 실제 assertion 범위를 정확히 반영한다.

### Rule Addition (if applicable)

즉시 새 rule 추가는 필요 없지만, 다음 E2E batch에서도 동일 패턴을 기본값으로 유지한다.

## Lessons Learned

- SwiftUI `NavigationLink` 자체보다 row body 쪽 accessibility identifier가 UI test에서 더 안정적으로 노출될 수 있다.
- seeded fixture는 “화면이 열린다” 수준이 아니라, drill-down 후 secondary surface까지 채워질 정도로 충분해야 한다.
- flaky test를 억지로 강하게 검증하기보다, 현재 제품이 보장하는 surface contract에 맞춰 assertion 범위를 조정하는 편이 유지보수성이 높다.
