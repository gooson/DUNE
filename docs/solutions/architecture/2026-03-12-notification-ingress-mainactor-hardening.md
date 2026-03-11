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

## Solution

state mutation 또는 UI-facing reload를 수행하는 `onReceive` 경로를 모두 `Task { @MainActor in ... }`
경유로 통일했다. 동시에 `Notification` 자체는 task 안으로 넘기지 않고, sendable한 값만 추출해서 넘기도록 정리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/DUNEApp.swift` | Cloud sync notification handler를 explicit main actor task로 변경 | `appRuntime` refresh ingress를 background delivery thread에서 분리 |
| `DUNE/App/ContentView.swift` | route request / mock refresh handler를 main actor task로 이동 | navigation path와 refresh signal mutation을 main actor에 고정 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | inbox change reload를 main actor task로 이동 | unread badge/state reload를 notification thread와 분리 |
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | inbox reload를 main actor task로 이동 | hub state refresh를 안전하게 유지 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | power-state notification 후 `@State` 갱신을 main actor task로 이동 | low-power mode toggle 시 background publish 방지 |
| `DUNEVision/App/VisionContentView.swift` | mock refresh path를 main actor task로 이동 | refresh signal + view model reload를 같은 actor boundary로 정리 |
| `DUNEVision/Presentation/Chart3D/Chart3DContainerView.swift` | `refreshToken` 증가를 main actor task로 이동 | direct `@State` mutation hardening |
| `DUNEVision/Presentation/Dashboard/VisionDashboardWindowScene.swift` | reload ingress를 main actor task로 이동 | vision workspace view model 업데이트를 명시적으로 main actor에서 실행 |
| `DUNEVision/Presentation/Immersive/VisionImmersiveExperienceView.swift` | reload + animation state reset ingress를 main actor task로 이동 | `@State` animation values와 view model reload를 같은 actor boundary로 유지 |
| `DUNEVision/Presentation/Volumetric/VisionVolumetricExperienceView.swift` | reload ingress를 main actor task로 이동 | spatial view model 갱신 contract를 명시 |

### Key Code

```swift
.onReceive(NotificationCenter.default.publisher(for: .simulatorAdvancedMockDataDidChange)) { _ in
    Task { @MainActor in
        refreshToken += 1
    }
}
```

```swift
.onReceive(NotificationCenter.default.publisher(for: NotificationInboxManager.routeRequestedNotification)) { notification in
    let request = NotificationInboxManager.navigationRequest(from: notification)
    Task { @MainActor in
        guard let request else { return }
        guard notificationInboxManager.consumePendingNavigationRequest(ifMatching: request) else { return }
        handleNotificationNavigationRequest(request)
    }
}
```

## Prevention

### Checklist Addition

- [ ] `NotificationCenter.default.publisher(...).onReceive`가 `@State`, `NavigationPath`, animation state, `@Observable @MainActor` view model을 만지면 explicit main actor hop이 있는지 확인한다.
- [ ] `Notification` 같은 non-Sendable payload를 `Task { @MainActor in ... }`에 직접 캡처하지 말고, 먼저 sendable 값으로 변환한 뒤 넘긴다.
- [ ] remote change 한 지점만 고치지 말고 동일한 notification ingress 패턴이 다른 화면에도 남아 있는지 함께 검색한다.

### Rule Addition (if applicable)

새 rules 파일까지는 필요 없고, notification 기반 UI ingress 리뷰 시 위 체크리스트를 반복 적용한다.

## Lessons Learned

- background publish warning은 특정 feature bug라기보다 notification ingress 패턴 누수일 때가 많다.
- actor isolation fix는 downstream publish 지점만이 아니라 notification entry point 전체를 같이 보아야 재발을 줄일 수 있다.
