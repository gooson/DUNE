---
tags: [notification, navigation, cold-launch, navigationstack, dedup, request-broker]
category: architecture
date: 2026-03-08
severity: important
related_files:
  - DUNE/Data/Persistence/NotificationInboxManager.swift
  - DUNE/App/ContentView.swift
  - DUNETests/NotificationInboxManagerTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
  - docs/solutions/architecture/2026-03-08-notification-navigation-multi-update-warning.md
  - docs/solutions/architecture/2026-03-02-watch-navigation-request-observer-update-loop.md
---

# Solution: Notification Navigation Request Delivery Dedup

## Problem

Notification tap 이후 iOS root routing에서 동일한 navigation request가 두 번 전달되며 SwiftUI가 같은 frame 안에서 `NavigationPath`를 중복 갱신할 수 있었다.

### Symptoms

- 콘솔에 `Update NavigationRequestObserver tried to update multiple times per frame.` 경고가 출력됨
- 이어서 `Update NavigationAuthority bound path tried to update multiple times per frame.` 경고가 함께 보일 수 있음
- 특히 cold launch 경로에서 알림 탭 직후 detail push가 간헐적으로 중복 적용될 수 있음

### Root Cause

`NotificationInboxManager.emitNavigationRequest()`가 동일 request를 두 채널로 전달하고 있었다.

1. `pendingNavigationRequest`에 즉시 저장
2. 별도 `NotificationCenter` post를 비동기로 예약

`ContentView`는 startup `.task`에서 pending request를 consume하고, 동시에 `.onReceive(routeRequestedNotification)`도 같은 request를 처리했다. cold launch 타이밍에 두 경로가 모두 살아 있으면 같은 request가 두 번 `handleNotificationNavigationRequest()`로 들어가며 동일 `NavigationPath` write가 중복될 수 있었다.

## Solution

request를 적용하기 전에 "이 request가 아직 pending ownership을 가지고 있는가"를 확인하는 matching consume gate를 추가했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Persistence/NotificationInboxManager.swift` | `consumePendingNavigationRequest(ifMatching:) -> Bool` 추가 | pending request를 정확히 한 번만 소비하도록 gate 제공 |
| `DUNE/App/ContentView.swift` | `.onReceive`에서 matching consume 성공 시에만 route 적용 | startup `.task`가 먼저 가져간 request의 delayed post를 무시 |
| `DUNETests/NotificationInboxManagerTests.swift` | matching consume success/failure 시나리오 추가 | duplicate delivery contract 회귀 방지 |

### Key Code

```swift
.onReceive(NotificationCenter.default.publisher(for: NotificationInboxManager.routeRequestedNotification)) { notification in
    guard let request = NotificationInboxManager.navigationRequest(from: notification) else { return }
    guard notificationInboxManager.consumePendingNavigationRequest(ifMatching: request) else { return }
    handleNotificationNavigationRequest(request)
}
```

## Prevention

notification/deep-link broker는 "pending state"와 "broadcast event"를 함께 쓸 때 ownership semantics를 반드시 명시해야 한다.

### Checklist Addition

- [ ] startup recovery path와 live event path가 같은 request를 각각 처리하지 않는지 확인한다.
- [ ] `NavigationPath`/`navigationDestination(item:)`를 외부 이벤트로 갱신할 때 request가 한 번만 소비되는지 먼저 점검한다.
- [ ] cold launch deep-link는 pending consume와 delayed notification post의 race를 테스트로 고정한다.

### Rule Addition (if applicable)

새 규칙 파일 추가는 생략했다. 이 패턴은 notification routing solution 문서와 unit test contract로 관리한다.

## Lessons Learned

SwiftUI navigation multi-update warning은 view 내부 상태 전환 문제만이 아니라, 상위 event broker가 같은 request를 두 번 전달하는 구조 신호일 수 있다. 외부 이벤트 라우팅은 "누가 request ownership을 가졌는가"를 명확히 해야 path/state write가 안정적이다.
