---
tags: [mac, cloudkit, refresh, throttle, flickering, performance]
date: 2026-03-21
category: plan
status: approved
---

# Mac CloudKit Refresh Storm Fix

## Problem

맥앱의 Activity 탭(및 모든 탭)이 계속 깜빡이며 무한 리프레시됨.

### Root Cause: Feedback Loop

```
NSPersistentStoreRemoteChange
  → requestRefresh(source: .cloudKitRemoteChange)  [bypasses throttle]
  → invalidateCache + yield refreshNeededStream
  → ContentView refreshSignal++ → VMs reload
  → VMs call ScoreRefreshService.recordSnapshot()
  → context.save() → SwiftData write → CloudKit sync
  → NSPersistentStoreRemoteChange  ← LOOP
```

핵심 원인: `cloudKitRemoteChange`가 throttle을 **완전히 bypass**하므로 (commit 8f1503f3),
매 CloudKit notification마다 즉시 full refresh가 실행되고, 그 refresh가 SwiftData에
snapshot을 write → CloudKit sync → 다시 notification → 무한 반복.

### 증거

로그에서 동일한 데이터(`steps: 16215, exerciseToday: 153.0min`)가 반복 로드되며,
매 사이클마다 `[ScoreRefreshService] Saved hourly snapshot` 이 실행됨.

## Solution

`cloudKitRemoteChange`에 **전용 짧은 throttle** (5초)을 적용.

### 설계 근거

- 60초 일반 throttle은 Mac에서 너무 느림 (iPhone 데이터 도착 후 최대 1분 대기)
- 0초 (현재, bypass) 는 feedback loop 유발
- **5초**: 연속 notification을 병합하면서 사용자 체감 지연은 무시 가능
- CloudKit batch sync 특성상 여러 notification이 1-2초 내에 몰려옴 → 5초면 한 번만 처리

### 변경 파일

| 파일 | 변경 |
|------|------|
| `DUNE/Data/Services/AppRefreshCoordinatorImpl.swift` | `cloudKitRemoteChange` 전용 throttle 추가 (5초) |
| `DUNETests/AppRefreshCoordinatorTests.swift` | 새 throttle 동작 테스트 추가/수정 |

### 구현 방법

`AppRefreshCoordinatorImpl`에 `lastCloudKitRefreshDate` 별도 추적:

```swift
private var lastCloudKitRefreshDate: Date
private let cloudKitThrottleInterval: TimeInterval = 5

func requestRefresh(source: RefreshSource) async -> Bool {
    let now = nowProvider()

    if source == .cloudKitRemoteChange {
        let cloudKitElapsed = now.timeIntervalSince(lastCloudKitRefreshDate)
        guard cloudKitElapsed >= cloudKitThrottleInterval else {
            // Throttled — too soon since last CloudKit refresh
            return false
        }
        lastCloudKitRefreshDate = now
    } else {
        let elapsed = now.timeIntervalSince(lastRefreshDate)
        guard elapsed >= throttleInterval else {
            return false
        }
    }

    lastRefreshDate = now
    await sharedHealthDataService.invalidateCache()
    continuation.yield(source)
    return true
}
```

## Implementation Steps

### Step 1: Modify AppRefreshCoordinatorImpl
- `lastCloudKitRefreshDate` private 프로퍼티 추가
- `cloudKitThrottleInterval` 상수 추가 (기본 5초)
- `requestRefresh` 메서드에서 `cloudKitRemoteChange`를 전용 throttle로 전환
- init에서 `cloudKitThrottleInterval` 파라미터 추가 (테스트용)

### Step 2: Update Tests
- 기존 `cloudKitRemoteChangeBypassesThrottle` → 전용 throttle 동작으로 변경
- 새 테스트: CloudKit rapid-fire가 throttle되는지 확인
- 새 테스트: CloudKit throttle 후 일반 소스는 여전히 일반 throttle 적용 확인

## Test Strategy

- 기존 테스트 중 bypass 동작을 기대하는 2개 수정
- 새 시나리오 3개 추가:
  1. CloudKit rapid requests within 5s → 첫 번째만 통과
  2. CloudKit after 5s → 통과
  3. CloudKit + foreground 교차 throttle 독립성

## Risks & Edge Cases

- **Risk**: Mac에서 5초 내에 실제 다른 데이터가 도착할 경우 → 5초 후 다음 notification에서 처리됨. 실질적 데이터 손실 없음 (snapshot은 동일 hour에 upsert)
- **Edge**: 앱 시작 직후 첫 CloudKit notification → `lastCloudKitRefreshDate`를 init에서 `.distantPast`로 설정하면 첫 요청은 항상 통과
