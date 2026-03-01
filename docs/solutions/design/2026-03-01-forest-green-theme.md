---
tags: [theme, forest-green, ukiyo-e, swiftui, wave-background, performance]
date: 2026-03-01
category: solution
status: implemented
---

# Forest Green Theme Implementation

## Problem

DUNE needed a 3rd theme (after Desert Warm and Ocean Cool) with a ukiyo-e forest aesthetic — mountain/forest silhouette waves, golden amber + red maple accents, and procedural woodblock grain texture.

## Solution

### Architecture

| Component | File | Purpose |
|-----------|------|---------|
| `ForestSilhouetteShape` | `ForestSilhouetteShape.swift` | Shape: mountain ridge + tree silhouettes + washi edge noise |
| `ForestWaveOverlayView` | `ForestWaveBackground.swift` | Single animated forest layer with bokashi gradient + optional grain |
| `UkiyoeGrainView` | `ForestWaveBackground.swift` | Pre-rendered woodblock grain texture (UIImage, zero per-frame cost) |
| `ForestTabWaveBackground` | `ForestWaveBackground.swift` | 3-layer parallax (far/mid/near) for tab screens |
| `ForestDetailWaveBackground` | `ForestWaveBackground.swift` | 2-layer for detail screens |
| `ForestSheetWaveBackground` | `ForestWaveBackground.swift` | 1-layer for sheet/modal |
| Forest colors (file-private) | `ForestWaveBackground.swift` | `forestDeepColor`, `forestMidColor`, `forestMistColor` |
| Theme dispatch | `AppTheme+View.swift` | All shared theme properties (accent, score, metric, weather, card) |

### Key Decisions

1. **WaveSamples reuse**: Made `WaveSamples` internal (was private in OceanWaveShape.swift) so `ForestSilhouetteShape` shares the same pre-computed angle array instead of duplicating.

2. **edgeNoise as static let**: Edge noise depends only on `sampleCount` (constant), so hoisted to `private static let` — prevents re-computation on every animation frame (was re-running 121-iteration loop at 60fps x 3 layers).

3. **UkiyoeGrainView pre-rendered to UIImage**: Canvas closure was executing ~8,580 iterations per render pass. Replaced with `UIGraphicsImageRenderer` producing a static `UIImage` cached as `static let`. Zero per-frame computation.

4. **File-private wave colors**: Forest layer colors (`forestDeepColor`, `forestMidColor`, `forestMistColor`) are only used by forest background views. Moved to `private extension AppTheme` in `ForestWaveBackground.swift` to prevent polluting the shared `AppTheme` extension.

5. **Score gradient consolidation**: Duplicated `forestScoreGradient` (and Desert/Ocean equivalents) in `ConditionHeroView` and `HeroScoreCard` replaced with shared `theme.detailScoreGradient`.

6. **Explicit rawValues**: `AppTheme` enum cases now have explicit `String` raw values to protect `@AppStorage` persistence against future case renames.

### Color Assets

- **iOS**: 28 Forest colorsets (reduced to 27 after removing unused ForestFoam)
- **watchOS**: 27 Forest colorsets (synced with iOS — Correction #69)
- Named `Forest{Category}{Name}` (e.g., `ForestScoreExcellent`, `ForestMetricHRV`)

### Performance Pattern

ForestSilhouetteShape animation loop:
```
SwiftUI animation frame
  → ForestSilhouetteShape.init (WaveSamples reuse, no edgeNoise recompute)
  → path(in:) (121 points × sin() calls — unavoidable for phase animation)
  → UkiyoeGrainView (static UIImage, zero computation)
```

Before fix: ~130k sin() calls/sec + ~514k Path allocations/sec from grain
After fix: ~7k sin() calls/sec (path only), grain = 0 per-frame cost

## Prevention

- New theme wave backgrounds should follow this pattern:
  1. Shape in its own file, using shared `WaveSamples`
  2. Static pre-computation for deterministic noise/patterns
  3. Wave-specific colors as `private extension AppTheme` in the background file
  4. Pre-render any procedural textures to `UIImage` (never use Canvas for deterministic patterns)
  5. Sync all color assets to Watch target at creation time
