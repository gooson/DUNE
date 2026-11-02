---
tags: [swiftui, muscle-map, compact-layout, observed-population, native-ui-testing]
category: architecture
date: 2026-11-03
severity: important
related_files:
  - DUNE/Presentation/Activity/MuscleMap/MuscleMapDetailView.swift
  - DUNE/Presentation/Activity/Components/MuscleRecoveryMapView.swift
  - DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift
related_solutions:
  - architecture/2026-02-27-muscle-map-detail-view-integration.md
  - architecture/2026-11-03-disable-muscle-map-entry-without-removing-implementation.md
---

# Muscle recovery: consistent populations and one compact scroll

## Problem

A redesigned recovery header could combine a live fatigue-state denominator with a cached recovered count. `.noData` states also satisfied the existing recovery predicate, so counting every supplied state implied that unobserved muscles were ready. The first successful Phone interaction test additionally showed a visual defect: two vertically arranged independent pane scrolls split the anatomy map above the volume pane.

## Solution

The A03 presentation filters one observed population (`fatigueLevel != .noData`) and derives its numerator using the existing `isRecovered` predicate. Header, recovery overview and recovery subtitle use this same population. The original full fatigue array still drives anatomy colors and weekly volume; the optional `recoverySummaryStates` argument only overrides the recovery subtitle. No recovery calculation, retrieval, SVG geometry, set goal or ViewModel changes are required.

Compact layout now uses one scroll containing map and summary content. Regular layout retains its existing two native panes. Recovery/Sets selection lives in the parent; an optional binding lets this screen own selection while other map callers keep local state. Fixed-pose captures establish each layout; they do not establish state continuity through a live fold.

The original cube entry remains visibly disabled and the 3D destination, engine and assets are retained. Real selected-muscle calculation, native grabber dismissal and Activity Back remain part of the focused interaction selector.

## Validation and limits

The initial closed-Duo attempt failed because its eight unconditional upward swipes moved the cube from a partly visible bottom position to negative Y. Archived pixels and AX established this direction error. A bounded short drag now chooses direction from the actual target frame, retaining the full-containment assertion and disabled-state assertion. The same-ID single conditional retry passed, and a fresh Open run passed; both recorded all eight capture acknowledgements and actual angle/display before and after. The earlier failure remains in history.

The earlier iPad approved-extra calculation case passed with real drag dismissal and Back. It remains an a226 source result, reused only within the documented unchanged regular-content/default-Recovery closure. Earlier Phone de559 passed before the compact correction and remains diagnostic evidence rather than the final after image. The fresh fef79bbf Phone also passed after the compact correction. The installed gallery records four before/after pairs, selected detail, calculation and actual post-Back screenshots. The iPad image remains explicitly historical a226; the other three after sets are fef79bbf.

No new tests mirror unchanged fatigue mathematics. Native captures and code reviews cover this presentation delta; maximum accessibility size, every mode/goal combination and live fold continuity are not claimed as freshly executed.

## Prevention

Use the same observed population for a numerator, denominator and explanatory subtitle. Preserve full source data when a summary needs a narrower population. Review actual default and selected screenshots even after an interaction test passes. A scroll reveal must be bounded and direction-aware when content can appear on either side of the viewport.

## Lessons Learned

A successful calculation/Back path can coexist with a fragmented first viewport. Layout quality needs direct image inspection in addition to assertions. A test correction should retain its user-visible contract and preserve the original failed evidence.

No `.claude` rule or configuration change is necessary; the existing scope and evidence policies cover this case.
