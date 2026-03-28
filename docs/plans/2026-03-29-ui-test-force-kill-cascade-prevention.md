---
tags: [ui-test, ci, terminate, force-kill, cascade, flake]
date: 2026-03-29
category: plan
status: approved
---

# Plan: UI Test Force-Kill & Cascade Prevention

## Problem

GitHub Actions nightly UI test job `68942453786` (run `23664358470`) failed with cascading
terminate/launch failures in `ActivityExercisePickerRegressionTests` and `ActivityExerciseRegressionTests`.

### Failure Sequence

1. `testFullPickerSupportsFilterSelectorsAndSelectionFromTemplateForm` ran 304s (max allowance 300s), app hung
2. `tearDownWithError()` called `terminateIfRunning()` → `terminate()` failed on stuck app
3. XCTest recorded failure at `UITestBaseCase.swift:82` (`application.terminate()`)
4. Next test `testQuickStartPickerCanRevealAllExercisesAndOpenDetail` → launch timed out (line 117)
5. All subsequent tests cascaded with same launch/terminate failures

### Root Cause

`terminateIfRunning()` has no fallback when `XCUIApplication.terminate()` fails on a hung app.
The 5s wait timeout expires, but the stuck process remains alive. Additionally, `tearDownWithError()`
doesn't suppress terminate failures, so one stuck test poisons the entire test class.

### Prior Art

- `2026-03-09-ui-test-aut-launch-lifecycle-hardening.md`: Fixed non-running AUT terminate calls
- `2026-03-22-quick-start-picker-presentation-contract.md`: Fixed picker presentation races
- Both solved specific trigger causes but didn't address the generic "stuck app won't terminate" scenario

## Affected Files

| File | Change |
|------|--------|
| `DUNEUITests/Helpers/UITestBaseCase.swift` | Add force-kill fallback, suppress tearDown cascade |

## Implementation Steps

### Step 1: Add `forceTerminateAppProcess()` helper

Add a private method that uses `posix_spawn` to run `xcrun simctl terminate booted <bundleID>`.
Foundation `Process` is unavailable in the iOS Simulator SDK, so `posix_spawn` is used instead.

Bundle ID: `com.raftel.dailve` (matches `test-ui.sh` `BUNDLE_ID` variable).

### Step 2: Harden `terminateIfRunning()`

- Increase default timeout from 5s to 10s
- After `terminate()` + `wait(for:)` timeout, call `forceTerminateAppProcess()`
- Wait another 5s after force-kill

### Step 3: Suppress terminate failures in `tearDownWithError()`

- Set `continueAfterFailure = true` before calling `terminateIfRunning`
- Restore original value after
- This prevents a single stuck test from recording extra failures that cascade

### Step 4: Harden `launchApp()` pre-launch cleanup

- If `terminateIfRunning()` returns false, call `forceTerminateAppProcess()` + wait
- Only then proceed to `app.launch()`

## Test Strategy

- Build verification: `scripts/build-ios.sh`
- The fix is in test infrastructure, not app code — no unit tests needed
- Verify by checking that the test runner compiles and the harness changes are correct
- Real verification happens in the next CI nightly run

## Risks / Edge Cases

- `posix_spawn` in XCUITest: Foundation `Process` is unavailable in iOS Simulator SDK; `posix_spawn` works because it's a POSIX API bridged through Darwin
- `xcrun simctl terminate booted` may fail if no simulator is booted — harmless, already guarded
- Race between `terminate()` and `forceTerminateAppProcess()`: force-kill on an already-dead process is a no-op
- `continueAfterFailure = true` in tearDown: only applies to the terminate call, restored immediately after
