---
tags: [notification, routing, activity-tab, level-up, personal-records]
date: 2026-03-05
category: architecture
status: implemented
related_files:
  - DUNE/Domain/Models/NotificationInboxItem.swift
  - DUNE/Data/Persistence/NotificationInboxManager.swift
  - DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift
  - DUNE/App/ContentView.swift
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Dashboard/NotificationHubView.swift
---

# Solution: Level Up Notification Landing Route

## Problem

`workoutPR` 알림 중 `levelUp` 이벤트는 운동 상세(`workoutDetail`) 또는 route-less fallback(metric detail)로 처리되어,
사용자가 기대하는 "Achievement History / Personal Records" 화면으로 바로 도달하지 못했다.

### Symptoms

- 레벨업 알림 탭 시 맥락에 맞는 랜딩 페이지 부재
- route가 없는 legacy `workoutPR` 알림은 허브에서 일관된 목적지로 이동하지 못함

### Root Cause

- `NotificationRoute`에 레벨업 전용 목적지가 없었음
- `handleNotificationResponse`의 route-less 분기가 `workoutPR`를 일반 non-routed 알림과 동일하게 처리했음
- Activity 탭은 workout 상세 signal만 받아서 PR 상세로의 외부 진입 경로가 없었음

## Solution

레벨업 알림 전용 라우트(`activityPersonalRecords`)를 추가하고, 앱/허브/백그라운드 생성 경로를 모두 이 라우트로 연결했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Models/NotificationInboxItem.swift` | `NotificationRoute.Destination.activityPersonalRecords` 추가 | 레벨업 랜딩 목적지 명시 |
| `DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift` | 대표 이벤트가 `.levelUp`일 때 route를 `.activityPersonalRecords`로 설정 | 신규 레벨업 알림을 PR 상세로 직접 연결 |
| `DUNE/Data/Persistence/NotificationInboxManager.swift` | route-less `workoutPR` 분기 추가, `userInfo` encode/decode 확장 | legacy 알림도 동일 랜딩 보장 |
| `DUNE/App/ContentView.swift` | `activityPersonalRecords` 수신 시 Activity 탭 전환 + signal 전달 | 전역 라우팅 처리 |
| `DUNE/Presentation/Activity/ActivityView.swift` | 외부 signal 기반 `personalRecords` programmatic navigation 추가 | Activity 상세로 실제 랜딩 |
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | route-less `workoutPR` 탭 fallback을 `.activityPersonalRecords`로 변경 | 허브 탭 동작 일관화 |
| `DUNE/Data/Persistence/NotificationThrottleStore.swift` | dedup route key에 신규 목적지 반영 | route-aware dedup 안정성 유지 |

## Prevention

- 보상형 알림(`levelUp`, `badge`)은 metric fallback이 아니라 도메인 상세 화면으로 라우팅한다.
- `NotificationRoute.Destination` 추가 시 필수 점검:
  - userInfo serialize/parse
  - global route handler(`ContentView`)
  - route dedup key
  - notification hub fallback path
  - 관련 unit test

