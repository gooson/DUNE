---
tags: [notification, body-composition, debounce, race-condition, healthkit-observer]
date: 2026-03-15
category: architecture
status: implemented
---

# 체성분 알림 3건 동시 발송 → 디바운스 패턴으로 단건 통합

## Problem

인바디 측정 후 HealthKit에 체중/체지방/BMI가 동시에 기록되면 `HKObserverQuery`가 3개 타입에 대해 거의 동시에 콜백을 발생시킨다. 기존 `bufferAndBuildMergedBody()` 메서드는 buffer에 값을 추가하고 **즉시** merged body를 반환하여 알림을 발송했기 때문에, 3개의 Task가 각각 독립적으로 알림을 보내 사용자에게 3건이 연속 표시되었다.

### 근본 원인

1. `evaluateAndNotify()`의 `canSend(for: type)` 체크는 타입별 throttle이므로 weight/bodyFat/BMI 모두 통과
2. `bufferAndBuildMergedBody()`가 buffer + 즉시 반환 → 각 Task가 독립적으로 발송
3. 동일한 `replacingIdentifier` 사용에도 불구하고 iOS가 밀리초 간격의 3건을 모두 배너로 표시

## Solution

**Buffer → Sleep → Claim** 디바운스 패턴:

1. `bufferBodyCompositionValue()` — 값만 buffer에 기록 (즉시 반환)
2. `Task.sleep(for: .seconds(debounce - 1))` — sibling 값이 도착할 시간 확보
3. `claimAndBuildMergedBody()` — 원자적으로 send slot 확보 + merged body 빌드

```
Task 1 (weight):    buffer → sleep 2s → claim ✓ → send(weight+bodyFat+BMI)
Task 2 (bodyFat):   buffer → sleep 2s → claim ✗ → return (debounce guard)
Task 3 (BMI):       buffer → sleep 2s → claim ✗ → return (debounce guard)
```

### 핵심 설계 결정

- **debounce window (3s)**: `bodyCompositionDebounceSeconds`로 configurable. `claimAndBuildMergedBody()`가 이 window 내 두 번째 호출을 거부
- **sleep duration**: `debounceSeconds - 1`로 자동 유도. sleep < debounce 보장
- **buffer clear**: claim 성공 후 buffer를 비워 stale 값이 다음 알림에 포함되지 않도록 방지
- **per-type throttle 기록**: claim 시 buffer 내 모든 body composition type의 일별 throttle을 기록하여, 같은 날 동일 타입 재발송 차단

### 변경 파일

- `NotificationThrottleStore.swift`: `bufferAndBuildMergedBody()` → `bufferBodyCompositionValue()` + `claimAndBuildMergedBody()`
- `BackgroundNotificationEvaluator.swift`: 2초 debounce sleep 추가
- `NotificationThrottleStoreTests.swift`: 5개 debounce 테스트 추가

## Prevention

- **동시 HKObserverQuery 콜백** 패턴이 새로 발생하면 buffer+debounce+claim 패턴을 적용
- buffer를 사용하는 경우 claim 후 반드시 clear하여 stale 방지
- sleep duration과 guard window의 관계를 config에서 유도하여 상수 drift 방지

## Lessons Learned

- `replacingIdentifier`로 iOS 알림 교체를 기대하면 안 됨 — 밀리초 간격 연속 발송 시 iOS가 모두 배너로 표시
- 기존 `bufferAndBuildMergedBody()` 원자성은 단일 호출 내에서만 보장 — 3개 병렬 호출 간 coordination이 누락된 것이 근본 원인
- Debounce guard의 window는 sleep보다 반드시 길어야 함 (sleep = debounce - 1)
