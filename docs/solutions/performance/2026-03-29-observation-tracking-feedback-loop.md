---
tags: [observation, feedback-loop, swiftui, environment, @Observable, NavigationStack, layout-invalidation, weatherAtmosphere]
date: 2026-03-29
category: performance
status: implemented
severity: critical
related_files:
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Wellness/WellnessView.swift
  - DUNE/Presentation/Life/LifeView.swift
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

## Second Instance: Cross-Observable Sparkline Read-Through

### Problem

After the weatherAtmosphere fix, the feedback loop persisted when entering Settings. Root cause: `DashboardViewModel.conditionSparkline` was a computed property that read through to `ScoreRefreshService.conditionSparkline` (a different `@Observable`):

```swift
// FEEDBACK LOOP: cross-observable read-through
var conditionSparkline: HourlySparklineData {
    scoreRefreshService?.conditionSparkline ?? .empty
}
```

SwiftUI observation tracked `ScoreRefreshService.conditionSparkline` through the computed property. When `ScoreRefreshService` updated the sparkline (from refresh stream or `recordSnapshot()` → `scheduleSparklineReload()`), it directly invalidated DashboardView, bypassing the `@State` ViewModel coalescing.

### Fix

Convert to stored property with explicit sync:

```swift
// SAFE: stored property, no cross-observable chain
private(set) var conditionSparkline: HourlySparklineData = .empty

private func syncSparklines() {
    conditionSparkline = scoreRefreshService?.conditionSparkline ?? .empty
}
```

Called at end of `loadData()`. Sparkline may be slightly behind `ScoreRefreshService` between refreshes — acceptable for hourly sparkline data.

## Third Instance: Preference→@State→Body Cascade During Navigation Push

### Problem

After fixes 1–2 and removal of the `sectionVisibilityHash` animation, the feedback loop recurred when entering Settings. Root cause: `@State heroFrame` updated via `.onPreferenceChange(TabHeroFramePreferenceKey.self)` created a continuous invalidation cycle during NavigationStack push animations.

The cycle:
1. NavigationStack push animation starts → content slides
2. Hero card frame changes in coordinate space → `GeometryReader` reports new frame
3. `.onPreferenceChange` fires → `heroFrame = newFrame` (writes to `@State`)
4. `@State` mutation → DashboardView body re-evaluates → reads ~20 `@Observable` ViewModel properties
5. If any ViewModel property changed from in-flight async work (enhanceCoachingTask, sparkline reload), observation triggers another invalidation
6. NavigationStack receives repeated [layout] invalidations → feedback loop

This pattern existed in ALL 4 tab root views (Dashboard, Activity, Wellness, Life) but manifested most severely in DashboardView due to its ~20 `@Observable` property reads amplifying the cascade.

### Fix

Replace the three-step pattern with `.backgroundPreferenceValue`:

```swift
// BEFORE: preference → @State → body re-eval → layout → preference (LOOP)
@State private var heroFrame: CGRect?
// ...
.onPreferenceChange(TabHeroFramePreferenceKey.self) { heroFrame = $0 }
.background {
    TabWaveBackground()
        .environment(\.tabHeroStartLineInset, heroFrame.map(TabHeroStartLine.inset(for:)))
}

// AFTER: preference read stays in background closure — no body re-eval
.backgroundPreferenceValue(TabHeroFramePreferenceKey.self) { heroFrame in
    TabWaveBackground()
        .environment(\.tabHeroStartLineInset, heroFrame.map(TabHeroStartLine.inset(for:)))
}
```

`backgroundPreferenceValue` reads the preference directly in the background view builder. When the preference changes, **only the background closure re-evaluates** — the parent view's body does NOT re-evaluate. No `@State` intermediate means no body invalidation.

Applied to all 4 tab root views: DashboardView, ActivityView, WellnessView, LifeView.

Also removed the dead `sectionVisibilityHash` computed property (23 lines) which had ~17 unnecessary `@Observable` reads per body evaluation.

## Fourth Instance: Async-Mutated Properties Read Directly in Body

### Problem

After instances 1–3, the feedback loop recurred after adding SectionGroup wrappers (PR #760) to DashboardView. The deeper view hierarchy (SectionGroup computes 3 gradients per instance) increased body evaluation cost, pushing latent observation tracking of async-mutated properties past SwiftUI's feedback loop detection threshold.

The volatile properties:
- `focusInsight` — mutated by `enhanceCoachingTask` (async)
- `coachingMessage` — mutated by same task
- `weatherSnapshot` — mutated by weather fetch
- `weatherCardInsight` — computed property reading `focusInsight` (cross-property observation chain)

All four were read directly in DashboardView body for the TodayBriefCard visibility check and props.

### Fix

1. Convert `weatherCardInsight` from computed to stored property with `syncWeatherCardInsight()` at stable points
2. Cache all 4 volatile properties in `@State` with `.onChange` sync in DashboardView
3. Extract cache-sync `.onChange` handlers into `DashboardCacheSync` ViewModifier to help the type-checker with the long modifier chain
4. Remove dead `standaloneCoachingInsight` computed property

### Key Insight

**View hierarchy depth amplifies latent feedback loops.** Adding visual wrappers (SectionGroup) around existing content doesn't add new observation tracking, but increases body evaluation cost enough to trigger SwiftUI's feedback loop detector when combined with existing volatile observation subscriptions.

## Lessons Learned

1. `.environment()` has subtree-wide propagation — treat it differently from regular property reads
2. `@Observable` + `.environment()` + async mutation = guaranteed feedback loop potential
3. The `@State` cache + `.onChange` pattern is the standard SwiftUI fix for `.environment()` cases
4. Initial `@State` default must match the ViewModel's initial value to avoid flash of wrong state
5. **Cross-observable computed read-throughs** also create feedback loops: when ViewModel A's computed property reads from `@Observable` B, SwiftUI tracks both. Updates to B invalidate the View even though A's `@State` wrapping should coalesce them
6. Fix for cross-observable: convert computed → stored property with explicit sync at stable points (end of `loadData()`, `.onChange`, etc.)
7. **`.onPreferenceChange` → `@State` in views with heavy `@Observable` tracking** is a latent feedback loop source. During navigation animations, geometry preferences change continuously. Each `@State` write triggers body re-evaluation, which re-tracks `@Observable` properties, amplifying any concurrent mutation into cascading invalidations
8. **Use `.backgroundPreferenceValue` / `.overlayPreferenceValue`** instead of `.onPreferenceChange` + `@State` when the preference value only needs to flow to background/overlay views. These APIs confine re-evaluation to the closure scope without invalidating the parent body
9. **Dead computed properties still register observation tracking** if accidentally called — remove them promptly after their sole consumer is deleted
10. **Any `@Observable` property mutated by an async Task** that is read in body should be cached in `@State` + `.onChange`. The async mutation can fire during NavigationStack layout, creating re-entrant invalidation. This applies even to stored (non-computed) properties
11. **View hierarchy depth amplifies latent feedback loops.** Adding wrappers (e.g., SectionGroup) that increase body evaluation cost can push previously-marginal observation tracking past the detection threshold
12. **When caching 5+ properties**, extract `.onChange` handlers into a `ViewModifier` to prevent type-checker timeouts on the main body
