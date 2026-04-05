---
tags: [observation, feedback-loop, preference-key, NavigationStack, layout-invalidation, heroFrame]
date: 2026-04-05
category: plan
status: draft
---

# Plan: Eliminate NavigationStack Observation Feedback Loop (3rd Instance)

## Problem

`UIObservationTrackingFeedbackLoopDetected` recurs when entering Settings from the Today tab. Previous fixes addressed:
1. `.environment()` reading `@Observable` property (weatherAtmosphere)
2. Cross-observable computed read-through (conditionSparkline)
3. Computed visibility properties reading currentTimeBand
4. sectionVisibilityHash animation removal

## Root Cause Analysis

The feedback loop is caused by `@State heroFrame` ← `onPreferenceChange(TabHeroFramePreferenceKey)` cycle during NavigationStack push animations:

1. NavigationStack starts push animation → content slides
2. Hero card frame changes in coordinate space → `GeometryReader` reports new frame
3. `TabHeroFramePreferenceKey` preference flows up
4. `.onPreferenceChange` fires → `heroFrame = newFrame` (`@State` mutation)
5. `@State` change → DashboardView body re-evaluation
6. Body re-evaluation reads ~20 `@Observable` ViewModel properties (observation tracking)
7. If any ViewModel property changed (from in-flight async work like `enhanceCoachingTask`, `ScoreRefreshService.scheduleSparklineReload`), observation triggers ANOTHER invalidation
8. NavigationStack receives repeated [layout] invalidations → feedback loop detected

Key insight: `@State heroFrame` change triggers a FULL DashboardView body re-evaluation. Because body reads ~20 `@Observable` properties, any concurrent ViewModel mutation (from async tasks) compounds into cascading invalidations. This only manifests during navigation transitions because the push animation continuously changes the hero frame geometry.

## Solution

Replace `@State heroFrame` + `.onPreferenceChange` + `.background { ... .environment(\.tabHeroStartLineInset, ...) }` with `.backgroundPreferenceValue(TabHeroFramePreferenceKey.self)`.

`backgroundPreferenceValue` reads the preference and provides it directly to a background view builder. When the preference changes, **only the background view builder re-evaluates** — the parent view's body does NOT re-evaluate. This breaks the cycle.

## Affected Files

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/DashboardView.swift` | Remove `@State heroFrame`, use `backgroundPreferenceValue` | Break feedback loop |
| `DUNE/Presentation/Activity/ActivityView.swift` | Same pattern fix | Preventive — same pattern |
| `DUNE/Presentation/Wellness/WellnessView.swift` | Same pattern fix | Preventive — same pattern |
| `DUNE/Presentation/Life/LifeView.swift` | Same pattern fix | Preventive — same pattern |

## Implementation Steps

### Step 1: Fix DashboardView (primary)

Remove:
- `@State private var heroFrame: CGRect?`
- `.onPreferenceChange(TabHeroFramePreferenceKey.self) { heroFrame = $0 }`

Replace `.background { TabWaveBackground().environment(\.tabHeroStartLineInset, heroFrame.map(...)) }` with:
```swift
.backgroundPreferenceValue(TabHeroFramePreferenceKey.self) { heroFrame in
    TabWaveBackground()
        .environment(\.tabHeroStartLineInset, heroFrame.map(TabHeroStartLine.inset(for:)))
}
```

### Step 2: Fix ActivityView, WellnessView, LifeView (preventive)

Apply the same pattern to all tab root views that use `@State heroFrame` + `onPreferenceChange` + `.background { .environment(\.tabHeroStartLineInset, ...) }`.

### Step 3: Remove dead computed property

Remove `sectionVisibilityHash` from DashboardViewModel — it's defined but unused after the animation removal.

## Test Strategy

- Build verification: `scripts/build-ios.sh`
- Manual: Navigate to Settings from Today tab — no UI block, no console warning
- Verify wave background still renders correctly (hero-anchored start line)
- Verify other tabs' wave backgrounds render correctly

## Risks / Edge Cases

- `backgroundPreferenceValue` API availability: iOS 13+ (project targets iOS 26+ — safe)
- Wave background rendering: verify the preference value is correctly passed through
- Coordinate space must still be defined on the ScrollView content for `reportTabHeroFrame()` to work — this is unaffected since coordinate space definition stays on the VStack
