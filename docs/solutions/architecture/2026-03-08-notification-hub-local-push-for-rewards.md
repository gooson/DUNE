---
tags: [notification, hub, push, navigation, personal-records, badge, level-up, openLocally]
date: 2026-03-08
category: architecture
status: implemented
severity: important
related_files:
  - DUNE/Presentation/Dashboard/NotificationHubView.swift
  - DUNE/Data/Persistence/NotificationInboxManager.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Shared/NotificationPersonalRecordsPushView.swift
  - DUNETests/NotificationExerciseDataTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-08-tab-scoped-notification-push-preserves-navigation-bar.md
  - docs/solutions/architecture/2026-03-08-notification-root-push-from-current-screen.md
---

# NotificationHub에서 뱃지/레벨업 알림 로컬 Push

## Problem

NotificationHubView에서 뱃지/레벨업 알림을 탭하면 PersonalRecords 화면으로 push되어야 하지만 아무 일도 일어나지 않았다.

### Root Cause

1. NotificationHubView는 DashboardView의 `.navigationDestination(isPresented:)`로 표시됨
2. 알림 탭 시 `inboxManager.open()`이 `activityPersonalRecords` route를 감지하고 ContentView로 navigation request 발송
3. ContentView의 `handleNotificationNavigationRequest()`가 `clearAllNavPaths()`로 NavigationPath를 초기화하지만, hub의 `isPresented`는 해제되지 않음
4. PersonalRecords가 path에 push되더라도 hub가 여전히 화면을 차지하여 보이지 않음

### 핵심 충돌

- **isPresented 기반**: NotificationHubView (DashboardView 소유)
- **NavigationPath 기반**: PersonalRecords push (ContentView 소유)
- 두 메커니즘이 독립적이어서, path push가 isPresented 위에 쌓이지 않음

## Solution

### 1. `openLocally(itemID:)` API 추가

`NotificationInboxManager`에 navigation request를 emit하지 않는 `openLocally` 메서드를 추가했다. 허브처럼 로컬에서 navigation을 처리하는 호출자가 race condition 없이 안전하게 사용할 수 있다.

```swift
/// Marks the item as read and returns it without emitting a navigation request.
/// Use this when the caller handles navigation locally (e.g., NotificationHubView push).
@discardableResult
func openLocally(itemID: String) -> NotificationInboxItem? {
    guard let existing = store.item(withID: itemID) else { return nil }
    _ = store.markRead(id: itemID)
    postInboxDidChange()
    return existing
}
```

### 2. NotificationHubView 로컬 push

`handleTap`에서 `activityPersonalRecords` route와 route-less `workoutPR`을 `openLocally`로 처리하고, 로컬 navigation destination으로 push한다.

```swift
let isLocalRoute = item.route?.destination == .activityPersonalRecords
    || (item.route == nil && item.insightType == .workoutPR)

if isLocalRoute {
    guard let opened = inboxManager.openLocally(itemID: item.id) else { ... }
    destination = .personalRecords(itemID: opened.id)
    return
}
```

### 3. SharedHealthDataService 전파

DashboardView → NotificationHubView → NotificationPersonalRecordsPushView로 service를 전달하여 허브 경유 진입에서도 ContentView 경유와 동일한 데이터 품질을 보장한다.

### 4. Layer 정리

`NotificationPersonalRecordsPushView`를 `App/ContentView.swift`에서 `Presentation/Shared/`로 이동하여 Presentation layer 간 정상 참조 관계를 유지한다.

## Changes Made

| File | Change | Reason |
|------|--------|--------|
| `NotificationInboxManager.swift` | `openLocally(itemID:)` 추가 | emit 없는 읽기 전용 open |
| `NotificationHubView.swift` | `HubDestination.personalRecords` + `handleTap` 로컬 push + service 주입 | 허브 내 로컬 navigation |
| `DashboardView.swift` | `sharedHealthDataService` 저장 + 허브에 전달 | 데이터 일관성 |
| `NotificationPersonalRecordsPushView.swift` | `Presentation/Shared/`로 이동 | App→Presentation layer 위반 해소 |
| `ContentView.swift` | 기존 push view 제거 (이동됨) | 중복 제거 |
| `NotificationExerciseDataTests.swift` | `openLocally` 기반 테스트로 교체 | 새 API 계약 고정 |

## Prevention

### 판단 기준: 로컬 push vs ContentView 위임

| 조건 | 처리 방식 |
|------|----------|
| 현재 navigation stack 내에서 push 가능 | `openLocally` + 로컬 destination |
| 탭 전환이 필요 | `open()` + ContentView 위임 |
| 시스템 알림 → 앱 cold start | `open()` + ContentView 위임 (허브 미표시) |

### `open()` vs `openLocally()` 선택 기준

- `open()`: navigation request가 ContentView까지 전달되어야 할 때 (시스템 알림 탭, 탭 전환 필요)
- `openLocally()`: 호출자가 직접 navigation을 처리할 때 (허브 내 push)

### 금지 패턴

- `open()` 호출 후 `consumePendingNavigationRequest()`로 retract하는 패턴 — race condition 위험
- 허브에서 `sharedHealthDataService: nil`로 PersonalRecords 생성 — 데이터 품질 저하

## Lessons Learned

- `isPresented` 기반 navigation과 `NavigationPath` 기반 navigation은 독립적이다. 한쪽에서 다른 쪽의 상태를 제어하려면 Binding 전파가 필요하며, 이보다는 같은 navigation context 내에서 로컬 처리하는 것이 간단하다.
- emit-then-retract 패턴은 근본적으로 fragile하다. 로컬 처리가 가능한 경우 처음부터 emit하지 않는 API를 사용해야 한다.
- 동일 View를 다른 경로에서 생성할 때 의존성(service, data source)이 누락되지 않도록 주의해야 한다.
