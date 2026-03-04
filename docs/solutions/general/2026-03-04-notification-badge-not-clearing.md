---
tags: [notification, badge, unread, usernotifications, dashboard]
category: general
date: 2026-03-04
severity: important
related_files:
  - DUNE/Data/Persistence/NotificationInboxManager.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNETests/NotificationInboxManagerTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
  - docs/solutions/general/2026-03-04-dashboard-notification-badge-clipping.md
---

# Solution: 알림 뱃지가 사라지지 않는 상태 불일치 수정

## Problem

NotificationHub에서 읽음 처리 또는 전체 삭제를 수행한 뒤에도 알림 뱃지가 즉시 사라지지 않는 상태 불일치가 발생했다.

### Symptoms

- NotificationHub에서 `Read All`/`Delete All` 후 Today로 돌아왔을 때 툴바 뱃지가 남아 보일 수 있음
- unread가 0이어도 iOS 앱 아이콘 badge 값이 즉시 0으로 정리되지 않음

### Root Cause

- unread 상태는 `NotificationInboxStore`에서 변경되지만, 시스템 앱 아이콘 badge 동기화는 발송 시점(`NotificationServiceImpl.send`)에만 수행되고 있었다.
- `DashboardView`는 변경 notification을 통해서만 unread를 갱신해, 화면 전환 타이밍에서 이벤트를 놓치면 재진입 시 stale 상태가 보일 수 있었다.

## Solution

unread 변경 후 처리 책임을 `NotificationInboxManager`에 집중시켜, inbox 변경 이벤트 발행과 시스템 badge 동기화를 같은 경로에서 실행했다.
또한 `DashboardView`에 재진입 동기화(`onAppear`)를 추가해 이벤트 누락 시에도 store 기준으로 최종 상태를 맞췄다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Persistence/NotificationInboxManager.swift` | `badgeUpdater` 주입 + `postInboxDidChange()`에서 unread 기반 badge 동기화 | read/unread/delete 모든 경로의 시스템 badge 일관성 확보 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | `.onAppear { reloadUnreadCount() }` 추가 | 화면 복귀 시 stale 뱃지 상태 제거 |
| `DUNETests/NotificationInboxManagerTests.swift` | 신규 테스트 2개 추가 (`markAllRead`, `deleteAll`) | badge 0 동기화 회귀 방지 |

### Key Code

```swift
private func postInboxDidChange() {
    let unreadCount = store.unreadCount()
    Task { @MainActor in
        NotificationCenter.default.post(name: Self.inboxDidChangeNotification, object: nil)
        badgeUpdater(unreadCount)
    }
}
```

## Prevention

### Checklist Addition

- [ ] unread 상태를 바꾸는 모든 경로가 동일한 "state changed" 후처리 함수(이벤트 + 시스템 동기화)를 거치는가?
- [ ] 알림/뱃지 UI는 화면 재진입(`onAppear`) 시 store 기준 재동기화를 수행하는가?
- [ ] 시스템 badge(API)와 앱 내부 unread 상태를 별개로 두지 않고 함께 검증하는 테스트가 있는가?

### Rule Addition (if applicable)

기존 규칙(`testing-required`, `compound-workflow`) 범위에서 해결 가능해 신규 rule 추가는 생략했다.

## Lessons Learned

- 알림 UX에서 뱃지 상태는 UI 표시와 OS badge가 함께 맞아야 "정상"으로 인식된다.
- 상태 변경 이벤트에만 의존하면 화면 전환 타이밍에서 stale UI가 남을 수 있어, 재진입 동기화가 방어선으로 필요하다.
