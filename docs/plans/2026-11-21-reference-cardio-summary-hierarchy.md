---
tags: [design, iphone, r10]
date: 2026-11-21
category: plan
status: approved
---
# R10 · cardio summary hierarchy

Approved reference: `docs/design/layout-map/reference-improvement-proposals.md` and `docs/design/theme-map/themes/dune-reference-proposals.html`. Implement as one PR on main `9d2f82398`; preserve DUNE tokens, existing navigation and data semantics.

## Implementation

Distance is the single primary result for distance cardio, duration follows, and secondary statistics use aligned rows. Time-only cardio makes duration primary. Existing Save action and persistence are unchanged. The previously missing Elevation Gain catalog entry is supplied in Korean and Japanese.

## Verification

- Focused tests: ActivityExerciseRegressionTests.testCardioFlowReachesSummary and testVisualAuditCardioAtDefaultTextSize; verify distance above duration, no-distance stair primary duration, secondary metrics, and Save hit area.
- Native capture IDs: Regular iPhone, iPad, Duo folded/open W25; running and no-distance cardio, standard/large text.
- Update the detail layout-map link and actual design map with new source/device/state provenance. Browser proposals are not native captures.
- Use `scripts/build-ios.sh`, the owned simulator UI runner, and `swift scripts/format-xcstrings.swift --check` if a catalog changes.
