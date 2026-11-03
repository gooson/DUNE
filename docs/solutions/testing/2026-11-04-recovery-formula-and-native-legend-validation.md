---
tags: [swiftui, fatigue, localization, formula, dynamic-type, xctest, accessibility]
category: testing
date: 2026-11-04
severity: important
status: resolved-scoped-native
related_files:
  - DUNE/Presentation/Activity/Components/FatigueAlgorithmSheet.swift
  - DUNE/Domain/UseCases/FatigueCalculationService.swift
  - Shared/Resources/Localizable.xcstrings
  - DUNEUITests/Full/ActivityExerciseRegressionTests.swift
  - DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift
related_solutions: []
---

# Generic fatigue explanation: explain the effective time constant

## Problem

The generic fatigue explanation presented 72h/36h muscle-size examples as τ. Those recovery-hour inputs do not by themselves equal the effective time constant: the existing service doubles the muscle's recovery hours, divides by sleep and readiness modifiers with a denominator floor, and imposes an outer one-hour minimum. A visual redesign that merely preserved the old sentence would continue to explain the computation inaccurately. The prior localized catalog entry also had to be replaced with a correctly registered key.

## Solution

`FatigueAlgorithmSheet` now displays the existing computation as `τ = max(2 × recovery hours ÷ max(sleep × readiness, 0.1), 1 hour)`; the original decay formula, 14-day description, modifier examples, all ten level descriptions and legend remain. The retired unused τ key was removed and the new equation has explicit manual English, Korean and Japanese values. The data model and `FatigueCalculationService` were not changed.

The original normal and dark accessibility-XXXL tests assert the exact decay and τ leaves, nonempty fully contained descriptions for all ten levels, legend existence and real system-sheet dismissal. Representative levels 1, 5 and 10 were captured for visual review. A separate regular-iPad A03 recovery-legend route exercises the actual alternate generic-sheet consumer, verifies the formula and τ, then dismisses and returns to Activity. This is not the distinct A14 per-muscle calculation sheet.

At actual source `95ecbe1846133c1e5d1073e24686ee5fff72e549`, closed Duo normal + dark MAX passed 2/2; open Duo, phone, iPad normal and separate iPad A03 consumer each passed 1/1. Independent native review inspected the selected formula, τ and representative level captures; a passing ten-level AX/geometry loop is not a claim that every level glyph was visually inspected. Captures are scoped to the observed seeded state and devices, not all languages, themes, VoiceOver speech or data states.

## Prevention

- Trace explanatory text through the actual service, including clamps, floors and modifiers; distinguish input examples from the resulting effective value.
- Register changed manual catalog keys for en/ko/ja, retain any still-used old key and run the project's formatter/manual-state checks at integration.
- Check real formula text, accessible frames, native dismissal and both actual consumers. Keep screen/source/selector/PNG/AX provenance exact; record failures as failures and distinguish test assertions from independently inspected pixels.

## Lessons learned

A mathematically correct computation can still be accompanied by an inaccurate explanation. Source-level equation review, catalog registration and bounded native evidence address different parts of that problem; none should stand in for another. No broad regression or new `.claude` rule follows from this screen-specific correction.
