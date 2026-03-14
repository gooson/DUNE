---
tags: [notification, delegate, async, main-thread, crash, UNUserNotificationCenterDelegate, swift-concurrency]
category: general
date: 2026-03-14
severity: critical
related_files:
  - DUNE/App/AppNotificationCenterDelegate.swift
  - DUNETests/AppNotificationCenterDelegateTests.swift
related_solutions:
  - docs/solutions/general/2026-03-14-notification-tap-main-thread-crash-fix.md
  - docs/solutions/architecture/2026-03-12-notification-ingress-mainactor-hardening.md
---

# Solution: Notification Delegate Async Return Thread Crash

## Problem

알림 센터에서 알림을 탭하면 앱이 `NSInternalInconsistencyException: Call must be made on main thread` 크래시 발생.

### Symptoms

- `_performBlockAfterCATransactionCommitSynchronizes:` assertion failure
- `SwiftUIApplication` 내부에서 CA transaction 동기화 시 main thread 아닌 곳에서 호출
- route 없는 알림에서도 발생 (notification dropped 경로 포함)

### Root Cause

`AppNotificationCenterDelegate`가 `UNUserNotificationCenterDelegate`의 **async** 버전 delegate 메서드를 사용하고 있었다:

```swift
nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
) async {
    // ...
    await forwardNotificationResponse(payload)
    // ← 여기서 임의 executor에서 리턴
}
```

`nonisolated async` 메서드에서 `await` 이후 Swift Concurrency는 continuation을 임의 executor에서 재개한다. 메서드가 리턴하면 UIKit의 내부 completion handler가 해당 (non-main) 스레드에서 호출되고, CA transaction synchronization이 main thread assertion을 발생시킨다.

기존 솔루션들(2026-03-14 post-yield actor drift, 2026-03-12 notification ingress hardening)은 ContentView와 publisher 쪽을 고쳤지만, delegate 메서드 자체의 async 리턴 스레드는 수정하지 않았다.

## Solution

completion-handler 기반 delegate 메서드로 전환. `UNUserNotificationCenter`는 delegate 메서드를 main thread에서 호출하므로, `responseHandler`와 `completionHandler`를 동기적으로 호출.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `AppNotificationCenterDelegate.swift` | `willPresent` async → completion-handler | async 리턴 스레드 문제 방지 |
| `AppNotificationCenterDelegate.swift` | `didReceive` async → completion-handler | main thread에서 동기 호출 보장 |
| `AppNotificationCenterDelegate.swift` | `forwardNotificationResponse` 제거 | delegate가 직접 호출하므로 dead code |
| `AppNotificationCenterDelegateTests.swift` | 테스트 간소화 | 제거된 메서드 대신 생성자 주입 검증 |

### Key Code

```swift
// Before: async — returns on arbitrary thread
nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
) async {
    await forwardNotificationResponse(payload)
}

// After: completion-handler — called on main thread by UIKit
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    responseHandler(payload)
    completionHandler()
}
```

## Prevention

### Checklist Addition

- [ ] `UNUserNotificationCenterDelegate`의 async 버전 메서드 사용 금지 — completion-handler 버전을 사용하여 main thread 리턴 보장
- [ ] `nonisolated async` 메서드에서 `await` 이후 리턴 스레드가 UIKit 내부 completion handler에 영향을 주는지 확인
- [ ] delegate 패턴에서 async overload 대신 completion-handler overload가 스레드 안전성 면에서 우선

## Lessons Learned

- Swift Concurrency의 async delegate overload는 편리하지만, `nonisolated` context에서 `await` 이후 리턴 스레드를 보장하지 않는다.
- UIKit delegate의 async 버전은 내부적으로 completion handler를 래핑하는데, 리턴 스레드가 main이 아니면 assertion이 발생할 수 있다.
- `handleNotificationResponse`에서 아무 UI 변경을 하지 않는 "dropped" 경로에서도 크래시가 발생한 이유는, delegate 메서드 리턴 자체가 UIKit의 CA transaction을 트리거하기 때문이다.
