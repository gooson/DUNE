---
tags: [ui-test, xctest, ci, launch, terminate, flake, activity-smoke]
category: testing
date: 2026-03-09
severity: important
related_files:
  - DUNEUITests/Helpers/UITestBaseCase.swift
  - docs/plans/2026-03-09-ui-test-activity-smoke-launch-stability.md
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
  - docs/solutions/testing/2026-03-08-ui-smoke-toolbar-tap-stability.md
  - docs/solutions/testing/2026-03-09-e2e-phase4-wellness-regression.md
---

# Solution: UI test AUT launch lifecycle hardening

## Problem

GitHub Actions iOS UI smoke job에서 `ActivitySmokeTests`가 첫 launch 단계에서 불안정하게 실패했다.
실패 지점은 화면 assertion이 아니라 공통 base helper인 `UITestBaseCase.launchApp()` 내부였다.

### Symptoms

- job `22824264855`에서 `testActivityScrollRemainsResponsive`가 `UITestBaseCase.swift:102`의 `app.launch()`에서 멈춘 뒤 2분 allowance를 초과했다.
- 이어서 같은 class의 다음 테스트들은 `Failed to terminate com.raftel.dailve:26214` 또는 launch timeout으로 연쇄 실패했다.
- 같은 job 안에서 test runner가 restart된 뒤 동일 `ActivitySmokeTests`는 다시 통과했다.

### Root Cause

`UITestBaseCase`가 launch 전과 teardown에서 AUT state와 무관하게 항상 `app.terminate()`를 호출하고 있었다.
CI에서는 첫 AUT launch 이전 또는 이미 죽은 프로세스에 대한 terminate 호출이 불필요한 failure surface를 만들었고,
한 번 launch lifecycle이 꼬이면 다음 테스트들도 stale process/timeout 에러로 전염됐다.

## Solution

공통 UI test base에 "실행 중일 때만 종료" helper를 추가해 launch/teardown contract를 좁혔다.
즉, AUT가 실제로 `runningForeground`, `runningBackground`, `runningBackgroundSuspended` 상태일 때만 terminate + wait를 수행하도록 바꿨다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEUITests/Helpers/UITestBaseCase.swift` | `isApplicationRunning` / `terminateIfRunning` helper 추가 | non-running AUT에 대한 불필요한 terminate 호출을 막기 위해 |
| `DUNEUITests/Helpers/UITestBaseCase.swift` | `tearDownWithError()`를 conditional terminate로 변경 | crash/timeout 뒤 2차 teardown failure를 줄이기 위해 |
| `DUNEUITests/Helpers/UITestBaseCase.swift` | `launchApp()`의 pre-launch terminate를 guarded helper로 변경 | 첫 CI launch에서 `Terminate com.raftel.dailve:0`가 hang surface가 되지 않게 하기 위해 |
| `docs/plans/2026-03-09-ui-test-activity-smoke-launch-stability.md` | 구현 계획 기록 | 원인, 대안, 검증 전략을 남기기 위해 |

### Key Code

```swift
private func isApplicationRunning(_ application: XCUIApplication) -> Bool {
    switch application.state {
    case .runningForeground, .runningBackground, .runningBackgroundSuspended:
        return true
    default:
        return false
    }
}

@discardableResult
private func terminateIfRunning(_ application: XCUIApplication, timeout: TimeInterval = 5) -> Bool {
    guard isApplicationRunning(application) else { return true }
    application.terminate()
    return application.wait(for: .notRunning, timeout: timeout)
}
```

## Prevention

UI test harness에서는 "lingering AUT 정리"와 "이미 죽은 앱에 대한 불필요한 lifecycle 호출"을 구분해야 한다.
특히 base case helper는 실패한 테스트 이후에도 항상 실행되므로, state check 없이 terminate를 던지면 실제 원인과 무관한 2차 에러를 만들기 쉽다.

### Checklist Addition

- [ ] `XCUIApplication.terminate()` 호출 전 AUT state가 실제 running 상태인지 확인하는가?
- [ ] teardown helper가 crash/timeout 뒤에도 새 failure를 만들지 않는가?
- [ ] CI log에서 첫 failure와 후속 failure가 같은 lifecycle helper에서 연쇄되는지 확인했는가?
- [ ] launch hang 이슈를 assertion 회귀로 오판하지 않고 base harness부터 분리했는가?

### Rule Addition (if applicable)

새 rules 파일 추가는 하지 않았다.
같은 패턴이 `LaunchScreenTests`나 snapshot/manual UI test base에도 반복되면 공통 rule 또는 helper 승격을 검토한다.

## Lessons Learned

UI smoke red는 반드시 화면 기능 회귀를 의미하지 않는다.
이번 케이스처럼 첫 launch lifecycle이 한 번 꼬이면 같은 class의 후속 테스트가 연쇄적으로 실패하고, runner restart 후에는 다시 통과할 수 있다.
따라서 flaky CI는 개별 smoke assertion을 손보기 전에 base harness의 launch/terminate contract부터 확인하는 편이 훨씬 빠르다.
