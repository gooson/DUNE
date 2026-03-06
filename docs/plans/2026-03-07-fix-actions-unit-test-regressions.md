---
tags: [ci, unit-tests, template-workout, notification, widget]
date: 2026-03-07
category: plan
status: implemented
---

# Actions Unit Test Regression Fixes

## Problem Statement

GitHub Actions run `22770407480` failed in the iOS unit test job for three separate reasons:

1. `TemplateWorkoutViewModel` template prefill no longer overrode the generic starter reps created by `WorkoutSessionViewModel`.
2. Notification routing tests still assumed `handleNotificationResponse` returned `nil` for route-less payloads, even though notification hub fallback was added on 2026-03-04.
3. `WidgetScoreDataTests` still expected the legacy unscoped `UserDefaults` key after the bundle-prefixed key migration.

## Implementation Steps

1. Reproduce the CI failure locally and separate real code regression from stale test expectations.
2. Fix `TemplateWorkoutViewModel.prefillFromTemplateDefaults(weightUnit:)` so template defaults replace generic starter reps and only apply once per view model lifecycle.
3. Update notification routing tests to distinguish pure `parseRoute` validation from full notification response handling with notification hub fallback.
4. Update widget shared-data tests to match the current bundle-prefixed `UserDefaults` key.
5. Re-run the full `DUNETests` suite with the same simulator/runtime used by CI.

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Presentation/Exercise/TemplateWorkoutViewModel.swift` | Template prefill logic fix + idempotency guard |
| `DUNETests/TemplateWorkoutViewModelTests.swift` | Regression coverage for one-time prefill behavior |
| `DUNETests/NotificationExerciseDataTests.swift` | Route parsing vs notification hub fallback expectation cleanup |
| `DUNETests/WidgetScoreDataTests.swift` | Bundle-prefixed key expectation update |
