---
tags: [design, iphone, r06]
category: design
date: 2026-11-21
status: draft
related_files:
  - DUNE/Presentation/Activity/
---
# Solution: R06 · training load hierarchy

## Problem

The approved reference hierarchy for A06 is not represented in the existing native view.

## Change

Selected date and load now precede the chart; rolling comparison follows it. Fixed 2/4/7 colors and legend remain. R07 owns same-count cache invalidation and scroll-domain reset; this PR consumes those values without changing their update policy.

## Evidence to attach before merge

- Focused tests to run: ChartInteractionRegressionUITests.testTrainingVolumeTrainingLoadLongPressKeepsVisibleRangeAndActivatesSelection and testTrainingVolumeTrainingLoadChartScrollsToPastData.
- Fresh native screenshots and capture indices: Regular iPhone, iPad, Duo folded/open A06; selected day, scroll, empty state, and large text.
- Record build result, exact revision, simulator IDs, and any unverified states. Do not treat proposal PNGs or earlier captures as implementation evidence.
