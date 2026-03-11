---
tags: [launch, permissions, healthkit, notifications, dashboard, swiftui, orchestration, first-install]
category: architecture
date: 2026-03-11
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNE/App/LaunchExperiencePlanner.swift
  - DUNE/App/ContentView.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
  - DUNETests/LaunchExperiencePlannerTests.swift
  - DUNETests/DashboardViewModelTests.swift
  - DUNEUITests/Manual/HealthKitPermissionUITests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-07-launch-permission-whatsnew-sequencing.md
  - docs/solutions/testing/2026-02-23-healthkit-permission-ui-test-gating.md
---

# Solution: Defer Launch Permissions Until App Content Is Ready

## Problem

첫 설치 시 launch orchestrator가 HealthKit / notification permission을 blocking launch step으로 취급하면서, splash 이후에도 앱 readiness가 system prompt 완료에 묶여 있었다.

### Symptoms

- 최초 실행에서 앱이 skeleton 또는 정지 상태처럼 보이고 실제 콘텐츠가 늦게 뜸
- Today 초기 로드가 permission 흐름과 경쟁하거나 prompt가 끝날 때까지 시작되지 않음
- manual permission UI test가 consent, What's New, permission 순서를 안정적으로 추적하지 못함

### Root Cause

`DUNEApp`의 launch planner가 permission prompt를 `ready` 이전 단계로 포함하고 있었고, `DashboardViewModel`도 launch 직후 shared snapshot / live HealthKit query를 시도할 수 있었다. 결과적으로 launch readiness와 protected data access가 분리되지 않았다.

## Solution

launch planner에서 permission step을 제거해 `consent -> What's New -> ready`만 blocking flow로 유지하고, HealthKit / notification authorization은 app content가 뜬 뒤 deferred task로 실행하도록 옮겼다. Today 탭은 `canLoadHealthKitData` gate가 `true`가 되기 전까지 shared snapshot과 direct HealthKit query를 모두 건너뛰고, gate 변경 시 자동 재로드된다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/LaunchExperiencePlanner.swift` | remove blocking permission steps | launch readiness를 system prompt 완료와 분리 |
| `DUNE/App/DUNEApp.swift` | add deferred authorization runner + `canLoadHealthKitData` | app content 렌더 후 순차 권한 요청 |
| `DUNE/App/ContentView.swift` | pass HealthKit load gate into Today tab | launch 상태를 화면 로딩 정책으로 전달 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | include gate in load trigger | permission 완료 후 자동 재로드 보장 |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | skip protected snapshot/query until gate opens | 첫 설치 시 HealthKit 접근 경쟁 제거 |
| `DUNETests/LaunchExperiencePlannerTests.swift` | update sequencing assertions | 새 blocking launch order 회귀 방지 |
| `DUNETests/DashboardViewModelTests.swift` | add deferred gate test | gate false/true 전환 동작 검증 |
| `DUNEUITests/Manual/HealthKitPermissionUITests.swift` | update manual flow order | dashboard surface 이후 deferred prompt 검증 |

### Key Code

```swift
private func requestDeferredAuthorizationsIfNeeded() async {
    guard isLaunchExperienceReady else { return }
    guard scenePhase == .active else { return }
    guard shouldRequestHealthKitAuthorizationAutomatically
        || shouldRequestNotificationAuthorizationAutomatically else { return }

    try? await Task.sleep(for: .milliseconds(400))

    if shouldRequestHealthKitAuthorizationAutomatically {
        try await HealthKitManager.shared.requestAuthorization()
        hasRequestedHealthKitAuthorization = true
    }
}
```

```swift
func loadData(canLoadHealthKitData: Bool = true) async {
    let canQueryHealthKit = healthKitAvailable && canLoadHealthKitData
    let canUseSharedSnapshot = !healthKitAvailable || canLoadHealthKitData
    ...
}
```

## Prevention

### Checklist Addition

- [ ] launch readiness가 system permission prompt 완료에 직접 종속되지 않는가
- [ ] protected data query가 authorization orchestration보다 먼저 시작되지 않는가
- [ ] permission 완료 후 화면 재로드 트리거가 별도 signal 없이도 재현 가능한가

### Rule Addition (if applicable)

없음. 기존 launch orchestration solution 문서에 대한 후속 패턴으로 충분하다.

## Lessons Learned

- launch 안정성은 permission prompt 자체보다 readiness와 data query를 분리하는지에 더 크게 좌우된다.
- launch 단계에서 prompt를 없애지 않더라도, 첫 프레임 이후 deferred task로 옮기면 “앱이 아무 반응이 없는” 인상을 크게 줄일 수 있다.
- shared snapshot 경로도 결국 protected data access일 수 있으므로, direct query만 막아서는 초기 race를 완전히 제거할 수 없다.
