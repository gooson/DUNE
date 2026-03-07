---
tags: [notification, hub, push, badge, level-up, personal-records, navigation]
date: 2026-03-08
category: plan
status: approved
---

# Plan: NotificationHub에서 뱃지/레벨업 알림 로컬 Push

## Problem

NotificationHubView에서 뱃지/레벨업 알림을 탭하면 PersonalRecords 화면으로 push되어야 하지만 실제로는 아무 일도 일어나지 않는다.

### Root Cause

1. NotificationHubView는 DashboardView의 `.navigationDestination(isPresented: $showNotificationHub)`로 표시됨
2. 뱃지/레벨업 알림 탭 시 `inboxManager.open()`이 route(`.activityPersonalRecords`)를 감지하고 ContentView로 navigation request 발송
3. `handleTap`에서 `opened.route != nil` → 즉시 return (로컬 destination 설정 없음)
4. ContentView의 `handleNotificationNavigationRequest()`가 `clearAllNavPaths()`로 모든 NavigationPath를 초기화하지만, `showNotificationHub`(isPresented)는 해제되지 않음
5. PersonalRecords가 path에 push되더라도 허브가 여전히 화면을 차지하여 보이지 않음

### 핵심 충돌

- **isPresented 기반**: NotificationHubView (DashboardView 소유)
- **NavigationPath 기반**: PersonalRecords push (ContentView 소유)
- 두 메커니즘이 독립적이어서, path push가 isPresented 위에 쌓이지 않음

## Solution

NotificationHubView에서 `.activityPersonalRecords` route를 **로컬로** 처리한다. ContentView의 path 기반 라우팅에 위임하지 않는다.

### Design

1. `HubDestination`에 `.personalRecords` case 추가
2. `handleTap`에서 route가 `.activityPersonalRecords`인 경우 로컬 destination으로 push
3. `inboxManager.open()`이 이미 emit한 navigation request는 ContentView에서 무시되도록 `open()`의 동작 수정 필요 없음 — `handleTap`에서 로컬 처리 후 return하면 됨

### 대안 검토

| 대안 | 평가 |
|------|------|
| ContentView에서 `showNotificationHub = false` 후 push | DashboardView의 `@State`를 ContentView가 직접 제어 불가. Binding 전파 필요 → 복잡도 증가 |
| `inboxManager.open()`에서 route emit 막기 | 외부 알림 탭(시스템 알림 → 앱 진입)에도 영향. 시스템 알림은 ContentView 경유가 정상 |
| 허브를 sheet로 전환 | 기존 navigation UX 파괴 |
| **허브에서 로컬 push** | 허브가 이미 navigation stack 내에 있으므로 자연스럽게 push 가능. 최소 변경 |

## Affected Files

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | `HubDestination.personalRecords` 추가, `handleTap` 수정, navigationDestination 추가 | 로컬 push 지원 |
| `DUNE/Data/Persistence/NotificationInboxManager.swift` | `open()` 수정: route가 있어도 emit 전 호출자가 로컬 처리 가능하도록 | 이중 라우팅 방지 |
| `DUNETests/NotificationExerciseDataTests.swift` | 허브 로컬 push 테스트 추가 | 동작 계약 고정 |

## Implementation Steps

### Step 1: HubDestination에 personalRecords case 추가

```swift
private enum HubDestination: Hashable, Identifiable {
    case metric(HealthMetric, itemID: String)
    case settings
    case unavailable(itemID: String)
    case personalRecords(itemID: String)  // NEW
    // ...
}
```

### Step 2: navigationDestination에 personalRecords View 추가

```swift
case .personalRecords:
    PersonalRecordsDetailView(...)  // 기존 NotificationPersonalRecordsPushView와 동일 패턴
```

### Step 3: handleTap 수정

route가 `.activityPersonalRecords`인 경우 ContentView로 위임하지 않고 로컬 destination 설정.

```swift
private func handleTap(on item: NotificationInboxItem) {
    guard let opened = inboxManager.open(itemID: item.id) else {
        destination = .unavailable(itemID: item.id)
        return
    }

    // Route-based navigation (badge/level-up → PersonalRecords)
    if opened.route?.destination == .activityPersonalRecords {
        destination = .personalRecords(itemID: opened.id)
        return
    }

    // Workout detail route — delegate to ContentView (tab switch needed)
    guard opened.route == nil else {
        return
    }

    // route-less workoutPR fallback
    if opened.insightType == .workoutPR {
        inboxManager.requestNavigation(itemID: opened.id, route: .activityPersonalRecords)
        return
    }

    if let metric = NotificationHubMetricResolver.metric(for: opened) {
        destination = .metric(metric, itemID: opened.id)
    } else {
        destination = .unavailable(itemID: opened.id)
    }
}
```

### Step 4: open()의 navigation request emit 방지

`open()`이 `.activityPersonalRecords` route에 대해 navigation request를 emit하면 ContentView도 동시에 반응한다. 이를 방지해야 한다.

**방법**: `open()` 자체를 수정하지 않고, NotificationHubView가 `open()` 대신 `openLocally(itemID:)`를 호출하거나, `open()`이 route를 반환하되 emit하지 않는 변형을 사용.

가장 간단한 접근: `open()` 에서 route emit을 조건부로 만들기보다, 허브에서 `markRead`만 직접 호출하고 route는 로컬 처리.

실제 구현 시 `inboxManager`의 API를 확인하여 최소 변경 결정.

### Step 5: 테스트

- `NotificationPresentationPlannerTests`에 허브 내 로컬 push 시나리오 추가
- route-less `workoutPR`는 기존 ContentView 위임 유지 확인

## Test Strategy

| 테스트 | 검증 |
|--------|------|
| 뱃지/레벨업 알림 탭 → `.personalRecords` destination 설정 | 로컬 push 경로 동작 |
| `.workoutDetail` route 알림 → ContentView 위임 유지 | 기존 동작 보존 |
| route-less workoutPR → ContentView requestNavigation 유지 | 기존 fallback 보존 |
| 시스템 알림 탭 → ContentView 경유 PersonalRecords push | 외부 진입 보존 |

## Risks

| Risk | Mitigation |
|------|------------|
| `open()`의 emit과 로컬 push가 동시 발생 → 이중 navigation | Step 4에서 emit 방지 또는 ContentView에서 허브 표시 중 request 무시 |
| `PersonalRecordsDetailView` 의존성 (SharedHealthDataService) | ContentView의 `NotificationPersonalRecordsPushView` 패턴 재사용 |
| route-less workoutPR fallback 경로 변경 위험 | 해당 분기는 수정하지 않음 |
