---
tags: [watchos, notification, background, coremotion, sedentary, stretch-reminder, UNTimeIntervalNotificationTrigger]
date: 2026-03-28
category: general
status: implemented
---

# watchOS 스트레칭 알림 백그라운드 미작동 수정

## Problem

워치에서 오래 앉아 있어도 스트레칭 알림이 발생하지 않음.

### 근본 원인 2가지

1. **알림 권한 미요청**: `WatchPostureMonitor`가 `UNUserNotificationCenter.add(request)`로 로컬 알림을 발송하지만, `requestAuthorization(options:)` 호출이 없었음. watchOS에서 권한 없이 알림은 조용히 실패.

2. **Task.sleep 기반 폴링이 watchOS 백그라운드에서 중단**: `Task.sleep(for: .seconds(60))` 루프가 watchOS 앱 중단 시 실행되지 않아, 사용자가 앱 화면을 보고 있지 않으면 `checkSedentaryDuration()`이 호출되지 않음.

## Solution

### 핵심 전략 전환

**Before**: 매분 `Task.sleep` → `checkSedentaryDuration()` → 조건 충족 시 즉시 알림
**After**: 정지 상태 진입 시 `UNTimeIntervalNotificationTrigger`로 미래 알림 예약 → 움직이면 취소

### 변경 사항

| 변경 | 설명 |
|------|------|
| `requestNotificationAuthorization()` 추가 | `startMonitoring()` 시 알림 권한 요청 |
| `scheduleStretchNotifications()` 추가 | 정지 상태 진입 시 1x/2x/3x threshold 알림 3건 예약 |
| `cancelScheduledStretchNotifications()` 추가 | 움직임 감지 시 예약 알림 전체 취소 |
| 야간 체크 per-notification | 예약 시점이 아닌 각 알림의 delivery time 기준으로 야간 필터링 |
| `checkSedentaryDuration()` 역할 축소 | UI 카운터 업데이트 전용 (알림 트리거 제거) |

### 핵심 코드 패턴

```swift
// 정지 상태 진입 시 — OS가 백그라운드에서도 전달
let trigger = UNTimeIntervalNotificationTrigger(
    timeInterval: thresholdSeconds * Double(index + 1),
    repeats: false
)

// 각 알림의 delivery time으로 야간 필터링
let deliveryDate = now.addingTimeInterval(delay)
let deliveryHour = calendar.component(.hour, from: deliveryDate)
if deliveryHour >= nightStart || deliveryHour < nightEnd { continue }

// 움직임 감지 시 — 모든 예약 취소
UNUserNotificationCenter.current().removePendingNotificationRequests(
    withIdentifiers: Self.scheduledNotificationIdentifiers
)
```

## Prevention

### watchOS 백그라운드 실행 체크리스트

1. **`Task.sleep` / `Timer` 기반 폴링은 watchOS에서 금지**: 앱이 중단되면 실행 안 됨
2. **반복 알림 → `UNTimeIntervalNotificationTrigger`**: OS가 앱 상태와 무관하게 전달
3. **알림 권한은 사용 시점에 반드시 요청**: watchOS도 iOS와 동일하게 `requestAuthorization` 필수
4. **야간 시간 체크는 delivery time 기준**: 예약 시점 기준으로만 체크하면 threshold 간격에 따라 야간에 알림 도착 가능
5. **`static let` 으로 identifier 배열 캐싱**: `cancelScheduledStretchNotifications()`가 활동 전환마다 호출되므로 매번 할당 방지

### watchOS 알림 패턴 원칙

- **포그라운드 타이머**: UI 업데이트/카운터 전용
- **백그라운드 알림**: `UNTimeIntervalNotificationTrigger` + cancel-on-state-change 패턴
- **권한 요청**: 기능 활성화 시점에 `requestAuthorization` 호출

## Lessons Learned

1. **iOS 패턴을 watchOS에 그대로 적용하면 안 됨**: iOS에서는 앱이 백그라운드에서도 일정 시간 실행되지만, watchOS는 거의 즉시 중단됨
2. **알림 권한 누락은 silent failure**: 에러 로그도 없이 알림이 전달되지 않으므로, 테스트 시 권한 상태를 반드시 확인
3. **야간 시간 필터링은 예약 시점이 아닌 전달 시점 기준**: `UNTimeIntervalNotificationTrigger`의 offset이 야간 시간을 넘을 수 있음
