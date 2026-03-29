---
tags: [oslog, logging, nil-safety, string-format, optional]
date: 2026-03-29
category: general
status: implemented
---

# OSLog nil + Unit Suffix Formatting Bug

## Problem

`SharedHealthDataService` snapshot log produced `exerciseToday: nilmin` and `weight: nilkg` when Optional values were nil. The unit suffix was placed **outside** the OSLog string interpolation, causing it to always append regardless of the value.

**Symptom**: `[SharedHealthDataService] Snapshot built — steps: 304, exerciseToday: nilmin, ...`

**Root cause**: Unit literals (`min`, `kg`) placed after the closing `)` of the `\(..., privacy: .public)` interpolation.

## Solution

Move unit suffix inside the `String(format:)` call within the `.map` closure:

```swift
// Before (broken):
\(value.map { String(format: "%.1f", $0) } ?? "nil", privacy: .public)min

// After (fixed):
\(value.map { String(format: "%.1fmin", $0) } ?? "nil", privacy: .public)
```

**Files changed**:
- `DUNE/Data/Services/SharedHealthDataServiceImpl.swift` (lines 261-263)
- `DUNE/Data/Services/CloudMirroredSharedHealthDataService.swift` (lines 70-72)

## Prevention

When writing OSLog messages with Optional values and unit suffixes:
- Always include the unit inside the `String(format:)` specifier, not after the interpolation
- Pattern: `\(optional.map { String(format: "%.1f{unit}", $0) } ?? "nil", privacy: .public)`
- This ensures nil values produce clean `"nil"` without dangling unit text

## Lessons Learned

- OSLog's `privacy:` parameter syntax makes the interpolation boundary less visually obvious
- Unit suffixes placed outside interpolation are easy to miss in code review since the non-nil case looks correct
