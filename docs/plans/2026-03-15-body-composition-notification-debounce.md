---
tags: [notification, body-composition, debounce, race-condition]
date: 2026-03-15
category: plan
status: draft
---

# 체성분 알림 3개 동시 발송 버그 수정

## Problem

인바디 측정 후 체중/체지방/BMI가 동시에 HealthKit에 기록되면, HKObserverQuery가 3개 타입에 대해 거의 동시에 콜백을 발생시킨다. 각 콜백이 독립적으로 `bufferAndBuildMergedBody()`를 호출하여 매번 알림을 발송하므로, 사용자에게 3개의 알림이 순차적으로 나타난다.

### Root Cause

1. `HealthKitObserverManager`가 bodyMass, bodyFatPercentage, bodyMassIndex 각각에 대해 별도 `HKObserverQuery`를 등록
2. 각 콜백이 독립적인 `Task`에서 `evaluateAndNotify(sampleType:)`을 호출
3. `canSend(for: type)`은 타입별 throttle이므로 3개 모두 통과
4. `bufferAndBuildMergedBody()`가 buffer에 값을 추가하고 **즉시** merged body를 반환 → 발송
5. Task 1: weight만 → 발송, Task 2: weight+bodyFat → 발송, Task 3: 전체 → 발송
6. 동일한 `replacingIdentifier`를 사용하지만 iOS가 연속 3개를 모두 배너로 표시

## Solution: Debounce Pattern

`bufferAndBuildMergedBody()`를 두 단계로 분리:

1. **Buffer** (즉시): 값을 buffer에 기록
2. **Claim & Send** (2초 지연 후): sibling 값이 모두 도착한 후 한 번만 발송

### Design

```
Task 1 (weight):    buffer → sleep 2s → claim ✓ → send(weight+bodyFat+BMI)
Task 2 (bodyFat):   buffer → sleep 2s → claim ✗ → return (already sent)
Task 3 (BMI):       buffer → sleep 2s → claim ✗ → return (already sent)
```

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Data/Persistence/NotificationThrottleStore.swift` | `bufferAndBuildMergedBody()` 분리 → `bufferBodyCompositionValue()` + `claimAndBuildMergedBody()` |
| `DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift` | `sendMergedBodyCompositionNotification()` 에 2초 debounce 추가 |
| `DUNETests/NotificationThrottleStoreTests.swift` | debounce 패턴 테스트 추가 |

## Implementation Steps

### Step 1: NotificationThrottleStore 메서드 분리

1. `bufferBodyCompositionValue(type:formattedValue:now:)` — buffer에 값 기록만
2. `claimAndBuildMergedBody(now:)` — 원자적으로 send slot 확보 + merged body 빌드
   - `bodyCompositionLastSent`가 debounce window(3초) 이내이면 `nil` 반환
   - 그 외: buffer에서 merge window 내 pending 수집, 일일 예산 확인, throttle 기록, merged body 반환
3. 기존 `bufferAndBuildMergedBody()` 제거

### Step 2: BackgroundNotificationEvaluator debounce 적용

`sendMergedBodyCompositionNotification()`을:
1. `bufferBodyCompositionValue()` 호출
2. `Task.sleep(for: .seconds(2))` 대기
3. `claimAndBuildMergedBody()` 호출
4. non-nil이면 알림 발송

### Step 3: 테스트 추가

- 연속 3개 buffer 후 claim → 첫 claim만 성공
- debounce window 이후 재 claim 가능
- merge window 내 모든 값이 merged body에 포함

## Test Strategy

- `NotificationThrottleStoreTests`에 debounce 시나리오 추가
- 기존 body composition 테스트가 새 API에 맞게 업데이트

## Risks & Edge Cases

1. **Task 취소**: background execution 30초 제한 내에 2초 sleep 완료 가능 (여유 충분)
2. **단일 체성분 값**: 체중만 변경된 경우에도 2초 대기 후 정상 발송
3. **하루 중 두 번째 InBody**: 5분 merge window 이후이면 새 알림 발송 가능
