---
tags: [watchconnectivity, transferUserInfo, bulk-sync, queue-buildup, throttle, dedup]
date: 2026-03-30
category: architecture
status: implemented
---

# WatchConnectivity Bulk Sync Queue Buildup

## Problem

### 증상
Watch 로그에서 `[BulkSync] Sent 3 workouts to iPhone`이 7회 반복 출력. 동일한 운동 데이터가 7번 중복 전송됨.

### 근본 원인
iPhone `WatchSessionManager.requestWorkoutBulkSync()`가 앱 실행마다 호출(`DUNEApp.swift`). Watch 미연결 시 `transferUserInfo`로 폴백하는데, `transferUserInfo`는 **영구 큐**로 동작하여 전달될 때까지 축적됨.

iPhone 7회 재실행 → 큐에 7건 적재 → Watch 활성화 시 7건 모두 전달 → 동일 벌크 싱크 7회 실행.

### 핵심 인사이트
`transferUserInfo`는 "보장된 전달"이 목적이므로, 멱등하지 않은 요청(bulk sync request)에 사용하면 큐 축적으로 중복 처리가 발생한다.

## Solution

### 1. iPhone: `transferUserInfo` 폴백 제거 (근본 원인 제거)

**파일**: `DUNE/Data/WatchConnectivity/WatchSessionManager.swift`

Bulk sync는 실시간 요청 패턴이므로 `sendMessage` only. 미연결 시에는 `pendingBulkSyncSince` 플래그에 저장하고, `sessionReachabilityDidChange`에서 재시도.

```swift
@discardableResult
func requestWorkoutBulkSync(since: Date = ...) -> Bool {
    guard session.activationState == .activated else { return false }
    guard session.isReachable else {
        pendingBulkSyncSince = since  // defer, don't queue
        return false
    }
    pendingBulkSyncSince = nil
    session.sendMessage(message, ...)
    return true
}

// Retry on reachability change
func sessionReachabilityDidChange(_ session: WCSession) {
    if session.isReachable, let since = pendingBulkSyncSince {
        requestWorkoutBulkSync(since: since)
    }
}
```

### 2. Watch: 60초 throttle (방어적 중복 제거)

**파일**: `DUNEWatch/WatchConnectivityManager.swift`

`handleBulkSyncRequest`에 throttle 추가. throttle 타임스탬프는 실제 전송 성공 후에만 설정 (guard 실패 시 소진 방지).

```swift
private static let bulkSyncThrottleInterval: TimeInterval = 60
private var lastBulkSyncProcessedAt: Date?

private func handleBulkSyncRequest(since: Date) async {
    let now = Date()
    if let last = lastBulkSyncProcessedAt,
       now.timeIntervalSince(last) < Self.bulkSyncThrottleInterval {
        return  // throttled
    }
    guard let container = registeredModelContainer else { return }
    // ... fetch and send ...
    lastBulkSyncProcessedAt = now  // only after success
}
```

## Prevention

### WatchConnectivity 메시지 전달 패턴 선택 기준

| 패턴 | 특성 | 적합한 용도 |
|------|------|------------|
| `sendMessage` | 즉시 전달, 미연결 시 실패 | 실시간 요청, 상태 동기화 |
| `transferUserInfo` | 영구 큐, 보장된 전달 | 데이터 전송 (운동 완료, 세트 기록) |
| `updateApplicationContext` | 최신값 덮어쓰기 | 설정, 라이브러리 동기화 |

**규칙**: "요청" 성격의 메시지에는 `transferUserInfo` 사용 금지. 요청은 멱등하지 않으므로 큐 축적 시 중복 처리 발생.

### Throttle 타임스탬프 배치 원칙

Throttle state는 **성공 경로 마지막에** 설정. guard 실패나 에러 경로에서 설정하면, 실패했는데 재시도가 차단되는 문제 발생.

## Lessons Learned

1. `transferUserInfo`는 "fire-and-forget 데이터"용이지 "요청"용이 아니다. 요청 패턴에는 `sendMessage` + reachability 기반 재시도가 적합
2. Throttle state를 guard 전에 설정하면 실패 시에도 throttle이 소진됨 — 항상 성공 경로 이후에 설정
3. 양쪽(송신/수신) 모두에서 방어해야 함: 송신 측 큐잉 제거 + 수신 측 throttle
