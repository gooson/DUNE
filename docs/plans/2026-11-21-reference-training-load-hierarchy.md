---
tags: [design, iphone, r06]
date: 2026-11-21
category: plan
status: approved
---
# R06 · training load hierarchy

Approved reference: `docs/design/layout-map/reference-improvement-proposals.md` and `docs/design/theme-map/themes/dune-reference-proposals.html`. Implement as one PR after R07 is merged from main `9d2f82398`; preserve DUNE tokens, existing navigation and data semantics.

## Implementation

Selected date and load now precede the chart; rolling comparison follows it. Fixed 2/4/7 colors and legend remain. R07 owns same-count cache invalidation and scroll-domain reset; this PR consumes those values without changing their update policy.

## Verification

- Focused tests: ChartInteractionRegressionUITests.testTrainingVolumeTrainingLoadLongPressKeepsVisibleRangeAndActivatesSelection and testTrainingVolumeTrainingLoadChartScrollsToPastData.
- Native capture IDs: Regular iPhone, iPad, Duo folded/open A06; selected day, scroll, empty state, and large text.
- Update the detail layout-map link and actual design map with new source/device/state provenance. Browser proposals are not native captures.
- Use `scripts/build-ios.sh`, the owned simulator UI runner, and `swift scripts/format-xcstrings.swift --check` if a catalog changes.
