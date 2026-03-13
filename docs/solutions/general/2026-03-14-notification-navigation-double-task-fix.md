---
tags: [notification, navigation, Task, MainActor, DispatchQueue, race-condition, .onReceive]
date: 2026-03-14
category: solution
status: implemented
---

# 알림 탭 네비게이션 실패: Double-Task 래핑 제거

## Problem

어떤 알림이든 탭하면 앱이 열리지만 목표 화면으로 네비게이션되지 않음. cold-start, warm-start 모두 동일.

원인 커밋: `24de7c09` (MainActor hardening, 2026-03-12)에서 `.onReceive` 핸들러를 `Task { @MainActor in }` 으로 래핑.

## Root Cause

`emitNavigationRequest`가 `Task { @MainActor in }` 으로 NotificationCenter post → `.onReceive` 발화 → 내부에서 또 `Task { @MainActor in }` 생성 → 2중 Task 홉. Swift concurrency의 cooperative scheduling으로 인해 두 번째 Task 실행 시점이 비결정적이 되어, consume 시점에 pending request가 이미 사라지거나 SwiftUI view update cycle과 맞지 않음.

## Solution

### 1. `.onReceive` 핸들러 동기화 (ContentView.swift)

```swift
// Before (실패): Task 래핑으로 비동기 홉
.onReceive(routeRequested) { notification in
    let request = extract(notification)
    Task { @MainActor in
        guard let request else { return }
        guard consume(ifMatching: request) else { return }
        handleNotificationNavigationRequest(request)
    }
}

// After (동작): 동기 실행
.onReceive(routeRequested) { notification in
    guard let request = extract(notification) else { return }
    guard consume(ifMatching: request) else { return }
    handleNotificationNavigationRequest(request)
}
```

`.onReceive` closure는 SwiftUI가 MainActor에서 호출하므로 추가 Task 불필요.

### 2. `emitNavigationRequest` — Task → DispatchQueue.main.async (NotificationInboxManager.swift)

```swift
// Before: Task { @MainActor in } — 비결정적 scheduling
Task { @MainActor in
    NotificationCenter.default.post(name: Self.routeRequestedNotification, object: request)
}

// After: DispatchQueue.main.async — run loop 기반 확정적 delivery
DispatchQueue.main.async {
    NotificationCenter.default.post(name: Self.routeRequestedNotification, object: request)
}
```

### 3. warm-start fallback 추가 (ContentView.swift)

`scenePhase .active` 전환 시 pending navigation 확인 (`.onReceive` 미발화 대비):

```swift
if newPhase == .active {
    // Fallback: consume if .onReceive missed it (dedup via consume)
    if let request = notificationInboxManager.consumePendingNavigationRequest() {
        handleNotificationNavigationRequest(request)
    }
}
```

## Prevention

1. **`.onReceive` 핸들러에 `Task { @MainActor in }` 래핑 금지** — `.onReceive`는 이미 MainActor
2. **NotificationCenter post에 `Task { @MainActor in }` 대신 `DispatchQueue.main.async` 사용** — Combine publisher 기반 `.onReceive`와 같은 run loop 메커니즘 사용
3. **notification 기반 navigation은 3중 안전망 유지**: `.onReceive` (즉시) + `scenePhase .active` (fallback) + `.task(id: launchExperienceReady)` (cold-start)

## Key Insight

`Task { @MainActor in }` vs `DispatchQueue.main.async`의 차이:
- `Task { @MainActor in }`: Swift cooperative executor에 의해 스케줄링. 다른 Task가 yield할 때까지 실행 보장 없음
- `DispatchQueue.main.async`: main run loop에 직접 enqueue. `.onReceive`가 Combine→RunLoop 경로이므로 같은 메커니즘 사용 시 delivery 타이밍이 확정적

## Related

- `docs/solutions/architecture/2026-03-12-notification-ingress-mainactor-hardening.md` — 원인 커밋의 문서
- `docs/solutions/general/2026-03-13-notification-cold-start-crash-fix.md` — cold-start 관련 이전 수정
