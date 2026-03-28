---
tags: [ui-test, xctest, ci, terminate, force-kill, cascade, posix-spawn, flake]
category: testing
date: 2026-03-29
severity: important
related_files:
  - DUNEUITests/Helpers/UITestBaseCase.swift
  - scripts/test-ui.sh
related_solutions:
  - docs/solutions/testing/2026-03-09-ui-test-aut-launch-lifecycle-hardening.md
  - docs/solutions/testing/2026-03-22-quick-start-picker-presentation-contract.md
---

# Solution: UI Test Force-Kill & Cascade Prevention

## Problem

GitHub Actions nightly UI test job `68942453786` (run `23664358470`) failed with cascading
terminate/launch failures across `ActivityExercisePickerRegressionTests` and `ActivityExerciseRegressionTests`.

### Symptoms

- `testFullPickerSupportsFilterSelectorsAndSelectionFromTemplateForm` hung for 304s, then `terminate()` failed on the stuck app
- `Failed to terminate com.raftel.dailve:25501` recorded at `UITestBaseCase.swift:82`
- Next test `testQuickStartPickerCanRevealAllExercisesAndOpenDetail` → `Failed to launch ... Timed out while launching application via Xcode`
- 4 more tests cascaded with the same launch/terminate failures

### Root Cause

`terminateIfRunning()` had no fallback when `XCUIApplication.terminate()` fails on a hung app.
The 5s wait timeout expired, but the stuck process remained alive. Additionally, `tearDownWithError()`
didn't suppress terminate failures, so one stuck test poisoned the entire test class.

This is the third iteration of AUT lifecycle hardening:
1. **March 9**: Fixed non-running AUT terminate calls (state guard)
2. **March 22**: Fixed picker presentation races (app-level fix)
3. **March 29 (this)**: Generic force-kill fallback for stuck apps (infrastructure fix)

## Solution

Three changes to `UITestBaseCase.swift`:

### 1. Force-kill via `posix_spawn` + `xcrun simctl terminate`

When `terminate()` + `wait(for:)` times out, `forceTerminateAppProcess()` runs
`xcrun simctl terminate booted com.raftel.dailve` as a subprocess.

`posix_spawn` is used because Foundation `Process` is unavailable in the iOS Simulator SDK.
The return value is checked before calling `waitpid` to avoid blocking on an invalid PID.

### 2. Suppress terminate failures in `tearDownWithError()`

`continueAfterFailure` is temporarily set to `true` during the terminate call.
This prevents a single stuck test from recording extra failures that cascade
into launch-timeout failures for all subsequent tests in the class.

### 3. Increased timeout from 5s to 10s

The default timeout for `terminateIfRunning()` was increased from 5s to 10s,
giving CI environments more time for graceful termination before falling back to force-kill.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEUITests/Helpers/UITestBaseCase.swift` | Added `forceTerminateAppProcess()` using `posix_spawn` | Force-kill stuck AUT when `terminate()` fails |
| `DUNEUITests/Helpers/UITestBaseCase.swift` | `tearDownWithError()` suppresses terminate failures | Prevent cascade from one stuck test to all subsequent tests |
| `DUNEUITests/Helpers/UITestBaseCase.swift` | `terminateIfRunning()` timeout 5s → 10s + force-kill fallback | More resilient termination lifecycle |

### Key Code

```swift
@discardableResult
private func terminateIfRunning(_ application: XCUIApplication, timeout: TimeInterval = 10) -> Bool {
    guard isApplicationRunning(application) else { return true }
    application.terminate()
    if application.wait(for: .notRunning, timeout: timeout) {
        return true
    }
    Self.forceTerminateAppProcess()
    return application.wait(for: .notRunning, timeout: 5)
}

private static func forceTerminateAppProcess() {
    var pid = pid_t()
    var args: [UnsafeMutablePointer<CChar>?] = [
        strdup("/usr/bin/xcrun"), strdup("simctl"), strdup("terminate"),
        strdup("booted"), strdup(appBundleID), nil
    ]
    defer { for arg in args where arg != nil { free(arg) } }
    guard posix_spawn(&pid, "/usr/bin/xcrun", nil, nil, &args, nil) == 0 else { return }
    var status: Int32 = 0
    waitpid(pid, &status, 0)
}
```

## Prevention

### Checklist

- [ ] `terminateIfRunning()` includes a force-kill fallback path
- [ ] `tearDownWithError()` suppresses terminate failures with `continueAfterFailure = true`
- [ ] `posix_spawn` return value is checked before `waitpid`
- [ ] Bundle ID in `UITestBaseCase.appBundleID` matches `test-ui.sh BUNDLE_ID`

### Design Principle

UI test harness terminate lifecycle has three layers:
1. **State guard**: Only terminate if app is actually running (`isApplicationRunning`)
2. **Graceful terminate**: `XCUIApplication.terminate()` + configurable wait
3. **Force-kill fallback**: `xcrun simctl terminate` via `posix_spawn` when graceful fails
4. **Cascade prevention**: `continueAfterFailure = true` in tearDown to isolate failures

## Lessons Learned

- `Foundation.Process` is unavailable when compiling for iOS Simulator SDK. Use `posix_spawn` (Darwin POSIX API) instead.
- CI cascading failures from stuck apps are infrastructure issues, not test-level bugs. Fix the harness, not individual tests.
- A single stuck test can poison an entire test class/run if tearDown records failures and the next test can't launch.
