---
tags: [swiftui, xctest, native-sheet, dynamic-type, accessibility, exact-label]
category: testing
date: 2026-11-04
severity: important
related_files:
  - DUNE/Presentation/Activity/Components/PersonalRecordsInfoSheet.swift
  - DUNEUITests/Full/ActivityExerciseRegressionTests.swift
related_solutions: []
---

# Native explanation sheet reading and dismissal

## Problem

The personal-record explanation needed a stronger title and consistent original icons while preserving its full document and native sheet behavior. Validation exposed three distinct driver problems: string-subscripting a 157-character body exceeded XCTest's identifier limit; small content pans did not move a medium sheet enough to reveal a lower leaf; and a single long grabber fling left the expanded normal sheet open. Each failed bundle remains archived with its actual outcomes.

## Solution

Use `NSPredicate(format: "label == %@", expected)` for exact full body labels. Keep the initial canonical capture, then read the real native grabber value and expand the sheet if needed. Short leaves must fit the actual viewport; oversized leaves keep their full label and width while bounded overlapping scroll intervals reach their top and bottom. Do not reduce font size or substitute existence-only assertions.

After reading, normal-size verification explicitly observes the system's Expanded → Half screen transition before its final dismiss gesture and checks return to Activity. Dark maximum text retains its successful direct gesture. This is test-driving logic: app detents, copy and runtime dismissal behavior were not modified to make the test pass. A preliminary block inserted before reading was caught and corrected by static review before native execution.

At source `6b857ae8cfc29fe7ec9f3a77a9c6d6af8992d509`, all five final cases passed: four normal device/pose profiles and dark maximum text on closed Duo. Independently reviewed selected PNG/AX show the original icons and readable content. Three earlier runs remain 2 passed/4 failed; they are not relabeled by the later success. Product/catalog bytes stayed unchanged through test corrections. The final comparison preserves unrelated screen rows and board pixels.

## Prevention

Query exact long labels rather than accessibility identifiers. Observe real native detent values and bounds before asserting motion; preserve original-state captures separately from expanded reading captures. Confirm actual dismissal with both functional assertions and genuine return-state evidence; teardown Home images are not proof of Activity return. Fully archive a completed run before editing source, and retain accurate export-time dirty state if the operations overlap.

## Lessons Learned

Source correctness, readable native layout and deterministic test driving are separate checks. A semantic native-state transition is more informative than retrying the same swipe. Use only affected selectors and consumers, reuse valid evidence after documentation-only publication, and keep original failures distinct from corrected final passes. No new `.claude` rule or unrelated full regression is needed.
