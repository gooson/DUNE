---
tags: [foundation-models, debounce, cancel-storm, ane, task-management, swiftdata-sync]
date: 2026-03-30
category: performance
status: implemented
related_files:
  - DUNE/Presentation/Activity/ActivityViewModel.swift
  - DUNE/Data/Services/FoundationModelReportFormatter.swift
related_solutions:
  - docs/solutions/general/2026-03-29-foundation-models-ane-error-handling.md
---

# Solution: Foundation Models Cancel/Restart Storm Prevention

## Problem

Repeated `[ReportFormatter] inference failed: CancellationError()` and ANE hardware errors (`ANEProgramProcessRequestDirect() Failed with status=0x15`) when SwiftData sync fires rapidly.

### Symptoms

- Console flooded with `CancellationError` and ANE inference failure logs
- `Failed to create 1320x0 image slot` errors (Foundation Models framework cleanup failure)
- Each CloudKit sync burst produces 4-6 error entries

### Root Cause

`generateWeeklyReport()` was called from two `.task(id:)` modifiers in `ActivityView`:

1. `.task(id: refreshSignal)` — user-initiated refresh
2. `.task(id: recordsUpdateKey)` — SwiftData sync (CloudKit changes)

SwiftUI's `.task(id:)` cancels the previous task when the id changes. During CloudKit sync bursts, `recordsUpdateKey` changes multiple times in rapid succession, creating a cancel/restart storm:

```
trigger 1 → start inference → cancelled by trigger 2
trigger 2 → start inference → cancelled by trigger 3
trigger 3 → start inference → cancelled by trigger 4
trigger 4 → start inference → completes (or also cancelled)
```

Each cancelled inference produced CancellationError + ANE cleanup errors.

The `weeklyReportRequestID` staleness check prevented stale results from being applied, but did NOT prevent the inference from starting.

## Solution

Added a 500ms debounce delay in `generateWeeklyReport()` before starting data processing and Foundation Models inference:

```swift
func generateWeeklyReport(
    debounceNanoseconds: UInt64 = Scheduling.reportDebounceNanoseconds // 500ms
) async {
    weeklyReportRequestID += 1
    let requestID = weeklyReportRequestID

    if debounceNanoseconds > 0 {
        do {
            try await Task.sleep(nanoseconds: debounceNanoseconds)
        } catch {
            return  // Task cancelled during debounce — newer trigger supersedes
        }
    }
    guard !Task.isCancelled, requestID == weeklyReportRequestID else { return }

    // ... data preparation and inference
}
```

This follows the existing `refreshSuggestionFromRecords()` debounce pattern (180ms) in the same ViewModel.

### Key Design Decisions

- **500ms debounce** (vs 180ms for suggestions): Foundation Models inference is heavier (~1-3s) and produces more visible errors when cancelled, so a wider coalescing window is appropriate
- **Test bypass via parameter**: Tests pass `debounceNanoseconds: 0` for immediate execution
- **No retry added**: The prior solution (2026-03-29) already handles transient ANE errors with retry in interactive services. For ReportFormatter, the debounce eliminates the root cause of repeated failures

## Prevention

| Risk | Pattern |
|------|---------|
| Foundation Models called from `.task(id:)` | Always debounce before inference to absorb SwiftData sync churn |
| Heavy async work in SwiftUI task | Check if the trigger can fire rapidly — if yes, add debounce |
| Cancel/restart storm pattern | Comment on `.task(id:)` that calls expensive async: `// Debounce: coalesces rapid triggers` |

## Lessons Learned

- `weeklyReportRequestID` staleness checks prevent stale results but don't prevent wasted work — debounce prevents the work from starting
- ANE errors (`ANEProgramProcessRequestDirect`, `Failed to create image slot`) are symptoms of mid-flight cancellation, not independent hardware failures
- The existing code comment "SwiftData sync churn should update derived UI state without cancel/restart storms" (line 444) was a TODO that needed to be applied to `generateWeeklyReport()` too, not just `loadActivityData`
