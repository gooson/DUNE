---
tags: [notification, delegate, main-thread, crash, async, UNUserNotificationCenterDelegate]
date: 2026-03-14
category: plan
status: draft
---

# Plan: Fix Notification Delegate Async Return Thread Crash

## Problem Statement

`AppNotificationCenterDelegate`의 `nonisolated func userNotificationCenter(_:didReceive:) async` 메서드가 `await forwardNotificationResponse(payload)` 이후 임의의 스레드에서 리턴한다. UIKit은 이 async delegate 메서드의 내부 completion handler를 리턴 시점의 스레드에서 호출하는데, 이 completion handler가 CA transaction synchronization을 수행하므로 main thread assertion이 발생한다.

### Crash Signature

```
NSInternalInconsistencyException: Call must be made on main thread
in -[SwiftUIApplication _performBlockAfterCATransactionCommitSynchronizes:]
```

## Root Cause

`UNUserNotificationCenterDelegate`의 async 버전은 메서드 리턴 시 내부적으로 completion handler를 호출한다. `nonisolated` 메서드에서 `await` 이후 Swift Concurrency가 임의 executor에서 continuation을 재개하므로, 리턴 시점에 main thread 보장이 없다.

## Solution

completion-handler 기반 delegate 메서드로 전환하여, completion handler 호출을 main thread에서 보장한다.

## Affected Files

| File | Change | Risk |
|------|--------|------|
| `DUNE/App/AppNotificationCenterDelegate.swift` | async delegate → completion-handler delegate | Low — 동일 로직, 스레드 보장만 변경 |
| `DUNETests/AppNotificationCenterDelegateTests.swift` | 테스트 업데이트 | Low |

## Implementation Steps

### Step 1: `didReceive` 메서드를 completion-handler 기반으로 전환

`nonisolated func userNotificationCenter(_:didReceive:) async` →
`func userNotificationCenter(_:didReceive:withCompletionHandler:)`

completion handler를 `DispatchQueue.main.async` 내에서 호출하여 main thread 보장.

### Step 2: `willPresent` 메서드를 completion-handler 기반으로 전환

`nonisolated func userNotificationCenter(_:willPresent:) async` →
`func userNotificationCenter(_:willPresent:withCompletionHandler:)`

이 메서드도 동일한 async 리턴 스레드 문제를 가지므로 함께 수정.

### Step 3: `forwardNotificationResponse` 리팩터

async가 아닌 동기 버전으로 변경. `DispatchQueue.main.async` 내에서 responseHandler를 호출하고 completionHandler도 함께 호출.

### Step 4: 테스트 업데이트

`AppNotificationCenterDelegateTests`에서 completion-handler 기반 동작 검증.

## Test Strategy

- 기존 `forwardNotificationResponseDeliversPayloadOnMainActor` 테스트를 새 시그니처에 맞게 업데이트
- completion handler가 main thread에서 호출되는지 검증

## Risks / Edge Cases

1. **async/completion handler 공존**: Swift는 async와 completion handler 버전이 동시에 존재하면 async를 우선한다. async 버전을 완전히 제거해야 한다.
2. **willPresent 리턴 값**: completion handler 버전에서는 presentation options를 직접 전달한다 — 동작 동일.
3. **forwardNotificationResponse 공개 API**: 테스트에서 사용 중이므로 시그니처 변경 시 테스트도 업데이트 필요.
