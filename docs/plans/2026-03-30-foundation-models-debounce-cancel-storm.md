---
tags: [foundation-models, debounce, cancel-storm, ane, performance]
date: 2026-03-30
category: plan
status: draft
---

# Plan: Foundation Models Cancel/Restart Storm Prevention

## Problem Statement

`generateWeeklyReport()` in `ActivityViewModel` invokes Foundation Models (on-device AI) for workout report formatting. It is called from two `.task(id:)` modifiers in `ActivityView`:

1. `.task(id: refreshSignal)` — user-initiated refresh
2. `.task(id: recordsUpdateKey)` — SwiftData sync churn

When CloudKit syncs records rapidly, `recordsUpdateKey` changes multiple times in quick succession. Each change cancels the previous `.task(id:)` and starts a new one, creating a cancel/restart storm:

- Each cancelled inference → `CancellationError` logged
- Mid-flight ANE cancellation → `ANEProgramProcessRequestDirect() Failed with status=0x15`
- Framework cleanup failure → `Failed to create 1320x0 image slot`

The code comment at line 444 explicitly warns about this: "SwiftData sync churn should update derived UI state without cancel/restart storms."

## Root Cause

`generateWeeklyReport()` starts Foundation Models inference immediately without debounce. The `weeklyReportRequestID` staleness check (line 473) correctly discards stale results but does NOT prevent the inference from starting.

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Presentation/Activity/ActivityViewModel.swift` | Add debounce delay in `generateWeeklyReport()` |
| `DUNETests/ActivityViewModelTests.swift` | Update tests for debounced behavior |

## Implementation Steps

### Step 1: Add debounce to `generateWeeklyReport()`

Add a `reportDebounceNanoseconds` constant to `Scheduling` enum and a `Task.sleep` + cancellation guard before the data processing and inference call:

```swift
private enum Scheduling {
    static let suggestionDebounceNanoseconds: UInt64 = 180_000_000
    static let reportDebounceNanoseconds: UInt64 = 500_000_000  // 500ms
    // ...
}

func generateWeeklyReport() async {
    weeklyReportRequestID += 1
    let requestID = weeklyReportRequestID

    // Debounce: coalesce rapid SwiftData sync triggers before starting
    // Foundation Models inference (prevents ANE cancel/restart storms).
    do {
        try await Task.sleep(nanoseconds: Scheduling.reportDebounceNanoseconds)
    } catch {
        return  // Task cancelled during debounce — newer trigger supersedes
    }
    guard !Task.isCancelled, requestID == weeklyReportRequestID else { return }

    // ... existing data preparation and inference call
}
```

### Step 2: Add debounce bypass parameter for tests

```swift
func generateWeeklyReport(
    debounceNanoseconds: UInt64 = Scheduling.reportDebounceNanoseconds
) async {
    // ...
    if debounceNanoseconds > 0 {
        do {
            try await Task.sleep(nanoseconds: debounceNanoseconds)
        } catch { return }
    }
    guard !Task.isCancelled, requestID == weeklyReportRequestID else { return }
    // ...
}
```

Tests call `generateWeeklyReport(debounceNanoseconds: 0)` for instant execution.

### Step 3: Update test call sites

Update existing `ActivityViewModelTests` to pass `debounceNanoseconds: 0`.

## Test Strategy

- Existing `ActivityViewModelTests` already cover the report generation logic
- Update test call sites to use `debounceNanoseconds: 0` bypass
- No new tests needed — the debounce is a timing mechanism that's not feasible to unit test

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| Report appears 500ms later on first load | Acceptable — report card has empty state, and 500ms is imperceptible after full data load |
| Test flakiness from timing | `debounceNanoseconds: 0` parameter bypasses debounce entirely in tests |
| Multiple rapid user refreshes | `weeklyReportRequestID` staleness check already handles this — debounce adds additional protection |
