---
tags: [notification, exercise, validation, testing, userInfo, round-trip]
date: 2026-03-04
category: solution
status: implemented
---

# 알림 시스템 운동 데이터 전달 검증

## Problem

알림 시스템에서 운동 데이터(workoutID)가 HKWorkout → 알림 생성 → userInfo 인코딩 → 사용자 탭 → parseRoute 디코딩 → 앱 내 네비게이션까지 정확히 전달되는지 검증이 필요했다.

발견된 Gap:
1. `NotificationRoute.workoutDetail(workoutID: "")` 가 빈 문자열로 route 생성 가능
2. userInfo 인코딩→디코딩 라운드트립 테스트 부재
3. `handleNotificationResponse` 5개 분기 중 테스트 커버리지 없음

## Solution

### 1. 팩토리 방어 (빈 ID 거부)

```swift
static func workoutDetail(workoutID: String) -> NotificationRoute? {
    guard !workoutID.isEmpty else { return nil }
    return NotificationRoute(destination: .workoutDetail, workoutID: workoutID)
}
```

팩토리 반환 타입을 `NotificationRoute?`로 변경. 모든 호출자가 이미 `NotificationRoute?` 컨텍스트에서 사용하므로 영향 없음.

### 2. 3계층 검증 유지

| 계층 | 위치 | 검증 |
|------|------|------|
| Domain (factory) | `NotificationRoute.workoutDetail` | 빈 ID → nil |
| Data (encoding) | `notificationUserInfo()` | `!workoutID.isEmpty` |
| Data (decoding) | `parseRoute()` | routeKind + workoutID 존재 + `!isEmpty` |

`parseRoute()`의 isEmpty 체크는 factory guard와 중복이지만, userInfo는 외부 입력(OS 알림 시스템)이므로 독립적 방어가 올바름.

### 3. 테스트 커버리지 (20개 테스트)

- **Route 모델**: 유효 ID, 빈 ID, Codable 라운드트립, Hashable
- **UserInfo 라운드트립**: 유효 route, route 없음, 손상된 payload 5가지
- **InboxStore**: route 보존, nil route 보존
- **handleNotificationResponse**: 유효 itemID, 미존재 itemID, itemID 없음, 빈 userInfo, route 없는 itemID

## Prevention

- `NotificationRoute` 에 새 destination 추가 시 `parseRoute()`의 switch에도 반드시 추가
- 알림 route 관련 변경 시 `NotificationExerciseDataTests`의 라운드트립 테스트 실행으로 데이터 전달 검증
- 팩토리에 빈 ID 방어가 있으므로, 새로운 route destination 팩토리도 동일 패턴 적용
