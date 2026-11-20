---
tags: [design, iphone, r12]
date: 2026-11-21
category: plan
status: approved
---
# R12 · machine level time history

Approved reference: `docs/design/layout-map/reference-improvement-proposals.md` and `docs/design/theme-map/themes/dune-reference-proposals.html`. Implement as one PR on main `9d2f82398`; preserve DUNE tokens, existing navigation and data semantics.

## Implementation

The shared component draws step segments at active elapsed seconds and extends the last selected level through the recorded workout duration. Chart selection and full event rows use the stored level changes. Summary and saved detail pass the appropriate end time.

## Verification

- Focused tests: CardioMachineLevelHistoryPlotTests.durationWeightedSteps and noInventedDuration; ActivityExerciseRegressionTests.testStairClimberLevelChangesAppearInSummary; retain pause behavior in CardioSessionViewModelTests.
- Native capture IDs: Regular iPhone, iPad, Duo folded/open W25 and W27; multiple changes, one event, large text, saved record.
- Update the detail layout-map link and actual design map with new source/device/state provenance. Browser proposals are not native captures.
- Use `scripts/build-ios.sh`, the owned simulator UI runner, and `swift scripts/format-xcstrings.swift --check` if a catalog changes.
