---
tags: [swiftui, posture, p08, accessibility, ui-testing]
category: general
date: 2026-11-07
severity: minor
status: unresolved
related_files: [DUNE/Presentation/Posture/PostureComparisonView.swift, DUNEUITests/Full/WellnessRegressionTests.swift]
related_solutions: []
---

# P08 comparison: implementation and held verification

The View keeps stored older/newer scores, dates, metric deltas, photos, joints, zoom and the existing AdaptivePaneView. It adds an opaque score surface, bounded rings and readable pane widths. Phone MAX score/pane checks passed on source 7b9138b6.

The normal test reached73/86/+13 and both fixture dates, then failed its photo-center assertion before zoom. Initial AX put the older photo at (28,345,188,334), with the pane ending at494.7; after one-direction scrolling the photo was at y-216. This proves the test overscrolled, not that zoom worked. The proposed correction uses a visible intersection and bounded directional scroll, preserving actual Front zoom and dismissal assertions. That correction remains unexecuted.

Phone and iPad checks each retain two failed histories. iPad Comparison has not been captured after the toolbar label correction. Duo cannot provide evidence because a fresh owned device also failed Data Migration before SDK. No new check ID or fresh device was used to replay P08. The [held gallery](../../design/full-redesign-map/review/posture-comparison-p08-2026-11-06/index.html) preserves before captures, MAX positives, normal diagnostics and original counts. Official actual-map P08 rows remain unchanged.

The next required evidence is a successful normal photo zoom/Close flow and current affected-device comparison captures with an available verification budget. No source-only expectation, previous PNG, or unrelated MAX pass substitutes for that result. P03/H08 limits and the unknown original l03/batch04 recovery remain unchanged.
