---
tags: [foundation-models, ane, error-handling, retry, logging]
date: 2026-03-29
category: plan
status: draft
---

# Plan: Foundation Models ANE Inference Error Handling

## Problem Statement

Apple Neural Engine (ANE) inference errors surface as `ModelManagerError` that can't be converted to `TokenGenerationError`:

```
InferenceError::inferenceFailed::Error Domain=com.apple.TokenGenerationInference.E5Runner Code=0
"Failed to run inference: ANE inference operation failed..."
```

The 4 Foundation Model services catch all errors via generic `catch` blocks but provide:
- No diagnostic logging to classify ANE vs. guardrail vs. rate-limit failures
- No retry for transient ANE errors (thermal throttling, hardware busy)
- No dedicated logger category for Foundation Models operations

## Affected Files

| File | Change |
|------|--------|
| `DUNE/App/AppLogger.swift` | Add `ai` logger category |
| `DUNE/Data/Services/AICoachingMessageService.swift` | Add error classification logging |
| `DUNE/Data/Services/FoundationModelReportFormatter.swift` | Add error classification logging |
| `DUNE/Data/Services/HealthDataQAService.swift` | Add error classification logging + retry |
| `DUNE/Data/Services/AIWorkoutTemplateGenerator.swift` | Add error classification logging + retry |
| `DUNETests/AICoachingMessageServiceTests.swift` | Add test for error logging path |

## Implementation Steps

### Step 1: Add AppLogger.ai category

Add `static let ai = Logger(subsystem: "com.raftel.dailve", category: "AI")` to `AppLogger`.

### Step 2: Add error classification logging to each Foundation Models service

In each service's `catch` block, add structured logging that identifies the error type:

```swift
} catch {
    AppLogger.ai.error(
        "[ServiceName] inference failed: \(String(describing: error), privacy: .private)"
    )
    return fallback
}
```

Key: use `.private` privacy for error details (may contain user prompt context).

### Step 3: Add single retry with backoff for AIWorkoutTemplateGenerator

The ANE error can be transient (hardware busy, thermal). Add a single retry with 1-second delay before falling to the deterministic builder:

```swift
// In the outer do/catch of generateTemplate()
catch {
    // First attempt failed — retry once for transient ANE errors
    AppLogger.ai.notice("[AIWorkoutTemplate] retrying after transient failure")
    try? await Task.sleep(for: .seconds(1))
    guard !Task.isCancelled else { throw WorkoutTemplateGenerationError.generationFailed }
    // Second attempt...
}
```

### Step 4: Add retry to HealthDataQAService

Similar single-retry pattern. The QA service is conversational, so a brief delay is acceptable.

### Step 5: Keep AICoachingMessageService and FoundationModelReportFormatter without retry

These are fire-and-forget with existing template fallbacks. Adding retry would delay UI for low-value enhancement. Logging only.

### Step 6: Update existing tests

- Verify that test mocks still work with the new logging
- Existing tests already mock `availabilityProvider` — no changes needed for the retry path since retries only happen with real Foundation Models

## Test Strategy

- **AICoachingMessageService**: Existing tests already cover error fallback path. No new tests needed — the only change is adding a log statement.
- **AIWorkoutTemplateGenerator**: Existing tests cover error → fallback → generationFailed path. The retry is internal to the real Foundation Models call path and won't be triggered by mocks.
- **Unit test safety**: Run existing test suite to confirm no regressions.

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| Retry doubles latency on persistent ANE failures | Single retry with 1s cap; no exponential backoff |
| Task cancellation during retry delay | `guard !Task.isCancelled` check after sleep |
| Privacy leak in error logs | `.private` privacy mask on all error details |
| Retry on non-transient errors (guardrail, rate limit) | Acceptable — single retry is cheap, and `LanguageModelSession.GenerationError` typed errors are already caught separately in AIWorkoutTemplateGenerator |
