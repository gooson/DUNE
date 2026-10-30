---
topic: T08 weather detail native redesign
date: 2026-10-31
status: approved
confidence: high
related_solutions: [docs/solutions/architecture/weather-detail-page-outdoor-fitness.md, docs/solutions/performance/2026-03-29-observation-tracking-feedback-loop.md]
related_brainstorms: []
---

# Implementation Plan: T08 Weather Detail

## Context

The reviewed T08 proposal (snapshot `786c2c3cb8dab80ccb0f5db0414c23f0ae5e4894`) makes current weather and the forecast easier to scan through a condition-specific sky. The preserved proposal JSON and light/dark images are browser design references, not native captures.

## Requirements

- Preserve the existing push destination, back/scroll actions, all conditional sections and section order, condition symbols, best-hour and outdoor-score calculations, AQ pollutant gates, forecast values and range bars, and stale indicator.
- Add a deep, weather-specific sky with sun/moon, cloud, precipitation, wind, and fog layers using bounded SwiftUI drawing with gentle condition motion. The scene reads the existing `condition` and `isDaytime`; it makes no weather service or domain changes.
- Keep temperature, condition, location and conditional feels-like readable in light/dark mode, regular width, Duo, and maximum Dynamic Type. Decorative content is hidden from accessibility.
- Add visual emphasis to score, best time, and details without new medical advice or new strings. Retain existing localization keys.

## Approach

Implement the scene in the existing view file to avoid project regeneration. Use one bounded `Canvas` with a paused `TimelineView` and system symbol on the hero, with a theme semantic-color gradient plus dark text scrim. The timeline stops once less than half of the hero is visible, outside the active scene, under Reduce Motion, and for static UI audit; it writes no observation feedback. Enhance existing section surfaces and hourly temperature flow while preserving data and gates.

## Affected Files

| File | Change |
|---|---|
| `DUNE/Presentation/Dashboard/WeatherDetailView.swift` | Hero scene, section emphasis, forecast flow |
| `docs/design/layout-map/weather-detail-redesign-proposal.md` | T08 native layout contract |
| `docs/design/layout-map/index.html` | Screen map link |
| `docs/design/theme-map/manifest.json`, `README.md` | Register reviewed T08 light/dark study |
| `DUNEUITests/Full/TodaySettingsRegressionTests.swift` | Focused destination/hero/sections assertion |
| `docs/design/phone-design-map/actual/**` | Fresh T08 affected-device captures after runtime gate |

## Implementation Steps

1. Register the reviewed proposal in layout and theme maps, keeping the browser/native distinction explicit.
2. Replace only the current hero presentation and strengthen existing score/details/forecast visual hierarchy. Keep all data inputs and gates.
3. Add focused UI assertions. Run `TodaySettingsRegressionTests/testWeatherCardOpensWeatherDetail` in the worktree-owned simulator, then capture T08 on regular iPhone, iPad, Duo closed/open and inspect light/dark and AX after the parent releases the runtime lane.
4. Update actual-design-map PNG and indexes using new captures only, review the diff, then commit/PR under the parent pipeline.

## Edge Cases

| Case | Handling |
|---|---|
| AQ or forecast absent | Existing conditional sections remain absent |
| Stale snapshot | Existing stale label stays visible |
| Night | Moon and deeper sky, using `isDaytime` only |
| Reduce Motion/offscreen/static UI audit | Timeline paused and static drawing |
| Maximum AX / narrow width | Text-first vertical hero; sky illustration behind text |

## Testing Strategy

- Existing exact UI selector for navigation and retained section elements; no full local regression.
- Focused opt-in fixtures cover clear day, rain night, snow day, and fog day; capture representative dark and maximum AX states, plus regular/dark/max AX and affected widths. Capture only after build and owned simulator access.
- String catalog format/manual-state check if catalog changes; no new strings are planned.

## Risks

- Hero contrast and AX clipping: verify native screenshots and adjust scrim/height.
- Canvas compositing cost: fixed geometry, at most 12 frames per second while visible and active; inspect scroll performance only if there is a symptom.

## Final native validation

Three focused phone methods passed atae9ef78e; iPad and Duo folded0°/unfolded180° normal entries passed ata52ddbeb after a test-only top-tab viewport correction. All four new actual T08 images and original matched images are preserved in the native comparison and actual map. Independent final quality gate returned PASS WITH NOTES and no open P1–P3. Live WeatherKit accuracy and sustained animation/energy are outside the static mock evidence. No production calculation changed, so no new unit suite or full local regression was required.
