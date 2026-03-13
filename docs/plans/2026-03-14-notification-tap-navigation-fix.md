---
tags: [notification, navigation, race-condition, MainActor, Task-wrapping]
date: 2026-03-14
category: plan
status: draft
---

# 알림 탭 시 앱 내 네비게이션 실패 수정

## Problem Statement

어떤 알림이든 탭하면 앱이 열리지만 목표 화면으로 네비게이션이 되지 않는 문제. cold-start, warm-start 모두 동일.

## Root Cause Analysis

### 원인 1: `.onReceive` 내 불필요한 Task 래핑 (주 원인)

commit `24de7c09` (MainActor hardening)에서 ContentView의 `.onReceive` 핸들러를 `Task { @MainActor in }` 로 래핑함.

**Before (동작함):**
```swift
.onReceive(routeRequested) { notification in
    guard let request = extract(notification) else { return }
    guard consume(ifMatching: request) else { return }
    handleNotificationNavigationRequest(request)  // 동기 실행
}
```

**After (실패):**
```swift
.onReceive(routeRequested) { notification in
    let request = extract(notification)
    Task { @MainActor in           // ← 비동기 홉 추가
        guard let request else { return }
        guard consume(ifMatching: request) else { return }
        handleNotificationNavigationRequest(request)
    }
}
```

이로 인해:
- `emitNavigationRequest`가 `Task { @MainActor in }` 으로 notification을 post
- `.onReceive`가 발화 → 내부에 또다른 `Task { @MainActor in }` 생성
- 2중 Task 홉: post Task → `.onReceive` 동기 → consume Task 생성 → post Task 완료 → consume Task 실행
- consume Task가 실행될 때 pending request가 이미 다른 경로에 의해 소비되었거나, SwiftUI view update cycle과 맞지 않음

### 원인 2: background→foreground 전환 시 `.onReceive` 미발화 가능성

앱이 background 상태일 때 `didReceive` 가 먼저 호출되고, scene이 아직 `.active`가 아닌 시점에
`emitNavigationRequest` 의 Task가 notification을 post하면, SwiftUI가 `.onReceive` 를 즉시 처리하지 않을 수 있음.

### 원인 3: background→foreground 전환 시 fallback 경로 부재

warm-start에서 `.onReceive`가 실패하면 navigation request를 소비할 다른 경로가 없음.
cold-start는 `.task(id: launchExperienceReady)` 가 fallback이지만, warm-start에는 fallback이 없음.

## Solution Design

### 3중 안전망 아키텍처

```
Path 1: .onReceive (즉시) — warm-start 주 경로
Path 2: scenePhase .active (fallback) — warm-start 보험
Path 3: .task(id: launchExperienceReady) — cold-start 전용
```

### Step 1: `.onReceive` 핸들러에서 Task 래핑 제거

**파일**: `DUNE/App/ContentView.swift`

`.onReceive` 핸들러를 동기 실행으로 복원:
```swift
.onReceive(routeRequested) { notification in
    guard let request = NotificationInboxManager.navigationRequest(from: notification) else { return }
    guard notificationInboxManager.consumePendingNavigationRequest(ifMatching: request) else { return }
    handleNotificationNavigationRequest(request)
}
```

근거: `.onReceive` closure는 SwiftUI가 MainActor에서 호출한다. `consumePendingNavigationRequest`는 DispatchQueue.sync로 thread-safe하다. `handleNotificationNavigationRequest`는 `@State` 수정이므로 MainActor 필요하나, `.onReceive`가 이미 MainActor이므로 추가 Task 불필요.

### Step 2: `emitNavigationRequest` 에서 Task 래핑 제거

**파일**: `DUNE/Data/Persistence/NotificationInboxManager.swift`

notification post를 동기화:
```swift
private func emitNavigationRequest(_ request: NotificationNavigationRequest) {
    queue.sync { pendingNavigationRequest = request }
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: Self.routeRequestedNotification, object: request)
    }
}
```

`Task { @MainActor in }` → `DispatchQueue.main.async` 변경 이유:
- Swift concurrency Task는 cooperative scheduling으로 실행 시점 예측이 어려움
- `DispatchQueue.main.async`는 run loop에 직접 enqueue하여 더 확정적
- `.onReceive`의 Combine publisher는 run loop 기반이므로 같은 메커니즘 사용

### Step 3: warm-start fallback 추가

**파일**: `DUNE/App/ContentView.swift`

`scenePhase` `.active` 전환 시 pending navigation 확인:
```swift
.onChange(of: scenePhase) { oldPhase, newPhase in
    if newPhase == .active {
        notificationInboxManager.syncBadge()
        // Fallback: check pending navigation missed by .onReceive
        if let request = notificationInboxManager.consumePendingNavigationRequest() {
            handleNotificationNavigationRequest(request)
        }
        ...
    }
}
```

### Step 4: `postInboxDidChange` 도 동일 패턴 적용

**파일**: `DUNE/Data/Persistence/NotificationInboxManager.swift`

`postInboxDidChange`도 `Task { @MainActor in }` → `DispatchQueue.main.async`로 통일.

## Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/App/ContentView.swift` | `.onReceive` Task 제거 + scenePhase fallback 추가 |
| `DUNE/Data/Persistence/NotificationInboxManager.swift` | `emitNavigationRequest` Task → DispatchQueue.main.async |

## Test Strategy

1. **warm-start**: 앱 실행 중 notification 탭 → 올바른 화면 이동 확인
2. **cold-start**: 앱 종료 → notification 탭 → splash 후 올바른 화면 이동 확인
3. **background→foreground**: 앱 백그라운드 → notification 탭 → 올바른 화면 이동 확인
4. **각 알림 유형별**: notificationHub, workoutDetail, sleepDetail, personalRecords

## Risks

- `DispatchQueue.main.async`가 Swift 6 strict concurrency에서 경고 발생 가능 → `@Sendable` 클로저로 해결
- `.onReceive`에서 Task 제거 시 Swift 6 MainActor isolation 경고 → ContentView body가 @MainActor이므로 문제 없음
- scenePhase fallback이 `.onReceive`와 중복 소비 시도 → `consumePendingNavigationRequest(ifMatching:)` 의 dedup이 방어

## Verification

```bash
scripts/build-ios.sh
```
