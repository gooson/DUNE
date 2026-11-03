---
tags: [swiftui, exercise-mix, frequency, copy, localization, dynamic-type, native-sheet]
category: general
date: 2026-11-04
severity: minor
related_files:
  - DUNE/Presentation/Activity/Components/ExerciseMixInfoSheet.swift
  - DUNE/Domain/UseCases/ExerciseMixService.swift
  - DUNEUITests/Full/ActivityExerciseRegressionTests.swift
related_solutions:
  - docs/solutions/testing/2026-11-04-consistency-sheet-builder-and-native-route.md
---

# Match exercise frequency explanations to their existing date window

## Problem

The exercise mix sheet described counting exercises across all records, while the existing service selects the latest 28 local calendar days through now. Its title was also repeated and the flat text groups lacked the visual emphasis applied to the surrounding detail screens.

## Solution

Trace the sole Activity caller and `ExerciseMixService.analyze` before editing the help copy. Keep merging, deduplication, filtering, frequency percentages and sorting unchanged. Correct the sentence to the last four weeks and register one manual English/Korean/Japanese key. Audit all 15 meaningful literals rather than presuming a visual-only change has no localization impact.

Reuse the opaque themed chart hero, preserve the original chart and four section symbols, and apply directly to the four existing groups a simple `ViewModifier` card. Intrinsic icon padding and vertically flexible text preserve large text; the original ScrollView, native medium/large detents and accessibility behavior remain.

Five focused native cases passed on the original source: four normal profiles plus closed Duo dark maximum text. Capture the canonical state before expansion, read headings/body through exact full-label predicates and bounded overlapping scrolling, and verify native dismissal and Activity return. Archive and seal each run before the next can prune SDK output. Inspect actual selected PNG/AX independently before publishing, preserving non-target board pixels and clearly labeling unknown historical provenance. A MAX lock-screen frame is not visual return proof even when functional return assertions pass.

## Prevention

Review data-window wording against the current service and date/calendar semantics. Keep source review, actual native results and visual publication review distinct. Derive file pins from real bytes; reuse the same scoped run for functional checks and captures. Do not rerun unrelated suites for documentation-only publication or copy prior screen failures into a fresh screen's history.

## Lessons Learned

A small explanation redesign can correct a meaningful mismatch without changing the data contract. Consistency comes from shared visual tokens and original symbols, while each native test must still cover its real entry, text and return behavior. No new Claude rule or service change was necessary.
