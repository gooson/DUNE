---
tags: [ci, unit-tests, template-workout, notification, widget]
date: 2026-03-07
category: testing
status: implemented
related_files:
  - DUNE/Presentation/Exercise/TemplateWorkoutViewModel.swift
  - DUNETests/TemplateWorkoutViewModelTests.swift
  - DUNETests/NotificationExerciseDataTests.swift
  - DUNETests/WidgetScoreDataTests.swift
---

# Actions Unit Test Regression Fixes

## Problem

GitHub Actions iOS unit tests failed after three unrelated changes drifted out of alignment:

- Template workout defaults stopped replacing the generic starter reps that `WorkoutSessionViewModel` injects on initialization.
- Notification tests were still forcing `notificationItemID` into malformed payloads, which now routes through `.notificationHub` fallback instead of the pure `parseRoute` path.
- Widget shared-data tests still expected the legacy `widget_score_data` key after the bundle-prefixed migration.

## Solution

### Fix 1: Make template prefill override starter reps exactly once

`TemplateWorkoutViewModel.prefillFromTemplateDefaults(weightUnit:)` now:

- guards with `didPrefillTemplateDefaults` so repeated `onAppear` calls do not overwrite edited values
- replaces the generic starter reps/weights with template defaults during the first prefill pass

This restores the intended template behavior while keeping later user edits intact.

### Fix 2: Split notification route parsing from notification response fallback

`NotificationExerciseDataTests` now:

- removes `notificationItemID` when validating `parseRoute` semantics directly
- verifies that real route-less notification taps open `.notificationHub`

This matches the current production behavior introduced by the cold-start notification routing fix.

### Fix 3: Update widget key assertion to the current scoped key

`WidgetScoreDataTests` now expects `com.raftel.dailve.widget_score_data`, matching the shared model used by the app and widget extension.

## Prevention

- Template defaults must override generic starter reps when those reps are only bootstrap values, and that prefill must be idempotent.
- Notification tests should omit `notificationItemID` when validating pure route decoding, because `handleNotificationResponse` applies higher-level fallback behavior when an item ID is present.
- Constant assertions should be updated alongside any bundle/app-group namespacing change to avoid stale CI failures.

## Verification

```bash
xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -derivedDataPath .deriveddata \
  -only-testing DUNETests \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

Result: `1313 tests in 148 suites passed`.
