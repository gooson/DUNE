---
tags: [observation, feedback-loop, swiftui, environment, @Observable, NavigationStack, layout-invalidation, weatherAtmosphere]
date: 2026-03-29
category: performance
status: implemented
severity: critical
related_files:
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
related_solutions:
  - docs/solutions/performance/2026-02-16-computed-property-caching-pattern.md
  - docs/solutions/architecture/2026-02-28-weather-display-integration.md
---

# Solution: @Observable Environment Feedback Loop in NavigationStack

## Problem

### Symptoms

- `UIObservationTrackingFeedbackLoopDetected` warning/crash on app launch
- Console: "Object receiving repeated [layout] invalidations: NavigationStackHostingController"
- Continuous layout invalidation cycle in the Today tab

### Root Cause

`DashboardView` read an `@Observable` ViewModel property directly in `.environment()`:

```swift
.environment(\.weatherAtmosphere, viewModel.weatherAtmosphere)
```

The `.environment()` modifier propagates to the **entire NavigationStack subtree**. When `loadData()` modified `weatherAtmosphere` (first resetting to `.default`, then setting the fetched value), it triggered:

1. Environment value changes → all children invalidated
2. NavigationStack re-layouts children
3. DashboardView body re-evaluates → re-reads `viewModel.weatherAtmosphere`
4. Step 3 happens during step 2's layout → **feedback loop**

### Why `.environment()` is uniquely dangerous

Regular `@Observable` reads in body (e.g., `Text(viewModel.title)`) only invalidate the current view. But `.environment()` propagates down the entire subtree. When a NavigationStack is the parent, modifying the environment value during its layout cycle creates a re-entrant invalidation that SwiftUI detects as a feedback loop.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DashboardView.swift` | Added `@State private var cachedWeatherAtmosphere: WeatherAtmosphere = .default` | Decouple environment from observation tracking |
| `DashboardView.swift` | `.environment(\.weatherAtmosphere, cachedWeatherAtmosphere)` | Read from @State (no observation tracking) |
| `DashboardView.swift` | `.onChange(of: viewModel.weatherAtmosphere) { cachedWeatherAtmosphere = $1 }` | Sync cache on next render pass |

### Key Code

```swift
// Before: direct @Observable read in .environment() — FEEDBACK LOOP
.environment(\.weatherAtmosphere, viewModel.weatherAtmosphere)

// After: @State cache breaks the observation tracking during layout
@State private var cachedWeatherAtmosphere: WeatherAtmosphere = .default

.environment(\.weatherAtmosphere, cachedWeatherAtmosphere)
.onChange(of: viewModel.weatherAtmosphere) { _, newValue in
    cachedWeatherAtmosphere = newValue
}
```

### Why This Works

`@State` changes are coalesced to the next render pass. So when `loadData()` modifies `viewModel.weatherAtmosphere`:
1. `.onChange` fires and sets `cachedWeatherAtmosphere`
2. But the environment update is deferred to the next layout pass
3. The NavigationStack completes its current layout without re-entrancy
4. On the next pass, the environment updates cleanly

## Prevention

### Rule: Never read @Observable properties directly in `.environment()`

When passing `@Observable` values through `.environment()`, always cache in `@State` first:

```swift
// BAD: observation tracking during environment propagation
.environment(\.myKey, viewModel.myProperty)

// GOOD: @State cache breaks the tracking cycle
@State private var cachedValue = MyDefault.value
.environment(\.myKey, cachedValue)
.onChange(of: viewModel.myProperty) { _, new in cachedValue = new }
```

This pattern is only needed for `.environment()`. Regular body reads (`Text(viewModel.title)`) don't need caching because they don't propagate to child views.

## Lessons Learned

1. `.environment()` has subtree-wide propagation — treat it differently from regular property reads
2. `@Observable` + `.environment()` + async mutation = guaranteed feedback loop potential
3. The `@State` cache + `.onChange` pattern is the standard SwiftUI fix for this class of issue
4. Initial `@State` default must match the ViewModel's initial value to avoid flash of wrong state
