---
tags: [watchos, notification, posture, stretch-reminder, background, coremotion]
date: 2026-03-28
category: plan
status: approved
---

# Fix: watchOS 스트레칭 알림 미작동

## Problem

워치에서 오래 앉아 있어도 스트레칭 알림이 발생하지 않음.

### Root Cause

1. **알림 권한 미요청**: `WatchPostureMonitor`가 `UNUserNotificationCenter.add(request)`로 로컬 알림을 발송하지만, watchOS에서 `requestAuthorization(options:)` 호출이 없음. 권한 없이 알림이 조용히 실패.

2. **백그라운드 타이머 미동작**: `sedentaryCheckTask`가 `Task.sleep(for: .seconds(60))` 기반 폴링으로 앉은 시간을 체크하지만, watchOS에서 앱이 백그라운드/중단 상태가 되면 Task가 실행되지 않음. 사용자가 앱 화면을 보고 있지 않으면 타이머가 작동하지 않아 알림이 절대 트리거되지 않음.

## Solution

### 핵심 전략 변경

**Before (폴링 기반)**: 매분 Task.sleep → `checkSedentaryDuration()` → 조건 충족 시 즉시 알림
**After (예약 기반)**: 정지 상태 진입 시 `UNTimeIntervalNotificationTrigger`로 미래 알림 예약 → 움직이면 취소

### Affected Files

| File | Change |
|------|--------|
| `DUNEWatch/Managers/WatchPostureMonitor.swift` | 알림 예약/취소 로직 추가, 권한 요청 추가 |
| `DUNEWatchTests/WatchPostureMonitorTests.swift` | 새 테스트: 예약/취소/권한 시나리오 |

### Implementation Steps

#### Step 1: 알림 권한 요청 추가

`setEnabled(true)` 호출 시 `UNUserNotificationCenter.requestAuthorization(options: [.alert, .sound])` 수행.
`startMonitoring()` 시작 전에도 권한 상태 확인하여 미허용이면 요청.

#### Step 2: 예약 기반 알림으로 전환

`handleActivityChange(.stationary)` 시:
1. 야간 시간/운동 중 체크 → 해당되면 예약하지 않음
2. `UNTimeIntervalNotificationTrigger(timeInterval: sedentaryThresholdMinutes * 60, repeats: false)` 생성
3. 고정 identifier로 `UNNotificationRequest` 추가 (이전 예약을 자동 대체)

`handleActivityChange(non-stationary)` 시:
1. 예약된 스트레칭 알림 취소: `UNUserNotificationCenter.removePendingNotificationRequests(withIdentifiers:)`

#### Step 3: 폴링 타이머 역할 축소

`sedentaryCheckTask`는 유지하되, 역할을 변경:
- **유지**: `sedentaryMinutesToday` 누적, 일일 리셋, 요약 동기화 (포그라운드 UI 업데이트용)
- **제거**: `checkSedentaryDuration()` → 알림 트리거 로직 (이제 OS 알림 시스템이 처리)
- `checkSedentaryDuration()` 내부에서는 카운터만 업데이트하고 `triggerStretchReminder()`는 호출하지 않음

#### Step 4: 알림 발송 후 재예약

알림이 실제로 전달된 후(사용자가 45분 앉은 후) → 다음 주기를 위해 재예약 필요.
방법: `UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:)` 활용하거나,
더 간단하게: `triggerStretchReminder()` 호출 시 `activityStateStartDate = Date()`를 리셋하고 즉시 다음 알림을 다시 예약.

하지만 WatchPostureMonitor 내에서는 이 delegate 활용이 복잡하므로, 대안으로:
- **repeating trigger 사용 금지** (triggerStretchReminder가 카운터/sync도 해야 하므로)
- 대신: `scheduleLocalNotification()` 시점에 즉시 다음 알림도 예약 (`timeInterval * 2, * 3` 등 3회분)
- 사용자가 움직이면 모두 취소

→ 더 단순한 접근: `repeats: false` + 알림 전달 시 delegate에서 재예약. 단, delegate가 복잡하면 **일단 1회 예약만 하고, 포그라운드 복귀 시 상태 재점검**하는 것이 watchOS에서 더 안정적.

**최종 결정**: 단일 non-repeating 예약 + 포그라운드 복귀 시 `periodicCheck()`에서 상태 재점검 + 재예약. 이유: 사용자가 45분 앉은 후 알림을 받으면 대부분 움직임 → 활동 변화 감지 → 재예약 사이클 자연 재시작.

### Test Strategy

1. **권한 미허용 시**: 알림 예약 시도 없이 로그만 기록
2. **정지 상태 진입**: 예약된 알림 identifier 확인
3. **비정지 상태 전환**: 예약된 알림 취소 확인
4. **야간 시간**: 예약 스킵 확인
5. **운동 중**: 예약 스킵 확인
6. **threshold 변경**: 기존 예약 갱신 확인

### Risk / Edge Cases

- **CMMotionActivityManager 백그라운드 전달**: watchOS에서 activity updates가 배치 전달될 수 있음. 정지 → 움직임 → 정지 전환이 한꺼번에 도착하면 최종 상태 기준으로 예약/취소 결정
- **Night hour 전환**: 22시 직전 예약된 알림이 22시 이후 전달될 수 있음 → 허용 (OS 레벨에서 방지 불가, 사용자 영향 미미)
- **알림 권한 거부**: 설정에서 활성화해도 알림이 안 옴 → 설정 UI에 권한 상태 표시 검토 (MVP 스코프 외)
