---
tags: [notification, cold-start, crash, UNUserNotificationCenter, ModelContainer, SwiftData]
date: 2026-03-13
category: general
status: implemented
---

# OS 알림센터에서 알림 탭 시 앱 크래시/미실행 수정

## Problem

iOS 알림센터(pull-down)에서 앱 알림을 탭하면 앱이 실행되지 않거나 크래시 발생.
콜드 스타트 경로에서 여러 복합 취약점이 존재했음.

## Root Causes

### 1. ModelContainer 초기화 실패 시 fatalError
`makeInMemoryFallbackContainer()`가 in-memory fallback마저 실패하면 `fatalError` 호출.
SwiftData migration plan과 in-memory config가 동시에 실패하는 edge case에서 앱 크래시.

### 2. 알림 userInfo 불완전 (bedtime reminder)
`BedtimeWatchReminderScheduler`가 `notificationRouteKind`만 설정하고 `notificationInsightType`을 누락.
`handleNotificationResponse`의 fallback path에서 `insightType` 조건 불충족 → 알림이 drop됨.

### 3. 콜드 스타트 타이밍 문제
`ContentView`의 `.task`가 `launchExperienceReady` 상태와 무관하게 즉시 실행.
스플래시 화면 표시 중 pending navigation을 소비하면 NavigationStack이 아직 구성되지 않아 navigation 실패.

## Solution

### 1. Graceful ModelContainer Fallback Chain
```
Level 1: in-memory + migration plan
Level 2: in-memory + schema only (migration plan 제외)
Level 3: empty Schema — 데이터 없이 앱 실행
```
`fatalError` 완전 제거. 어떤 상황에서도 앱이 실행됨.

### 2. Bedtime Reminder userInfo 완성
`NotificationResponsePayload`를 사용하여 `routeKind`와 `insightType` 모두 포함:
```swift
content.userInfo = NotificationResponsePayload(
    routeKind: NotificationRoute.sleepDetail.destination.rawValue,
    insightType: HealthInsight.InsightType.sleepComplete.rawValue
).userInfo
```

### 3. Cold-Start Deferral
`.task(id: launchExperienceReady)` + `guard launchExperienceReady` + `Task.yield()`로
NavigationStack destination 등록 완료 후 navigation 수행.

### 4. NotificationResponsePayload 레이어 이동
App layer → Data layer로 이동하여 `BedtimeWatchReminderScheduler`(Data)가
App layer에 의존하지 않도록 수정.

## Prevention

- 새 알림 종류 추가 시 `NotificationResponsePayload`의 `userInfo` 직렬화를 반드시 사용
- ModelContainer 초기화에 `fatalError` 사용 금지
- 콜드 스타트 경로에서 navigation 수행 시 `launchExperienceReady` 게이트 필수
- 알림 routing 변경 시 `NotificationPresentationPlannerTests`로 검증

## Files Changed

| File | Change |
|------|--------|
| `DUNE/App/DUNEApp.swift` | fatalError → 3-level fallback chain |
| `DUNE/Data/Persistence/NotificationResponsePayload.swift` | App → Data 이동 |
| `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift` | userInfo에 insightType 추가 |
| `DUNE/App/ContentView.swift` | .task(id:) + Task.yield() deferral |
| `DUNE/Data/Persistence/NotificationInboxManager.swift` | 진단 로깅 추가 |
| `DUNETests/NotificationPresentationPlannerTests.swift` | 새 테스트 |
| `DUNETests/NotificationInboxManagerTests.swift` | fallback path 테스트 |
