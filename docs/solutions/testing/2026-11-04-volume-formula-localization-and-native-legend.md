---
tags: [swiftui, localization, training-volume, integer-division, dynamic-type, accessibility]
category: testing
date: 2026-11-04
severity: important
status: scoped-native-reviews-complete
related_files:
  - DUNE/Presentation/Activity/Components/VolumeAlgorithmSheet.swift
  - DUNE/Presentation/Shared/Extensions/ExerciseRecord+WeeklyVolume.swift
  - Shared/Resources/Localizable.xcstrings
related_solutions: []
---

# Weekly volume explanation: per-record rounding and localized helper text

## Problem

The weekly volume explanation described secondary work as one-half of sets and displayed a simple halving sum. The existing calculation instead applies integer division separately to each secondary-muscle record and credits a minimum of one set for each record. Rounding after a combined sum or omitting that minimum can describe a different result; for records with 1, 3 and 5 completed sets the existing per-record secondary contributions are 1, 1 and 2. This is a worked calculation, not a claim about the seeded UI fixture.

Several existing explanatory bullet strings passed through a `String` helper and were absent from the shared string catalog. The `5-Level Volume Scale` heading was also missing. Those paths could display English fallback in Korean or Japanese. The overview and its existing translations were already registered; no claim that they were missing is made.

## Solution

The presentation copy now states that each secondary record's completed sets are halved, rounded down and credited at least one set. Its formula distinguishes the primary sum and per-record secondary contribution: `Volume = Σ primary sets + Σ max(⌊secondary sets ÷ 2⌋, 1)`. Existing actual arithmetic and data flow remain unchanged. The existing zero-set minimum behavior is not asserted as an observed UI fixture.

Use `LocalizedStringKey` for the explanatory helper and register eight missing manual English/Korean/Japanese keys: the five retained bullet sentences, corrected secondary sentence, corrected formula and five-level heading. At the reviewed source, all 13 meaningful literal title/heading/body/helper strings have catalog entries with Korean/Japanese translations; punctuation is not user copy requiring a translation. Run the official formatter and manual-state checks at actual integration and after build. Preserve any prior key still used elsewhere.

The screen keeps its existing large native sheet, original information and sets-legend entry routes, five volume intensity levels, data and native dismissal. On source `6d186b3ac51f4fa94c91c06455ea6e267a0a037d`, six focused native cases passed: closed Duo normal and dark maximum text, open Duo normal, iPhone normal, iPad normal, and a separate iPad A03 sets-legend route. Selected screenshots and accessibility records received scoped independent source, native and pre-install stage review; final publication remains pending until merge. Two earlier closed bundles are preserved as mixed outcomes: source 357 normal passed and MAX failed; source eb6 normal failed and MAX passed. The reviewed one-extra correction used a separate proxy record; it did not rewrite those failures. A Python executable alias affected receipt metadata matching and was corrected as a bounded metadata validation change, not as an app-test result.

## Prevention

- Trace explanatory formulas to the exact production operation, including integer division, per-record grouping and minimums. Check a small worked example independently without misrepresenting it as seeded user data.
- Audit helper argument types and all direct/helper string literals against the actual manual catalog; retain localization and Dynamic Type behavior when rearranging UI.
- Inspect actual large-text PNG and paired AX for formula wrapping, all level relationships and horizontally scrollable legend endpoints, and verify both real entry routes and native dismissal. Do not claim every glyph is visually verified solely because a frame assertion passed.

## Lessons learned

Correct mathematics, localized presentation and native layout are separate checks. Updating explanatory copy did not require changing a correct service or adding a new unit test for unchanged arithmetic; it did require accurately describing its per-record behavior and checking the actual rendered explanation. No new `.claude` rule or broad regression is implied.
