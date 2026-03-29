---
tags: [gpu, image-slot, bgtask, cloudkit, scroll-anchor, swiftui, info-plist]
date: 2026-03-29
category: general
status: implemented
related_files:
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Wellness/WellnessView.swift
  - DUNE/Presentation/Life/LifeView.swift
  - DUNE/Resources/Info.plist
---

# Solution: Image Slot 1320x0 Error & BGTask Scheduling Failure

## Problem

1. **`Failed to create 1320x0 image slot`**: GPU 0-height texture allocation failure from scroll anchors using `Color.clear.frame(height: 0)`. Width 1320 = device width at 3x scale.
2. **`BGSystemTaskSchedulerErrorDomain Code=3`**: CoreData CloudKit background task scheduling failure due to missing Info.plist configuration.

### Root Cause

- **Image slot**: SwiftUI proposes full device width to `Color.clear.frame(height: 0)`, causing GPU to attempt 1320x0 texture allocation which fails with IOSurface error
- **BGTask**: Info.plist missing `processing` background mode and `BGTaskSchedulerPermittedIdentifiers` for CoreData CloudKit internal tasks

## Solution

### Fix 1: Scroll Anchor — `frame(width: 0, height: 0)`

```swift
// Before: GPU tries to allocate 1320x0 texture
Color.clear.frame(height: 0).id(ScrollAnchor.top)

// After: 0x0 → renderer skips allocation entirely
Color.clear.frame(width: 0, height: 0).id(ScrollAnchor.top)
```

Applied in 4 tab root views: DashboardView, ActivityView, WellnessView, LifeView.

### Fix 2: Info.plist — BGTask identifiers + processing mode

Added `BGTaskSchedulerPermittedIdentifiers` with CoreData CloudKit standard identifiers:
- `com.apple.coredata.cloudkit.activity.export`
- `com.apple.coredata.cloudkit.activity.import`

Added `processing` to `UIBackgroundModes` alongside existing `remote-notification`.

## Prevention

- Scroll anchors: always use `frame(width: 0, height: 0)` — never `frame(height: 0)` alone
- CloudKit sync apps: include CoreData CloudKit task identifiers in Info.plist boilerplate
- `Color.clear` is NOT automatically optimized away by SwiftUI renderer — it can still trigger GPU allocations
