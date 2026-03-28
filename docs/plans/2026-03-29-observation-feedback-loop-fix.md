---
tags: [observation, feedback-loop, swiftui, environment, weatherAtmosphere, @Observable]
date: 2026-03-29
category: plan
status: approved
---

# Plan: Fix UIObservationTrackingFeedbackLoopDetected in DashboardView

## Problem

`UIObservationTrackingFeedbackLoopDetected` crash/warning on app launch. The NavigationStackHostingController receives repeated layout invalidations.

### Root Cause

`DashboardView` reads `viewModel.weatherAtmosphere` (an `@Observable` property) directly in `.environment(\.weatherAtmosphere, viewModel.weatherAtmosphere)`. This injects the value into the **entire NavigationStack subtree**. When the async `.task(id:)` calls `loadData()`, which modifies `weatherAtmosphere` (reset to `.default` then set to fetched value), it triggers:

1. Environment change propagates to all children
2. NavigationStack re-layouts
3. Body re-evaluates, re-reading `viewModel.weatherAtmosphere`
4. If still mid-layout from step 2, this creates the feedback loop

### Why `.environment()` is special

Unlike a regular `Text(viewModel.title)` read, `.environment()` propagates to the entire subtree. When the value changes during layout, the NavigationStackHostingController must re-layout all children, which re-evaluates the parent body, creating the cycle.

## Solution

Cache `weatherAtmosphere` in a `@State` variable. Sync via `.onChange(of:)`. This breaks the observation tracking during layout because `@State` changes are coalesced to the next render pass.

## Affected Files

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/DashboardView.swift` | Add `@State cachedWeatherAtmosphere`, use in `.environment()`, sync via `.onChange` | Break observation feedback loop |

## Implementation Steps

### Step 1: Cache weatherAtmosphere in @State

1. Add `@State private var cachedWeatherAtmosphere: WeatherAtmosphere = .default`
2. Replace `.environment(\.weatherAtmosphere, viewModel.weatherAtmosphere)` with `.environment(\.weatherAtmosphere, cachedWeatherAtmosphere)`
3. Add `.onChange(of: viewModel.weatherAtmosphere) { _, newValue in cachedWeatherAtmosphere = newValue }`

## Test Strategy

- **Build verification**: `scripts/build-ios.sh`
- **Runtime verification**: Launch app, confirm no `UIObservationTrackingFeedbackLoopDetected` in console
- **Functional verification**: Weather-reactive wave backgrounds still update correctly when weather data loads

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| Initial state mismatch | Default value `.default` matches ViewModel's initial value |
| Delay in atmosphere update | `.onChange` fires on next render pass — imperceptible to user (< 1 frame) |
| Other `@Observable` reads in `.environment()` | Audited: `weatherAtmosphere` is the only ViewModel property passed via `.environment()` in DashboardView |

## Related Solutions

- `docs/solutions/performance/2026-02-16-computed-property-caching-pattern.md` — same principle of caching @Observable reads
- `docs/solutions/architecture/2026-02-28-weather-display-integration.md` — original WeatherAtmosphere environment design
