# Siri health query SwiftUI delta review

Reviewed `9ae252af...cab56cc6` on 2026-10-30, including the affected view model, result card, snippet, record detail, formatting helper, and smoke tests. Static review only; no build, tests, simulator, or current native PNG review was performed here.

## Prior findings

- **Record detail unlock recovery: resolved in code.** The unlock notification increments `reloadRevision`, which restarts the guarded `.task`; both service awaits now recheck cancellation and protected-data availability before assigning records.
- **Calculated Siri source: resolved.** The snippet maps `.app`, `.healthKit`, and `.calculated` explicitly.
- **Narrow metric rows: resolved in code.** Result-card secondary metrics and Siri snippet metrics now use `ViewThatFits` with a vertical layout. The hero value scales and has a vertical unit fallback. Native layout remains unverified.
- **Back navigation requery: resolved in code.** `cancel()` preserves a loaded answer and `HealthQueryView.task` skips reloading it on return.

## New findings

No confirmed P1, P2, or P3 finding in the reviewed delta.

## Verification boundary

The 62 unit tests reported at `3999e507` precede later condition-ring/date/UI changes. The first four UI tests failed on the parent accessibility identifier; moving `health-query-result` to the period text addresses that cause in code, but the retry timed out waiting for the repository simulator lock before tests started. Current native screenshots and the large-text layout test remain unverified. A successful targeted UI run and fresh PNG inspection are needed before claiming visual approval.
