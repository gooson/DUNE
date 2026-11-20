---
tags: [design, iphone, r10]
category: design
date: 2026-11-21
status: draft
related_files:
  - DUNE/Presentation/Exercise/
---
# Solution: R10 · cardio summary hierarchy

## Problem

The approved reference hierarchy for W25 is not represented in the existing native view.

## Change

Distance is the single primary result for distance cardio, duration follows, and secondary statistics use aligned rows. Time-only cardio makes duration primary. Existing Save action and persistence are unchanged. The previously missing Elevation Gain catalog entry is supplied in Korean and Japanese.

## Evidence to attach before merge

- Focused tests to run: ActivityExerciseRegressionTests.testCardioFlowReachesSummary and testVisualAuditCardioAtDefaultTextSize; verify distance above duration, no-distance stair primary duration, secondary metrics, and Save hit area.
- Fresh native screenshots and capture indices: Regular iPhone, iPad, Duo folded/open W25; running and no-distance cardio, standard/large text.
- Record build result, exact revision, simulator IDs, and any unverified states. Do not treat proposal PNGs or earlier captures as implementation evidence.
