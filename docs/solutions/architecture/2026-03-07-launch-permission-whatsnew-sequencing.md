---
tags: [launch, onboarding, permissions, healthkit, notifications, icloud, whats-new, swiftui, state-machine, permission-prompt, retry-safety]
category: architecture
date: 2026-03-07
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNE/App/ContentView.swift
  - DUNE/App/LaunchExperiencePlanner.swift
  - DUNE/Domain/Services/NotificationService.swift
  - DUNE/Data/Services/NotificationServiceImpl.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
  - DUNE/Presentation/Shared/CloudSyncConsentView.swift
  - DUNE/Presentation/WhatsNew/WhatsNewView.swift
  - DUNETests/LaunchExperiencePlannerTests.swift
  - DUNEUITests/Manual/HealthKitPermissionUITests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-07-whats-new-release-surface.md
  - docs/solutions/testing/2026-02-23-healthkit-permission-ui-test-gating.md
---

# Solution: Sequence Launch Permissions And What's New From A Single Orchestrator

## Problem

첫 실행 시 `iCloud Sync` consent, HealthKit authorization, notification authorization, 그리고 `What's New` surface가 서로 다른 계층에서 시작되면서 사용자에게 요청이 겹쳐 보일 수 있었다.

### Symptoms

- splash가 끝난 직후 consent sheet와 system permission alert가 연달아 겹침
- `DashboardViewModel`이 Today 초기 로드에서 HealthKit prompt를 띄우는 동안 앱 레벨 task가 notification prompt도 요청
- `What's New`를 launch surface로 붙일 경우 동일한 충돌이 재발할 구조
- launch auto-request가 throw 되거나 중단되면 다음 실행부터 permission prompt가 영구적으로 생략될 수 있는 상태 전이 버그 위험이 있었음

### Root Cause

- launch-level UX surface를 오케스트레이션하는 단일 계층이 없었다.
- `DUNEApp`는 consent만 관리했고, HealthKit은 `DashboardViewModel`, notifications는 app-level fire-and-forget task가 담당해 초기 표시 순서가 분산돼 있었다.
- 권한 상태를 "이번 실행에서 시도했는가"와 "다음 실행부터 건너뛰어도 되는가"로 분리하지 않아, 완료 플래그를 너무 이르게 저장할 여지가 있었다.

## Solution

`DUNEApp`가 launch flow의 단일 오케스트레이터가 되도록 바꾸고, 다음 단계 결정은 pure planner로 분리했다. 첫 진입에서는 `iCloud consent -> HealthKit -> notifications -> What's New -> app ready` 순서로 한 단계씩만 진행되고, Today 탭의 초기 load는 launch flow 완료 후에만 시작된다. 이후 리뷰에서 드러난 상태 전이 문제를 반영해, 권한 요청은 "이번 실행에서 이미 시도했는지"와 "영구적으로 완료 처리했는지"를 분리하고, 영구 플래그는 system request가 정상 반환된 뒤에만 저장하도록 수정했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/LaunchExperiencePlanner.swift` | add | launch step 판정과 authorization eligibility를 pure logic으로 분리해 테스트 가능성 확보 |
| `DUNE/App/DUNEApp.swift` | update | consent / permissions / automatic `What's New` / runtime services 순서 제어 + per-launch attempt state와 persisted completion state 분리 |
| `DUNE/Domain/Services/NotificationService.swift` | update | notification authorization failure를 앱 레벨에서 구분할 수 있도록 throwing contract로 조정 |
| `DUNE/Data/Services/NotificationServiceImpl.swift` | update | UNUserNotificationCenter request failure를 false로 삼키지 않고 throw로 전파 |
| `DUNE/App/ContentView.swift` | update | launch readiness와 HealthKit auto-request 정책을 Today 탭에 전달 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | update | launch flow 완료 전 skeleton 유지 + initial load gate |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | update | launch orchestration과 중복되는 HealthKit auto-request 제거 |
| `DUNE/Presentation/Shared/CloudSyncConsentView.swift` | update | consent CTA AX identifier 추가 |
| `DUNE/Presentation/WhatsNew/WhatsNewView.swift` | update | automatic mode close button AX identifier 추가 |
| `DUNETests/LaunchExperiencePlannerTests.swift` | add | launch step order / skip 조건 unit tests |
| `DUNEUITests/Manual/HealthKitPermissionUITests.swift` | update | 새 launch 순서에 맞춘 manual verification flow |

### Key Code

```swift
while hasCompletedPostSplashSetup, !showConsentSheet, !showWhatsNewSheet {
    switch nextLaunchExperienceStep {
    case .cloudSyncConsent:
        showConsentSheet = true
        return
    case .healthKitAuthorization:
        hasAttemptedHealthKitAuthorizationThisLaunch = true
        try await HealthKitManager.shared.requestAuthorization()
        hasRequestedHealthKitAuthorization = true
    case .notificationAuthorization:
        hasAttemptedNotificationAuthorizationThisLaunch = true
        _ = try await notificationService.requestAuthorization()
        hasRequestedNotificationAuthorization = true
    case .whatsNew:
        presentAutomaticWhatsNewIfNeeded()
        return
    case .ready:
        finishLaunchExperienceIfNeeded()
        return
    }
}
```

```swift
private var launchReadyRefreshSignal: Int {
    launchExperienceReady ? refreshSignal : -1
}
```

`DashboardView`는 `launchExperienceReady`가 `false`인 동안 `loadData()`를 호출하지 않고 skeleton만 보여 준다. 덕분에 Today 초기 load가 HealthKit prompt를 선점하지 않는다.

## Prevention

### Checklist Addition

- [ ] launch-level permission, consent, notice surface는 `DUNEApp` 한 곳에서 순서를 결정하는가?
- [ ] 탭 내부의 초기 `loadData()`가 onboarding/permission flow와 경쟁하지 않도록 gate가 있는가?
- [ ] cross-launch persisted permission flag와 same-launch attempt state가 분리되어 있는가?
- [ ] permission completion flag는 system request가 정상 반환된 뒤에만 저장되는가?
- [ ] 새 launch CTA는 UI test에서 접근 가능한 accessibility identifier를 가지는가?

### Rule Addition (if applicable)

없음. 현재는 solution 문서와 tests로 충분하다.

## Lessons Learned

- permission prompt와 custom sheet가 함께 있는 앱은 “누가 먼저 보여 줄지”를 각 화면에 나눠 두면 거의 반드시 충돌한다.
- `App`은 launch sequence를, 탭 화면은 실제 콘텐츠 로드를 담당하게 분리하는 편이 안정적이다.
- `What's New` 같은 launch surface는 기능 자체보다도 timing orchestration이 핵심이며, 기존 consent/permission flow에 얹을 때는 planner 기반 step resolution이 가장 안전하다.
- permission orchestration에서는 "attempted this launch"와 "completed across launches"를 같은 저장소에 섞으면 재시도 정책이 쉽게 망가진다.
