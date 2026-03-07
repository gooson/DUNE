---
tags: [notification, navigation, tabview, navigationstack, personal-records, root-push]
date: 2026-03-08
category: solution
status: implemented
---

# Notification Reward Detail Root Push (Superseded)

> Follow-up: same-day regression fix replaced this outer root-stack approach with tab-scoped push paths. See `2026-03-08-tab-scoped-notification-push-preserves-navigation-bar.md`.

## Problem

`Level Up!` 또는 `New Badge Unlocked` 알림을 누르면 현재 화면에서 바로 상세를 여는 대신, 먼저 Activity 탭으로 전환한 뒤 `Personal Records` 상세로 진입하고 있었다.

이 흐름은 사용자가 보던 컨텍스트를 불필요하게 끊고, "알림에서 현재 화면 위로 상세를 푸시한다"는 기대와도 어긋났다.

## Root Cause

알림 라우팅이 `ContentView.handleNotificationNavigationRequest()`에서 route 종류와 관계없이 탭 상태(`selectedSection`)를 직접 바꾸는 방식으로 구현돼 있었다.

`activityPersonalRecords` route도 Activity 탭 내부 signal로만 열 수 있게 묶여 있었기 때문에, 현재 화면을 유지한 채 push할 수 없었다.

## Initial Approach

초기 대응에서는 `ContentView` 바깥에 root-level `NavigationStack` path를 추가하고, `activityPersonalRecords` route를 탭 전환 대신 전역 push destination으로 처리했다.

이 접근은 "현재 화면 위 push" 자체는 달성했지만, 같은 날 iOS 탭 화면의 navigation bar/toolbar ownership을 깨뜨리는 회귀가 확인되어 최종 해법으로 유지되지 않았다.

## Superseded Resolution

현재 유효한 해법은 outer root stack을 제거하고, 활성 탭의 `NavigationStack(path:)`에만 notification destination을 연결하는 tab-scoped push 구조다.

상세 내용은 `2026-03-08-tab-scoped-notification-push-preserves-navigation-bar.md`를 source of truth로 사용한다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/ContentView.swift` | `NotificationPresentationPlanner`와 outer root notification path 추가 | reward notification detail을 현재 화면 위로 push하려는 1차 시도 |
| `DUNETests/NotificationExerciseDataTests.swift` | `NotificationPresentationPlannerTests` 추가 | route별 presentation 계약 고정 |

### Key Code

```swift
case .activityPersonalRecords:
    return .push(.personalRecords(requestID: requestID))
```

## Prevention

- 이 문서의 outer root-stack 패턴은 재사용하지 않는다.
- 탭 내부 detail을 외부 이벤트에서 열 때는 먼저 "정말 탭 전환이 필요한가"를 확인한다.
- 현재 컨텍스트 위에 얹는 상세라면 전역 outer stack 대신 활성 탭의 `NavigationStack(path:)` push를 우선한다.
- 라우팅 결정은 View body 안 분기보다 pure planner/helper로 분리해서 테스트로 고정한다.

## Lessons Learned

탭 기반 앱에서 외부 이벤트 라우팅을 단순히 `selectedTab = ...`로 처리하면 UX가 쉽게 거칠어진다. 다만 "현재 화면 위 push"를 구현할 때도 탭 루트 navigation ownership은 유지해야 하므로, outer global stack보다 active-tab stack path가 더 안전하다.
