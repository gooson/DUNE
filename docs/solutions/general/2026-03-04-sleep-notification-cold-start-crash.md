---
tags: [notification, crash, cold-start, threading, sleep, cooperative-thread]
date: 2026-03-04
category: solution
status: implemented
---

# Sleep Notification Cold Start Crash/Hang

## Problem

수면시간 알림(sleep notification)을 탭했을 때 앱에 진입하지 못하는 문제.

### Root Cause

두 가지 원인이 결합:

1. **Cooperative thread starvation**: `AppNotificationCenterDelegate.didReceive`가 `nonisolated async`로 선언되어 cooperative thread에서 실행. 내부에서 `handleNotificationResponse` → `open()` → `DispatchQueue.sync` 호출이 cooperative thread를 블로킹. Cold start 시 SwiftUI/SwiftData/HealthKit 초기화와 cooperative pool을 경합하여 앱 렌더링 지연/행.

2. **Non-routed notification 무응답**: Sleep notification은 `route: nil`로 생성됨. `handleNotificationResponse`에서 route가 없으면 아무 navigation도 emit하지 않아 앱이 열려도 아무 반응 없음.

## Solution

### Fix 1: MainActor.run으로 delegate 작업 이동

```swift
nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
) async {
    await MainActor.run {
        inboxManager.handleNotificationResponse(
            userInfo: response.notification.request.content.userInfo
        )
    }
}
```

- Cooperative thread에서 `DispatchQueue.sync` 블로킹 방지
- Main actor에서 실행하므로 UIKit/SwiftUI lifecycle과 동기화
- `await`로 delegate contract (완료 대기) 유지

### Fix 2: Non-routed notification에 notificationHub route 추가

```swift
// NotificationRoute.Destination에 .notificationHub 추가
enum Destination: String, Codable, Sendable {
    case workoutDetail
    case notificationHub
}

// handleNotificationResponse에서 route 없는 알림에 hub route emit
if let itemID {
    let openedItem = open(itemID: itemID)
    if openedItem?.route != nil { return }
    // ... parseRoute fallback ...
    emitNavigationRequest(.init(itemID: itemID, route: .notificationHub))
    return
}
```

- ContentView에서 `.notificationHub` → Today 탭 + hub signal
- DashboardView에서 signal → NotificationHubView push

## Prevention

- `nonisolated async` delegate 메서드에서 `DispatchQueue.sync` 호출 금지
- Cooperative thread에서의 blocking 작업은 `MainActor.run` 또는 별도 Task로 dispatch
- 모든 notification type에 route 또는 fallback navigation 보장
- 새 `NotificationRoute.Destination` 추가 시 모든 switch 문 (ContentView, InboxManager, ThrottleStore) 업데이트 체크리스트

## Files Changed

| File | Change |
|------|--------|
| `App/AppNotificationCenterDelegate.swift` | `MainActor.run` 래핑 |
| `Domain/Models/NotificationInboxItem.swift` | `.notificationHub` destination 추가 |
| `Data/Persistence/NotificationInboxManager.swift` | Non-routed → hub route emit |
| `Data/Persistence/NotificationThrottleStore.swift` | Switch exhaustive 대응 |
| `App/ContentView.swift` | Hub signal + routing |
| `Presentation/Dashboard/DashboardView.swift` | Hub signal → navigation |
