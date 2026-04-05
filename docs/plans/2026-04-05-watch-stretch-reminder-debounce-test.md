---
tags: [watchos, notification, posture, stretch-reminder, debounce, testing]
date: 2026-04-05
category: plan
status: approved
---

# Fix: watchOS 스트레칭 알림 디바운스 + 1분 테스트 지원

## Problem

워치 자세 알림이 1시간 앉아있어도 발동하지 않음. 2026-03-28 수정으로 `UNTimeIntervalNotificationTrigger` 기반 예약으로 전환했으나, CMMotionActivityManager의 잦은 상태 변경(wrist 미세 움직임 → walking/unknown 감지)이 예약 알림을 반복 취소+재예약하여 카운트다운이 계속 리셋됨.

### Root Cause

1. **Activity state flickering**: CMMotionActivityManager가 보고하는 활동 상태에 debounce 없이 즉시 반응. 손목 미세 움직임이 `walking`/`unknown`으로 감지되면 `cancelScheduledStretchNotifications()` 호출 → `stationary` 복귀 시 `scheduleStretchNotifications()` 재호출 → 타이머 리셋.
2. **Confidence 미확인**: `CMMotionActivity.confidence`를 확인하지 않아 `.low` confidence 활동에도 반응.
3. **테스트 불가**: 최소 threshold 15분, UI는 30분부터. 1분 테스트 불가.

## Solution

### 핵심 전략

1. **Debounce**: 비정지 상태가 감지되면 즉시 취소하지 않고, 10초간 유지되는지 확인 후 취소
2. **Confidence 필터**: `.low` confidence 활동은 무시
3. **테스트 모드**: `#if DEBUG`에서 최소 1분까지 threshold 설정 가능

### Affected Files

| File | Change |
|------|--------|
| `DUNEWatch/Managers/WatchPostureMonitor.swift` | Debounce 로직 추가, confidence 필터, threshold 최소값 조정 |
| `DUNEWatch/Views/PostureMonitorSettingsView.swift` | DEBUG 빌드에서 1분 옵션 추가 |
| `DUNEWatchTests/WatchPostureMonitorTests.swift` | Debounce 및 confidence 필터 테스트 추가 |

### Implementation Steps

#### Step 1: CMMotionActivity confidence 필터 추가

`mapActivity()`에서 `.low` confidence를 무시하고 이전 상태 유지:
```swift
nonisolated private static func mapActivity(_ activity: CMMotionActivity) -> PostureActivityState? {
    guard activity.confidence != .low else { return nil }
    // ... existing mapping
}
```

`handleActivityChange`에서 nil이면 무시.

#### Step 2: 비정지 상태 전환에 debounce 추가

`handleActivityChange`에서 stationary → non-stationary 전환 시:
- 즉시 알림 취소하지 않고 `pendingCancelTask`에 10초 지연 후 취소 스케줄
- 10초 내에 다시 stationary가 감지되면 `pendingCancelTask` 취소 (알림 유지)
- Stationary → Stationary는 무시 (중복 예약 방지)

#### Step 3: threshold 최소값을 DEBUG에서 1분으로 조정

```swift
#if DEBUG
private static let minimumThresholdMinutes = 1
#else
private static let minimumThresholdMinutes = 15
#endif
```

#### Step 4: 설정 UI에 DEBUG 모드 테스트 옵션 추가

`PostureMonitorSettingsView`에서 `#if DEBUG`일 때 thresholdOptions에 1분, 5분 추가.

#### Step 5: handleActivityChange를 테스트 가능하게 변경

`private` → `internal` (within package)로 변경하여 테스트에서 직접 호출 가능.

### Test Strategy

1. **Confidence 필터 테스트**: `.low` confidence 활동이 상태를 변경하지 않는지 확인
2. **Debounce 테스트**: 비정지 상태가 10초 미만이면 알림이 취소되지 않는지 확인
3. **1분 threshold 테스트**: DEBUG 빌드에서 1분 threshold가 허용되는지 확인
4. **실기기 테스트**: Watch에서 1분 threshold로 설정 후 알림 수신 확인

### Risk / Edge Cases

| Case | Handling |
|------|----------|
| 실제로 일어나서 걸을 때 debounce 지연 | 10초 지연은 사용자 경험에 무의미 (어차피 이미 알림 받은 후) |
| Debounce 중 앱 suspend | pendingCancelTask는 포그라운드 전용; 알림은 OS가 관리하므로 안전 |
| DEBUG 1분 threshold 프로덕션 유출 | `#if DEBUG`로 컴파일 시점 격리 |
