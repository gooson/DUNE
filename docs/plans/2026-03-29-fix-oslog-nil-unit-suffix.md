---
tags: [logging, oslog, formatting, nil-safety]
date: 2026-03-29
category: plan
status: draft
---

# Fix OSLog nil + unit suffix formatting

## Problem

`SharedHealthDataService` snapshot log produces `exerciseToday: nilmin` and potentially `nilkg` when Optional values are nil. The unit suffix (`min`, `kg`) is placed **outside** the OSLog string interpolation, so it always appends regardless of the value.

```
[SharedHealthDataService] Snapshot built — steps: 304, exerciseToday: nilmin, ...
```

## Root Cause

```swift
exerciseToday: \(exerciseToday.map { String(format: "%.1f", $0) } ?? "nil", privacy: .public)min
//                                                                                           ^^^
// "min" is a literal suffix OUTSIDE the interpolation — appended even when value is "nil"
```

## Affected Files

| File | Lines | Issue |
|------|-------|-------|
| `DUNE/Data/Services/SharedHealthDataServiceImpl.swift` | 261-263 | `exerciseToday`, `exerciseRecent` (`min`), `weight` (`kg`) |
| `DUNE/Data/Services/CloudMirroredSharedHealthDataService.swift` | 70-72 | Same three fields |

## Solution

Move unit suffix inside the `String(format:)` call within the `.map` closure, so nil values produce `"nil"` without a dangling unit:

```swift
// Before:
\(exerciseToday.map { String(format: "%.1f", $0) } ?? "nil", privacy: .public)min

// After:
\(exerciseToday.map { String(format: "%.1fmin", $0) } ?? "nil", privacy: .public)
```

Apply same pattern to `exerciseRecent` (min) and `weight` (kg).

## Implementation Steps

1. Fix `SharedHealthDataServiceImpl.swift` lines 261-263
2. Fix `CloudMirroredSharedHealthDataService.swift` lines 70-72
3. Build verification

## Test Strategy

- No unit test needed (log formatting only, no behavior change)
- Verify via build pass
- Visual verification: run app and check log output

## Risks / Edge Cases

- None — pure log formatting change, no runtime behavior affected
- No localization impact (log strings are developer-facing, not user-facing)
