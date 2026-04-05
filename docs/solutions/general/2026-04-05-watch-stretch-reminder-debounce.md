---
tags: [watchos, notification, coremotion, debounce, CMMotionActivityManager, stretch-reminder, confidence-filtering]
date: 2026-04-05
category: general
status: implemented
---

# watchOS 스트레칭 알림 상태 플리커링 수정

## Problem

워치 자세 알림이 1시간 앉아있어도 발동하지 않음.

2026-03-28 수정으로 `UNTimeIntervalNotificationTrigger` 기반 예약으로 전환했으나 여전히 미작동. CMMotionActivityManager가 손목 미세 움직임을 `.walking`/`.unknown`으로 잠깐 감지한 뒤 다시 `.stationary`로 돌아오는 "플리커링" 현상이 알림 예약을 반복 취소+재예약하여 카운트다운이 계속 리셋됨.

### 근본 원인 2가지 (이전 수정 후 잔존)

1. **Activity state flickering**: `handleActivityChange`가 모든 상태 변경에 즉시 반응. 비정지 상태가 1초만 유지되어도 `cancelScheduledStretchNotifications()` → `stationary` 복귀 시 `scheduleStretchNotifications()` → 타이머 리셋.
2. **CMMotionActivity.confidence 미확인**: `.low` confidence 활동에도 반응하여 불필요한 상태 전환 발생.

## Solution

### 1. 비정지 상태 전환에 10초 debounce

```swift
private func debouncedCancelStretchNotifications() {
    pendingCancelTask?.cancel()
    pendingCancelTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(Constants.activityDebounceSeconds))
        guard !Task.isCancelled, let self else { return }
        self.cancelScheduledStretchNotifications()
    }
}
```

- 비정지 상태 감지 시 즉시 취소하지 않고 10초 대기
- 10초 내 `stationary` 복귀 시 `pendingCancelTask?.cancel()` → 알림 유지
- 실제로 걸어나간 경우 10초 후 정상 취소

### 2. Low confidence 필터링

```swift
nonisolated private static func mapActivity(_ activity: CMMotionActivity) -> PostureActivityState? {
    guard activity.confidence != .low else { return nil }
    // ... mapping
}
```

### 3. 중복 상태 무시

```swift
func handleActivityChange(_ newState: PostureActivityState) {
    guard newState != previousState else { return }
    // ...
}
```

### 4. DEBUG 1분 테스트 모드

```swift
#if DEBUG
static let minimumThresholdMinutes = 1
#else
static let minimumThresholdMinutes = 15
#endif
```

Watch 설정 UI에서도 `#if DEBUG`로 1분/5분 옵션 노출.

## Prevention

### CMMotionActivityManager 상태 전환 처리 체크리스트

1. **Confidence 필터링 필수**: `.low` confidence 활동은 무시 (센서 노이즈)
2. **비정지→정지 전환은 즉시 처리** (알림 예약), **정지→비정지는 debounce** (플리커 방어)
3. **중복 상태 변경 무시**: `guard newState != previousState`
4. **watchOS Task.sleep debounce는 포그라운드 전용**: 백그라운드 동작은 OS 알림에 위임

### watchOS 알림 3계층 패턴

| 계층 | 역할 | 수명 |
|------|------|------|
| `UNTimeIntervalNotificationTrigger` | 실제 알림 전달 | 앱 상태 무관 (OS 관리) |
| `debouncedCancelStretchNotifications()` | 플리커 방어 | 포그라운드 전용 |
| `sedentaryCheckTask` | UI 카운터 업데이트 | 포그라운드 전용 |

## Lessons Learned

1. **`UNTimeIntervalNotificationTrigger`만으로는 부족**: OS가 알림을 전달해도, 알림 취소 로직이 과민하면 전달 전에 취소됨
2. **CMMotionActivityManager는 noisy**: 손목 착용 기기에서 stationary↔walking 플리커는 일상적. Debounce 없이 직접 반응하면 안 됨
3. **테스트 인프라는 개발 초기에 확보**: 45분 알림을 실기기에서 검증하기 어려움 → DEBUG 1분 모드를 처음부터 제공했어야 함
