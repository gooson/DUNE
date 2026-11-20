---
tags: [design, iphone, r12]
category: design
date: 2026-11-21
status: draft
related_files:
  - DUNE/Presentation/Exercise/
---
# Solution: R12 · machine level time history

## Problem

The approved reference hierarchy for W25, W27 is not represented in the existing native view.

## Change

The shared component draws step segments at active elapsed seconds and extends the last selected level through the recorded workout duration. Chart selection and full event rows use the stored level changes. Summary and saved detail pass the appropriate end time.

## Evidence to attach before merge

- Focused tests to run: CardioMachineLevelHistoryPlotTests.durationWeightedSteps and noInventedDuration; ActivityExerciseRegressionTests.testStairClimberLevelChangesAppearInSummary; retain pause behavior in CardioSessionViewModelTests.
- Fresh native screenshots and capture indices: Regular iPhone, iPad, Duo folded/open W25 and W27; multiple changes, one event, large text, saved record.
- Record build result, exact revision, simulator IDs, and any unverified states. Do not treat proposal PNGs or earlier captures as implementation evidence.
