---
tags: [navigation, swiftui, notification, activity, navigationdestination, request-token]
category: architecture
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNETests/NotificationActivityDestinationTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-02-watch-navigation-request-observer-update-loop.md
---

# Solution: Notification Navigation Multi-Update Warning

## Problem

Activity 탭의 외부 notification 라우팅에서 `Update NavigationRequestObserver tried to update multiple times per frame.` 경고가 발생할 수 있었다.

### Symptoms

- personal records 알림 경로를 열 때 콘솔에 `NavigationRequestObserver` multi-update 경고가 출력됨
- 경고는 즉시 크래시로 이어지지 않지만, 같은 프레임 안에서 `navigationDestination(item:)` 바인딩을 두 번 갱신하고 있다는 신호였다

### Root Cause

`ActivityView.handleExternalPersonalRecordsRoute()`가 같은 메인 런루프 안에서 `notificationActivityDestination = nil` 후 곧바로 `.personalRecords`를 다시 대입하고 있었다.

이 nil trampoline은 "같은 목적지 재열기"를 강제하려는 의도였지만, SwiftUI 입장에서는 같은 프레임에 navigation binding이 두 번 변한 것으로 보이기 때문에 `NavigationRequestObserver` 경고를 유발했다.

## Solution

`navigationDestination(item:)`가 한 번만 갱신되도록 request token 기반 `Identifiable` wrapper를 도입했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/ActivityView.swift` | `NotificationActivityDestination`에 `requestID` 추가, `nil -> value` 재할당 제거 | 같은 destination 재요청도 단일 write로 처리 |
| `DUNETests/NotificationActivityDestinationTests.swift` | request token에 따라 ID가 달라지는지 검증 | 반복 라우팅 contract 고정 |

### Key Code

```swift
notificationActivityDestination = NotificationActivityDestination(
    destination: .personalRecords,
    requestID: notificationPersonalRecordsSignal
)
```

## Prevention

### Checklist Addition

- [ ] `navigationDestination(item:)` 재트리거를 위해 같은 frame에 `nil -> value` 대입을 하지 않는다.
- [ ] 동일 목적지를 반복 push해야 하면 optional reset 대신 request token/unique ID를 모델에 포함한다.

### Rule Addition (if applicable)

active correction에 `navigationDestination(item:)` 재트리거 패턴을 추가했다.

## Lessons Learned

`NavigationRequestObserver` 경고는 단순 로그가 아니라 SwiftUI navigation binding을 잘못 다루고 있다는 구조 신호다. 동일 destination을 다시 열어야 할 때는 상태를 두 번 쓰는 편법보다, 식별자를 요청 단위로 분리하는 쪽이 더 안정적이다.
