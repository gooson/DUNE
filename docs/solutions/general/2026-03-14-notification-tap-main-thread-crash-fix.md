---
tags: [notification, cold-start, mainactor, swiftui, task, task-yield, navigation]
category: general
date: 2026-03-14
severity: important
related_files:
  - DUNE/App/ContentView.swift
  - DUNETests/NotificationPresentationPlannerTests.swift
related_solutions:
  - docs/solutions/general/2026-03-13-notification-cold-start-crash-fix.md
  - docs/solutions/general/2026-03-14-notification-navigation-double-task-fix.md
  - docs/solutions/architecture/2026-03-12-notification-ingress-mainactor-hardening.md
---

# Solution: Notification Tap Cold-Start Main-Thread Crash

## Problem

OS 알림센터에서 알림을 탭해 앱을 cold-start 하면 간헐적으로 다음 크래시가 발생했다.

### Symptoms

- `NSInternalInconsistencyException`
- `Call must be made on main thread`
- 로그상 `AppNotificationCenterDelegate` → `NotificationInboxManager.emitNavigationRequest()` 까지는 정상
- route-less 알림은 `notificationHub` fallback 직후 크래시

### Root Cause

`ContentView`의 cold-start fallback은 `.task(id: launchExperienceReady)` 내부에서 pending notification request를 소비했다.

문제는 이 경로가 다음 순서를 가졌다는 점이다:

1. `.task(id:)` action 시작
2. `await Task.yield()` 로 NavigationStack destination 등록 대기
3. yield 이후 같은 task 안에서 `selectedSection`, `notificationHubSignal`, `NavigationPath` 직접 변경

Apple SwiftUI 문서 기준 `View.task(id:_:)` 는 `nonisolated` modifier이고 action closure는 `@isolated(any)` async closure다.
즉 첫 suspension 이후 재개 executor가 main actor로 고정되지 않는다. `Task.yield()` 이후 notification navigation state를 직접
변경하면 UIKit/SwiftUI navigation update가 background thread에서 실행되어 main-thread assertion이 발생할 수 있다.

기존 2026-03-13 수정은 cold-start 타이밍 자체를 defer했고, 2026-03-14 수정은 `.onReceive` double-task race를 제거했지만,
post-yield actor drift까지는 고정하지 못했다.

## Solution

notification navigation을 두 단계로 분리했다.

1. `NotificationPresentationState`
   - 현재 tab / navigation path / signal 변화를 pure reducer로 계산
2. `@MainActor` apply helper
   - 실제 `@State` 와 `NavigationPath` mutation은 main actor 경계 안에서만 반영

cold-start `.task(id:)` fallback은 `await MainActor.run { ... }` 으로 reducer 결과를 apply하도록 바꿨다.
동시에 `.onReceive` 와 `scenePhase` fallback도 `MainActor.assumeIsolated` 경유로 같은 helper를 사용하게 정리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/ContentView.swift` | notification state reducer 추가 + `@MainActor` apply helper 도입 | cold-start post-yield UI mutation을 main actor로 고정 |
| `DUNE/App/ContentView.swift` | `.task(id: launchExperienceReady)` 에 `await MainActor.run` 추가 | `Task.yield()` 이후 executor drift 방지 |
| `DUNE/App/ContentView.swift` | warm-start ingress를 동일 helper로 정리 | notification routing state contract 일관화 |
| `DUNETests/NotificationPresentationPlannerTests.swift` | reducer state regression test 추가 | notificationHub / workout / sleep routing state mutation 고정 |

### Key Code

```swift
.task(id: launchExperienceReady) {
    guard launchExperienceReady else { return }
    await Task.yield()
    if let request = notificationInboxManager.consumePendingNavigationRequest() {
        await MainActor.run {
            handleNotificationNavigationRequest(request)
        }
    }
}
```

```swift
@MainActor
private func handleNotificationNavigationRequest(_ request: NotificationNavigationRequest) {
    var state = currentNotificationPresentationState
    state.apply(request)
    applyNotificationPresentationState(state)
}
```

## Prevention

notification cold-start routing에서 `task` 기반 deferral을 사용할 때는 **yield/await 이후 actor drift** 를 항상 점검한다.

### Checklist Addition

- [ ] SwiftUI `.task` / `.task(id:)` 안에서 첫 `await` 이후 `@State`, `NavigationPath`, tab selection을 직접 변경하지 않는지 확인한다.
- [ ] cold-start fallback이 필요하면 `await MainActor.run` 또는 `@MainActor` helper 경계를 명시한다.
- [ ] notification routing 수정 시 `.onReceive`, `scenePhase`, cold-start `.task` 세 ingress가 동일한 actor contract를 공유하는지 확인한다.

### Rule Addition (if applicable)

새 규칙 파일까지는 필요 없다. 다만 notification / launch sequencing 리뷰 시 "post-await UI mutation actor drift" 체크를 반복 적용한다.

## Lessons Learned

- cold-start bug는 timing만 맞춰도 끝나지 않는다. `yield` 이후 어떤 actor에서 재개되는지까지 봐야 한다.
- SwiftUI notification navigation은 pure reducer와 main actor apply를 분리하면 디버깅과 회귀 테스트가 쉬워진다.
