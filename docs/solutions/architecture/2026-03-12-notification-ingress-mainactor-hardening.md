---
tags: [swiftui, notificationcenter, mainactor, thread-safety, visionos]
category: architecture
date: 2026-03-12
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNE/App/ContentView.swift
  - DUNE/Presentation/Shared/Components/OceanWaveBackground.swift
  - DUNEVision/App/VisionContentView.swift
  - DUNEVision/Presentation/Chart3D/Chart3DContainerView.swift
  - DUNEVision/Presentation/Dashboard/VisionDashboardWindowScene.swift
  - DUNEVision/Presentation/Immersive/VisionImmersiveExperienceView.swift
  - DUNEVision/Presentation/Volumetric/VisionVolumetricExperienceView.swift
related_solutions:
  - docs/solutions/architecture/2026-03-12-cloudkit-remote-change-mainactor-ingress.md
  - docs/solutions/architecture/2026-03-12-mac-swiftdata-migration-refresh-stability.md
---

# Solution: Notification Ingress Main Actor Hardening

## Problem

CloudKit remote change 경로를 고친 뒤에도, 저장소 곳곳의 `NotificationCenter.default.publisher(...).onReceive`
closure가 notification delivery thread를 그대로 신뢰하고 있었다.

### Symptoms

- `Publishing changes from background threads is not allowed` 경고가 notification 기반 갱신 뒤 간헐적으로 반복될 수 있었다.
- simulator mock data refresh, power-state change, notification route delivery처럼 UI state를 직접 건드리는 ingress가 thread-safe contract를 코드상 드러내지 못했다.

### Root Cause

`NotificationCenter` publisher는 delivery thread를 보장하지 않는데도,
여러 view가 `onReceive` closure 안에서 `@State`를 직접 바꾸거나 `@Observable @MainActor` view model 갱신을 즉시 시작하고 있었다.

CloudKit remote change 한 지점만 main actor로 고정해도, 같은 패턴이 다른 notification ingress에 남아 있으면
background-thread publish 경고가 재발할 수 있었다.
후속 디버깅에서 `Task { @MainActor in ... }`만으로는 `NotificationCenter.Publisher` 자체의
delivery thread를 바꾸지 못한다는 점도 확인됐다.

## Solution

`NotificationCenter`에 `mainThreadPublisher(for:)` helper를 추가해 publisher output 자체를
`receive(on: RunLoop.main)`으로 올리고, SwiftUI의 `.onReceive`는 이 helper만 사용하도록 정리했다.
비동기 작업이 필요한 경우에만 그 다음 단계에서 `Task { @MainActor in ... }`를 유지한다.
동시에 `Notification` 자체는 task 안으로 넘기지 않고, sendable한 값만 추출해서 넘기도록 정리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Services/NotificationCenter+MainThread.swift` | `receive(on: RunLoop.main)` helper 추가 | notification publisher delivery thread를 선언적으로 main으로 고정 |
| `DUNE/App/DUNEApp.swift` | Cloud sync notification handler가 main-thread publisher를 사용하도록 변경 | `appRuntime` refresh ingress를 background delivery thread에서 분리 |
| `DUNE/App/ContentView.swift` | route request / mock refresh handler가 main-thread publisher를 사용하도록 변경 | navigation path와 refresh signal mutation 진입점을 main run loop로 고정 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | inbox change reload publisher를 main-thread helper로 전환 | unread badge/state reload를 notification thread와 분리 |
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | inbox reload publisher를 main-thread helper로 전환 | hub state refresh를 안전하게 유지 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | power-state notification publisher를 main-thread helper로 전환 | low-power mode toggle 시 background publish 방지 |
| `DUNEVision/App/VisionContentView.swift` | mock refresh publisher를 main-thread helper로 전환 | refresh signal + view model reload 진입점을 동일 contract로 통일 |
| `DUNEVision/Presentation/Chart3D/Chart3DContainerView.swift` | `refreshToken` update publisher를 main-thread helper로 전환 | direct `@State` mutation ingress hardening |
| `DUNEVision/Presentation/Dashboard/VisionDashboardWindowScene.swift` | reload ingress publisher를 main-thread helper로 전환 | vision workspace view model 업데이트를 main run loop에서 시작 |
| `DUNEVision/Presentation/Immersive/VisionImmersiveExperienceView.swift` | reload + animation ingress publisher를 main-thread helper로 전환 | `@State` animation values와 view model reload 진입점을 동일 contract로 유지 |
| `DUNEVision/Presentation/Volumetric/VisionVolumetricExperienceView.swift` | reload ingress publisher를 main-thread helper로 전환 | spatial view model 갱신 contract를 명시 |

### Key Code

```swift
.onReceive(NotificationCenter.default.mainThreadPublisher(for: .simulatorAdvancedMockDataDidChange)) { _ in
    refreshToken += 1
}
```

```swift
.onReceive(NotificationCenter.default.mainThreadPublisher(for: NotificationInboxManager.routeRequestedNotification)) { notification in
    guard let request = NotificationInboxManager.navigationRequest(from: notification) else { return }
    guard notificationInboxManager.consumePendingNavigationRequest(ifMatching: request) else { return }
    handleNotificationNavigationRequest(request)
}
```

## Prevention

### Checklist Addition

- [ ] `NotificationCenter.default.publisher(...).onReceive`가 `@State`, `NavigationPath`, animation state, `@Observable @MainActor` view model을 만지면 publisher 단계에서 `receive(on: RunLoop.main)` 또는 `mainThreadPublisher(for:)`를 먼저 적용한다.
- [ ] `Notification` 같은 non-Sendable payload를 `Task { @MainActor in ... }`에 직접 캡처하지 말고, 먼저 sendable 값으로 변환한 뒤 넘긴다.
- [ ] remote change 한 지점만 고치지 말고 동일한 notification ingress 패턴이 다른 화면에도 남아 있는지 함께 검색한다.

### Rule Addition (if applicable)

새 rules 파일까지는 필요 없고, notification 기반 UI ingress 리뷰 시 위 체크리스트를 반복 적용한다.

## Lessons Learned

- background publish warning은 특정 feature bug라기보다 notification ingress 패턴 누수일 때가 많다.
- `Task { @MainActor in ... }`는 state mutation 지점 보호에는 유효하지만, Combine publisher delivery thread 자체를 바꾸지는 못한다.
- actor isolation fix는 downstream publish 지점만이 아니라 notification entry point 전체를 같이 보아야 재발을 줄일 수 있다.
