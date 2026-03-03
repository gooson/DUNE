---
tags: [notification, inbox, deep-link, today-tab, navigation, read-unread]
category: architecture
date: 2026-03-03
severity: important
related_files:
  - DUNE/Data/Persistence/NotificationInboxStore.swift
  - DUNE/Data/Persistence/NotificationInboxManager.swift
  - DUNE/Data/Services/NotificationServiceImpl.swift
  - DUNE/App/ContentView.swift
  - DUNE/Presentation/Dashboard/NotificationHubView.swift
  - DUNE/Presentation/Activity/ActivityView.swift
related_solutions: []
---

# Solution: Notification Inbox + Workout Deep Link Routing

## Problem

Today 탭에서 알림 진입점이 없어 사용자가 최근 알림을 모아서 확인할 수 없었고, 푸시 탭 시 앱 내 운동 상세로 이어지는 라우팅 경로도 부재했다.

### Symptoms

- Today toolbar에서 알림 허브 진입 불가
- 로컬 알림은 발송되지만 앱 내 히스토리/읽음 상태 없음
- 알림 탭/푸시 탭 시 해당 운동 상세 화면으로 이동하지 않음
- 대상 운동이 없을 때 fallback 화면 부재

### Root Cause

- 알림 발송(`UNUserNotificationCenter`)과 앱 내 navigation이 분리되어 있었고,
- 알림 메타데이터(route, itemID)를 보존하는 저장소/브로커 계층이 없었다.

## Solution

알림 히스토리 저장소와 라우팅 매니저를 추가해 발송-저장-탭-이동 흐름을 하나로 묶었다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Models/NotificationInboxItem.swift` | add | 알림 item/route 모델 정의 |
| `DUNE/Data/Persistence/NotificationInboxStore.swift` | add | 최신순/읽음 상태/무제한 히스토리 저장 |
| `DUNE/Data/Persistence/NotificationInboxManager.swift` | add | 푸시 응답 처리 + 앱 라우팅 이벤트 브로커 |
| `DUNE/Data/Services/NotificationServiceImpl.swift` | update | 알림 발송 시 item 저장 + `userInfo` route 첨부 |
| `DUNE/App/AppNotificationCenterDelegate.swift` | add | `UNUserNotificationCenterDelegate` 수신 연결 |
| `DUNE/App/DUNEApp.swift` | update | 앱 시작 시 notification delegate 등록 |
| `DUNE/App/ContentView.swift` | update | route 이벤트 수신 후 Activity 탭 전환/전달 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | update | Today 벨 아이콘 + unread badge |
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | add | 최신순 허브 + 읽음/미읽음 + 모두 읽음 |
| `DUNE/Presentation/Activity/ActivityView.swift` | update | 외부 route로 workout 상세 push + not found fallback |
| `DUNE/Presentation/Shared/NotificationTargetNotFoundView.swift` | add | 대상 누락 시 사용자 안내 |

### Key Code

```swift
// NotificationServiceImpl.swift
let inboxItem = inboxManager.recordSentInsight(insight)
content.userInfo = inboxManager.notificationUserInfo(for: inboxItem)

// ContentView.swift
.onReceive(NotificationCenter.default.publisher(for: NotificationInboxManager.routeRequestedNotification)) { notification in
    guard let request = NotificationInboxManager.navigationRequest(from: notification) else { return }
    selectedSection = .train
    notificationOpenWorkoutID = request.route.workoutID
    notificationRouteSignal += 1
}
```

## Prevention

알림 기능은 "발송"만 구현하지 말고, **저장 + 라우팅 + fallback**까지 한 세트로 설계한다.

### Checklist Addition

- [ ] 로컬 알림에 itemID/route userInfo가 포함되는가?
- [ ] 푸시 탭과 인앱 허브 탭이 동일 라우팅 경로를 사용하는가?
- [ ] 대상 데이터 누락 시 fallback 화면이 준비되어 있는가?
- [ ] 읽음/미읽음 상태와 badge 반영이 동기화되는가?

### Rule Addition (if applicable)

없음. 기존 `swift-layer-boundaries`, `testing-required` 규칙 범위 내에서 해결.

## Lessons Learned

- 알림 히스토리와 navigation 이벤트를 분리하지 않고 중간 매니저로 묶으면, 푸시/인앱 탭 동작을 동일하게 유지할 수 있다.
- 탭 기반 앱에서 deep link는 전역 path 리팩터링 없이도 "탭 전환 + signal 전달" 패턴으로 안정적으로 구현 가능하다.
