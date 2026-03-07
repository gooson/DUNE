---
tags: [swift-6, mainactor, nonisolated, ui-test, launch-arguments, app-startup]
category: architecture
date: 2026-03-08
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNEWatchTests/CardioInactivityPolicyTests.swift
  - docs/plans/2026-03-08-launch-argument-mainactor-isolation-fix.md
related_solutions:
  - docs/solutions/architecture/watch-settings-sync-pattern.md
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
---

# Solution: Launch Argument MainActor Isolation Fix

## Problem

UI test launch argument를 읽는 `DUNEApp` static helper가 Swift 6 actor isolation 규칙에 의해 main actor-isolated로 해석되면서, synchronous nonisolated launch configuration 경로에서 컴파일 에러가 발생했다.

### Symptoms

- `Call to main actor-isolated static method 'launchArgumentValue(for:)' in a synchronous nonisolated context` 빌드 에러 발생
- `--ui-scenario`, `--ui-test-theme`, `--ui-test-style` parsing이 들어 있는 `DUNE/App/DUNEApp.swift` 가 컴파일되지 않음
- 검증 과정에서 watch unit test 한 파일이 `Date` 사용에도 `Foundation` import가 없어 전체 `scripts/test-unit.sh` 완료가 막힘

### Root Cause

`DUNEApp` 내부의 `launchArgumentValue(for:)` 는 `ProcessInfo.processInfo.arguments` 만 읽는 순수 helper지만, Swift 6에서는 enclosing context의 actor isolation 영향을 받아 main actor-isolated static method처럼 취급될 수 있다.
이 helper를 nonisolated synchronous context에서 호출하면서 compile-time isolation 충돌이 드러났다.

## Solution

순수 launch argument helper를 `nonisolated` 로 명시해 actor hop 없이 사용할 수 있게 하고, 검증 중 발견된 watch test import 누락을 함께 보정했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/DUNEApp.swift` | `launchArgumentValue(for:)` 를 `nonisolated` 로 변경 | 순수 static helper를 nonisolated launch configuration 경로에서 안전하게 호출하기 위해 |
| `DUNEWatchTests/CardioInactivityPolicyTests.swift` | `import Foundation` 추가 | `Date` 심볼을 사용하는 watch test가 전체 unit test runner를 막지 않도록 하기 위해 |
| `docs/plans/2026-03-08-launch-argument-mainactor-isolation-fix.md` | 구현 계획 기록 | run pipeline의 plan 증빙과 리스크를 남기기 위해 |

### Key Code

```swift
nonisolated private static func launchArgumentValue(for key: String) -> String? {
    let arguments = ProcessInfo.processInfo.arguments
    guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else {
        return nil
    }
    return arguments[index + 1]
}
```

## Prevention

`@MainActor` 또는 actor 영향권에 있는 타입 안에서 순수 static helper를 만들 때는, actor-isolated 상태를 읽지 않는다면 `nonisolated` 여부를 먼저 검토한다.
반대로 actor-isolated singleton이나 mutable state를 읽는 helper라면 `nonisolated` 로 내리지 말고, call site에서 필요한 값을 파라미터로 전달해야 한다.

### Checklist Addition

- [ ] `@MainActor` 타입 내부의 static helper가 순수 함수라면 `nonisolated` 명시가 필요한지 검토한다
- [ ] static helper가 actor-isolated 상태를 직접 읽지 않는지 확인한다
- [ ] build 검증 후 프로젝트 전체 test runner가 unrelated import 누락으로 막히지 않는지 함께 확인한다

### Rule Addition (if applicable)

추가 규칙 파일은 필요하지 않았다.
기존 `watch-settings-sync-pattern.md` 와 이번 solution 문서 조합으로 동일 패턴을 다시 찾을 수 있다.

## Lessons Learned

Swift 6 strict concurrency에서는 \"단순 static helper\" 라는 직관만으로 isolation을 판단하면 안 된다.
특히 앱 시작 경로나 test launch configuration처럼 synchronous parsing이 필요한 지점에서는, 순수 helper를 명시적으로 `nonisolated` 로 선언하는 편이 가장 작은 수정으로 문제를 해결한다.
