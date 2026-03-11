---
tags: [notification, bedtime, sleep, delegate, mainactor, notification-center]
category: general
date: 2026-03-11
severity: important
related_files:
  - DUNE/App/AppNotificationCenterDelegate.swift
  - DUNETests/AppNotificationCenterDelegateTests.swift
  - DUNE/DUNE.xcodeproj/project.pbxproj
related_solutions:
  - docs/solutions/general/2026-03-04-sleep-notification-cold-start-crash.md
  - docs/solutions/general/2026-03-08-general-bedtime-reminder.md
---

# Solution: Bedtime Reminder Notification Delegate Fix

## Problem

취침시간 안내 알림이 foreground에서 뜰 때 배너를 눌러도 화면 전환이 되지 않고, 시스템 Notification Center 목록에도 기록이 남지 않는 회귀가 발생했다.

### Symptoms

- 취침시간 안내 알림 탭 후 Wellness 수면 상세로 이동하지 않음
- foreground 배너가 Notification Center 목록에 남지 않음

### Root Cause

원인은 `AppNotificationCenterDelegate`에 있었다.

1. `willPresent`가 `[.banner, .sound, .badge]`만 반환해 foreground 알림이 Notification Center list에 기록되지 않았다.
2. `didReceive`가 notification payload를 main actor로 넘기지 않아, notification tap 후 SwiftUI navigation 갱신 시점이 불안정했다.

## Solution

delegate가 foreground 표시 옵션과 response forwarding을 다시 담당하도록 복원했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/AppNotificationCenterDelegate.swift` | foreground presentation 옵션 상수화 + `.list` 추가, sendable payload 래퍼와 main-actor forwarding helper 추가 | foreground Notification Center 기록과 tap routing 안정화 |
| `DUNETests/AppNotificationCenterDelegateTests.swift` | `.list` 포함 여부와 forwarding main-thread 실행 회귀 테스트 추가 | 같은 회귀 재발 방지 |
| `DUNE/DUNE.xcodeproj/project.pbxproj` | 새 테스트 파일을 DUNETests 타깃에 연결 | 테스트가 실제 빌드/실행되도록 보장 |

### Key Code

```swift
static let foregroundPresentationOptions: UNNotificationPresentationOptions = [
    .banner,
    .list,
    .sound,
    .badge
]

func forwardNotificationResponse(_ payload: NotificationResponsePayload) async {
    let responseHandler = self.responseHandler
    await MainActor.run {
        responseHandler(payload)
    }
}
```

## Prevention

foreground local notification UX를 바꿀 때는 banner 표시만 보지 말고 Notification Center list 잔존 여부와 tap 후 route 전달 actor isolation을 함께 검증해야 한다.

### Checklist Addition

- [ ] `UNUserNotificationCenterDelegate.willPresent` 변경 시 `.list` 포함 여부를 확인한다
- [ ] notification tap forwarding이 main actor에서 navigation state를 갱신하는지 확인한다
- [ ] delegate 회귀 테스트가 실제 test target에 연결되어 있는지 확인한다

### Rule Addition (if applicable)

신규 rule 추가는 보류한다. 동일한 delegate/notification actor isolation 회귀가 반복되면 notification routing 규칙으로 승격할 수 있다.

## Lessons Learned

- foreground notification은 banner가 보인다고 끝이 아니라, Notification Center list 옵션까지 맞춰야 사용자 체감이 완결된다.
- Swift 6 concurrency 환경에서는 raw `userInfo` 딕셔너리를 actor 경계 너머로 바로 넘기기보다 sendable payload로 정규화하는 편이 안정적이다.
