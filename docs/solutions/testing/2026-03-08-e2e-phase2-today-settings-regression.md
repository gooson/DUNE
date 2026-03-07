---
tags: [ui-test, e2e, dashboard, settings, seeded-fixture, accessibility]
category: testing
date: 2026-03-08
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNE/App/TestDataSeeder.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
  - DUNE/Presentation/Shared/CloudSyncConsentView.swift
  - DUNEUITests/Full/TodaySettingsRegressionTests.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
  - docs/solutions/testing/ui-test-infrastructure-design.md
  - docs/solutions/testing/2026-03-03-ipad-activity-tab-ui-test-navigation-stability.md
  - docs/solutions/general/2026-03-08-cloud-sync-consent-localization-leak.md
---

# Solution: E2E Phase 2 Today/Settings 회귀 경로 확장

## Problem

Phase 1에서 launch/reset/seed 기반 UI 테스트 인프라는 준비됐지만, Today/Settings 주요 상세 화면은 아직 deterministic fixture와 AXID가 충분하지 않았다.
특히 Today 카드 진입, notification hub 상태 전이, pinned editor, cloud sync consent 같은 흐름은 UI에서 보이더라도 테스트가 안정적으로 선택할 수 있는 surface가 부족했다.

### Symptoms

- seeded launch를 해도 Today 상세 화면 진입에 필요한 condition/weather/shared snapshot 상태가 매 실행마다 동일하게 보장되지 않음
- dashboard metric/weather/section/pinned 영역이 AXID 없이 노출되어 UI 테스트가 레이아웃/문구에 의존함
- cloud sync consent sheet는 작은 sheet 높이와 localized label 때문에 안정적인 dismiss 경로를 잡기 어려움
- notification hub, pinned editor 회귀가 phase 단위 테스트로 아직 묶여 있지 않음

### Root Cause

Phase 1이 공통 인프라 정리에 집중하면서, 실제 Today/Settings surface별 fixture contract와 accessibility contract는 아직 각 화면 구현에 흩어져 있었다.
또한 일부 SwiftUI 버튼/컨테이너는 AXID를 부모에 붙이면 hit-testing과 접근성 노출이 섞여 XCUI 선택자가 불안정해질 수 있었는데, 이 제약이 상세 플로우 테스트에서 드러났다.

## Solution

Today/Settings Phase 2 대상 화면에 대해 scenario-aware seeded fixture를 보강하고, 화면 진입점과 목적지 화면에 AXID를 추가했다.
동시에 consent/pinned/notification 경로에서 SwiftUI 접근성 노출 방식에 맞는 테스트 선택자와 레이아웃을 적용해 regression test를 구성했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/TestDataSeeder.swift` | scenario 해석, user defaults reset, shared snapshot/weather/notification fixture 생성 추가 | Today/Settings regression이 매 실행 동일 상태에서 시작되게 하기 위해 |
| `DUNE/App/DUNEApp.swift` | seeded UI launch 시 mirrored snapshot service와 force-consent hook 연결 | HealthKit/CloudKit 실환경 의존 없이 Today/consent 경로를 재현하기 위해 |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | seeded mode에서 shared snapshot/weather fixture 직접 사용 | launch 타이밍 차이로 Today 카드가 비어 보이는 flake를 줄이기 위해 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | weather/section/metric/pinned AXID 추가, pinned grid 식별자 범위 조정 | Today phase 2 테스트가 구조적 selector를 사용하도록 하기 위해 |
| `DUNE/Presentation/Shared/CloudSyncConsentView.swift` | scroll + bottom action layout, large detent, consent action AX surface 보강 | consent sheet action이 다양한 sheet 높이와 locale에서 안정적으로 노출되게 하기 위해 |
| `DUNE/Presentation/*Detail*.swift` | condition/metric/all-data/weather/notification/pinned editor root AXID 추가 | 목적지 화면 도착 assertion을 명확하게 만들기 위해 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | Phase 2 AXID constants 확장 | 테스트 파일이 문자열 리터럴에 의존하지 않게 하기 위해 |
| `DUNEUITests/Full/TodaySettingsRegressionTests.swift` | Today/Settings regression suite 추가 | hero/detail/weather/pinned/notification/settings/consent 경로를 묶어서 회귀 검증하기 위해 |

### Key Code

```swift
if hasSeededMockData {
    appContent
} else {
    Color.clear
        .task {
            guard !hasSeededMockData else { return }
            TestDataSeeder.seed(
                into: modelContainer.mainContext,
                scenario: Self.uiTestLaunchConfiguration.scenario
            )
            hasSeededMockData = true
        }
}
```

```swift
Button {
    isShowingPinnedEditor = true
} label: {
    Text("Edit")
        .font(.subheadline.weight(.medium))
        .accessibilityIdentifier("dashboard-pinned-edit")
}
```

## Prevention

Today/Settings처럼 카드 진입이 많은 화면은 UI test 추가 전에 먼저 "fixture contract"와 "AX contract"를 함께 정의해야 한다.
특히 SwiftUI에서 섹션 전체 컨테이너에 AXID를 붙이면 자식 버튼 hit-testing을 먹을 수 있으므로, 테스트 식별자는 실제 상호작용 surface 또는 그 최소 범위에만 부여한다.

### Checklist Addition

- [ ] seeded UI scenario가 필요한 화면은 `TestDataSeeder`에 user defaults, SwiftData, weather/shared snapshot fixture를 함께 정의했는지 확인
- [ ] 상세 화면 진입 테스트를 추가할 때 source card AXID와 destination root AXID를 쌍으로 제공했는지 확인
- [ ] localized button text에 기대는 테스트는 가능하면 AXID를 우선하고, 불가피하면 launch locale을 테스트 클래스 수준에서 고정했는지 확인
- [ ] SwiftUI 컨테이너 AXID가 자식 button hit-testing을 가리지 않는지 screenshot/debugDescription으로 한 번 확인했는지 점검

### Rule Addition (if applicable)

새 규칙 파일 추가는 보류한다.
다음 E2E phase에서도 "fixture contract + AX contract 동시 추가" 원칙을 유지한다.

## Lessons Learned

UI 테스트 안정화에서 가장 큰 비용은 assertion보다 "선택 가능한 surface를 어떻게 설계하느냐"에 있다.
또한 seeded fixture를 네트워크/HealthKit fetch 완료에만 맡기지 않고 view model이 직접 읽을 수 있는 deterministic snapshot으로 연결해야 Today 계열 회귀가 훨씬 안정적으로 닫힌다.
