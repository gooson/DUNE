---
tags: [swift6, concurrency, watchos, oslog, warning-cleanup]
category: general
date: 2026-03-02
severity: minor
related_files:
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNEWatch/WatchConnectivityManager.swift
related_solutions:
  - docs/solutions/general/2026-02-16-swift6-healthkit-build-fixes.md
---

# Solution: Replace `nonisolated(unsafe)` with `nonisolated` for Watch Loggers

## Problem

watchOS 코드에서 `@MainActor` 클래스의 `Logger` 상수에 `nonisolated(unsafe)`가 선언되어 Swift 6 컴파일러 경고가 발생했다.

### Symptoms

- `WorkoutManager.swift`에서 "`nonisolated(unsafe)` is unnecessary for a constant with Sendable type `Logger`" 경고 발생
- `WatchConnectivityManager.swift`에서 동일 경고 발생

### Root Cause

`Logger`는 Sendable 타입이므로 `unsafe`는 불필요했다. 다만 두 클래스는 `nonisolated` delegate 메서드에서 `Self.logger`를 호출하므로 `nonisolated` 자체는 유지되어야 했다.

## Solution

경고가 난 두 선언을 `nonisolated(unsafe)`에서 `nonisolated`로 축소했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/Managers/WorkoutManager.swift` | logger 선언을 `nonisolated(unsafe)` → `nonisolated`로 변경 | 컴파일러 권고 반영, delegate nonisolated 접근 유지 |
| `DUNEWatch/WatchConnectivityManager.swift` | logger 선언을 `nonisolated(unsafe)` → `nonisolated`로 변경 | 동일 |

### Key Code

```swift
// Before
nonisolated(unsafe) private static let logger = Logger(...)

// After
nonisolated private static let logger = Logger(...)
```

## Prevention

concurrency 경고가 발생하면 `unsafe` 키워드 추가보다 먼저 타입의 Sendable 여부와 호출 맥락(nonisolated delegate 접근 여부)을 함께 확인한다.

### Checklist Addition

- [ ] `nonisolated(unsafe)` 사용 전 "Sendable + immutable constant" 여부를 점검한다.
- [ ] `nonisolated`를 제거하기 전 nonisolated 함수/delegate에서 static 멤버를 참조하는지 확인한다.

### Rule Addition (if applicable)

현재 규칙 추가까지는 필요하지 않다. 동일 패턴이 반복되면 `healthkit-patterns` 또는 concurrency 관련 규칙에 승격을 검토한다.

## Lessons Learned

Swift 6 경고 처리 시 `unsafe` 제거와 actor 접근 가능성 검증은 함께 진행되어야 한다. 경고 문구만 보고 어노테이션을 전부 제거하면 컴파일 에러로 이어질 수 있다.
