---
tags: [foundation-models, ane, error-handling, retry, logging, apple-neural-engine]
date: 2026-03-29
category: general
status: implemented
related_files:
  - DUNE/App/AppLogger.swift
  - DUNE/Data/Services/AICoachingMessageService.swift
  - DUNE/Data/Services/FoundationModelReportFormatter.swift
  - DUNE/Data/Services/HealthDataQAService.swift
  - DUNE/Data/Services/AIWorkoutTemplateGenerator.swift
related_solutions:
  - docs/solutions/architecture/2026-03-09-foundation-models-integration-pattern.md
  - docs/solutions/general/2026-03-09-natural-language-workout-template-failure-debugging.md
---

# Solution: Foundation Models ANE Inference Error Handling

## Problem

Apple Neural Engine (ANE) inference errors surface as `ModelManagerError` that can't be converted to `TokenGenerationError`:

```
InferenceError::inferenceFailed::Error Domain=com.apple.TokenGenerationInference.E5Runner Code=0
"Failed to run inference: ANE inference operation failed...
  Error Domain=com.apple.appleneuralengine Code=8
  statusType=0x8: Program Inference error"
```

### Symptoms

- Foundation Models calls fail silently — generic `catch` blocks return fallback with no logging
- No way to distinguish ANE hardware failures from model guardrails/rate limits in production logs
- Transient ANE errors (thermal throttling, hardware busy) aren't retried

### Root Cause

All 4 Foundation Model services (`AICoachingMessageService`, `FoundationModelReportFormatter`, `HealthDataQAService`, `AIWorkoutTemplateGenerator`) used bare `catch` blocks with no diagnostic output. The ANE error is caught and handled gracefully (no crash), but developers couldn't identify the failure class without Xcode console filtering.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `AppLogger.swift` | Added `static let ai` logger category | Dedicated Foundation Models logging channel |
| `AICoachingMessageService.swift` | Added `AppLogger.ai.error()` in catch block | Diagnostic logging for coaching enhancement failures |
| `FoundationModelReportFormatter.swift` | Added `AppLogger.ai.error()` in catch block | Diagnostic logging for report formatting failures |
| `HealthDataQAService.swift` | Extracted `performInference()`, added single retry with 1s delay | Retry transient ANE errors; DRY extraction for reuse |
| `AIWorkoutTemplateGenerator.swift` | Added retry with fresh session before falling to deterministic builder | Retry transient ANE errors with new session (original session may be in bad state) |

### Error Logging Pattern

```swift
} catch {
    AppLogger.ai.error(
        "[ServiceName] inference failed: \(String(describing: error), privacy: .private)"
    )
    return fallback
}
```

All error details use `.private` privacy mask to prevent health-related content from leaking to shared device logs.

### Retry Pattern

```swift
do {
    return try await performInference(...)
} catch {
    AppLogger.ai.notice("[Service] retrying after transient failure: ...")
    try? await Task.sleep(for: .seconds(1))
    guard !Task.isCancelled else { return fallback }
    do {
        return try await performInference(...)
    } catch {
        AppLogger.ai.error("[Service] inference failed after retry: ...")
        return fallback
    }
}
```

Key decisions:
- **Single retry only** — avoids doubling latency on persistent failures
- **1s fixed delay** — simple, no exponential backoff needed for single retry
- **Task cancellation check** — prevents zombie retries when view has been dismissed
- **Fresh session on retry** (AIWorkoutTemplateGenerator) — original session may retain failed state
- **No retry for coaching/report** — fire-and-forget with template fallbacks; retry would delay UI for low-value enhancement

## Prevention

| Risk | Pattern |
|------|---------|
| Silent Foundation Models failures | Always log to `AppLogger.ai` in catch blocks with `.private` privacy |
| Transient ANE errors | Single retry with `Task.isCancelled` guard for interactive services |
| Error without context | Use `[ServiceName]` prefix and include error description in log |
| Privacy leak in logs | `.private` mask on all error interpolations |

## Lessons Learned

- ANE errors are thrown as generic `Error` (not `LanguageModelSession.GenerationError`), so they land in the untyped `catch` block. The typed `GenerationError` cases (`.guardrailViolation`, `.rateLimited`, etc.) are already handled separately.
- `LanguageModelSession` is lightweight to recreate — per-call session creation is the recommended pattern. A fresh session on retry is safe.
- The `ModelManagerError` wrapping `InferenceError` is an internal Apple framework type — we can't pattern-match on it, only log and retry.
