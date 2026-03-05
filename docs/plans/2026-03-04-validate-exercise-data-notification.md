---
tags: [notification, exercise, validation, testing]
date: 2026-03-04
category: plan
status: draft
---

# 알림 시스템 운동 데이터 전달 검증

## Problem Statement

알림 시스템에서 운동 데이터가 정확히 전달되는지 검증이 필요하다.
데이터 흐름: `HKWorkout → WorkoutSummary → HealthInsight → NotificationInboxItem → userInfo → parseRoute → ContentView → ActivityView`

## 현재 상태 분석

### 검증 체크포인트 (기존)
1. **Encoding** (`notificationUserInfo`): `!workoutID.isEmpty` 체크
2. **Decoding** (`parseRoute`): routeKind + workoutID 존재 + `!isEmpty` 체크
3. **Routing** (`handleNotificationNavigationRequest`): `!workoutID.isEmpty` 체크

### 발견된 Gap
1. **UserInfo 인코딩-디코딩 라운드트립 테스트 부재**: `notificationUserInfo()` → `parseRoute()` 왕복 검증 없음
2. **빈 workoutID로 route 생성 가능**: `NotificationRoute.workoutDetail(workoutID: "")` 가 방어 없이 생성됨
3. **Inbox Store Codable 라운드트립에서 route 보존 미검증**: route가 JSON 직렬화/역직렬화 후 유지되는지 테스트 없음
4. **handleNotificationResponse 분기 테스트 부재**: itemID 있는 경우/없는 경우, route 있는 경우/없는 경우

## Implementation Plan

### Step 1: NotificationRoute 팩토리에 빈 ID 방어 추가
- `NotificationRoute.workoutDetail(workoutID:)` 에서 빈 문자열이면 nil 반환하도록 변경
- 팩토리 반환 타입을 `NotificationRoute?`로 변경

### Step 2: 테스트 작성 - 데이터 전달 검증
기존 `NotificationInboxManagerTests`에 다음 테스트 추가:
- `notificationUserInfo` → `parseRoute` 라운드트립 (유효 workoutID)
- `notificationUserInfo` → `parseRoute` 라운드트립 (빈 workoutID → nil)
- `notificationUserInfo` → `parseRoute` 라운드트립 (route 없는 insight → route nil)
- `handleNotificationResponse`로 유효 userInfo 전달 시 navigation request 발생 확인
- `handleNotificationResponse`로 잘못된 userInfo 전달 시 무시 확인
- Codable 라운드트립: NotificationInboxItem의 route가 보존되는지 확인

### Step 3: 테스트 작성 - NotificationRoute 모델 검증
새 `NotificationRouteTests.swift` 생성:
- workoutDetail 팩토리 유효 ID → route 생성
- workoutDetail 팩토리 빈 ID → nil
- Codable 라운드트립
- Equatable/Hashable 동작

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Domain/Models/NotificationInboxItem.swift` | `workoutDetail` 팩토리 방어 로직 |
| `DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift` | 빈 ID 방어에 따른 optional handling |
| `DUNETests/NotificationInboxManagerTests.swift` | 라운드트립/분기 테스트 추가 |
| `DUNETests/NotificationRouteTests.swift` | 신규: route 모델 테스트 |
