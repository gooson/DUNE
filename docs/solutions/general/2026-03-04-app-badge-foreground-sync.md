---
tags: [notification, badge, UNUserNotificationCenter, scenePhase, foreground]
date: 2026-03-04
category: solution
status: implemented
---

# 앱 뱃지 포그라운드 동기화 누락

## Problem

앱 아이콘 뱃지가 앱 진입 시 사라지지 않는 현상. 사용자가 알림을 받은 후 앱을 열어도 홈 화면의 뱃지 숫자가 유지됨.

## Root Cause

`NotificationInboxManager.postInboxDidChange()`를 통한 `badgeUpdater` 호출은 **명시적 inbox 상태 변경**(markRead, deleteAll 등)에서만 트리거됨. 앱이 포그라운드에 진입할 때 시스템 뱃지를 현재 unread 수와 동기화하는 코드가 없었음.

`ContentView.onChange(of: scenePhase)`는 데이터 refresh만 수행하고 뱃지 동기화를 하지 않았음. `DashboardView.reloadUnreadCount()`는 UI bell icon만 업데이트하고 `UNUserNotificationCenter.setBadgeCount()`는 호출하지 않았음.

## Solution

1. `NotificationInboxManager.syncBadge()` 추가 — 현재 unread count를 시스템 뱃지에 동기화 + unread=0이면 delivered notifications 제거
2. `ContentView.onChange(of: scenePhase)` — `.active` 전환 시 `syncBadge()` 호출

## Prevention

- 시스템 뱃지를 변경하는 코드는 `NotificationInboxManager`에 집중하고, 포그라운드 진입 경로에서 반드시 동기화
- 뱃지 관련 변경 시 체크리스트: (1) inbox mutation 경로 (2) 포그라운드 진입 경로 (3) 알림 수신 경로
