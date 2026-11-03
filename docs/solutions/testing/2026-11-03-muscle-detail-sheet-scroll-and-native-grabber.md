---
tags: [swiftui, xctest, dynamic-type, accessibility, sheets, duo]
category: testing
date: 2026-11-03
severity: important
related_files:
  - DUNE/Presentation/Activity/Components/MuscleDetailPopover.swift
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Activity/MuscleMap/MuscleMapDetailView.swift
  - DUNEUITests/Full/ActivityExerciseRegressionTests.swift
  - DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift
related_solutions: []
---

# Solution: Muscle detail sheet scroll and native grabber checks

## Problem

The shared muscle detail component appears in an Activity sheet and an inline muscle-map pane. The redesign needed to preserve the selected muscle, actual status and metric values, conditional calculation and existing exercise recommendations in both consumers.

The original closed-Duo `b26ff4c0` run failed both cases. At maximum text the weekly-volume leaf was below the visible sheet; alternating full swipes overshot it. The normal case reached its metrics and calculation action but did not recognize the observed native label `Sheet Grabber` because the existing predicate used different capitalization. Both original failures remain archived; the scroll diagnosis is supported by the recorded viewport and gesture sequence, not a claim about every device.

## Solution

`MuscleDetailPopover.swift` keeps the same data and actions, with a theme-aware hero and an accessibility-size single-column presentation. The Activity consumer provides a scrollable sheet; the existing muscle-map consumer retains its own inline scrolling pane. The focused tests use the named actual pane and check the selected title, status, real metric labels and calculation action in each relevant consumer.

The 72c test correction uses bounded short drags inside the actual sheet/window intersection, in the direction of the target. It retains nonempty values and full-frame containment rather than accepting a clipped leaf. The native grabber predicate includes the observed English capitalization alongside existing alternatives; the test still requires a hittable grabber, native dismissal and a usable Activity screen after return. The A03 inline route also opens and dismisses the existing baseline calculation sheet; that is not a later A14 implementation.

Normal sheet cases passed on phone, iPad, closed Duo and open Duo; dark Accessibility XXXL passed on closed Duo, and the separate iPad inline case passed. Closed normal/MAX were one actual 2/2 bundle; the others were separate 1/1 cases. [Reviewed gallery and provenance](../../design/full-redesign-map/review/a13-muscle-detail-native-2026-11-03/index.html) include actual screenshots, AX and the preserved failure. These observations do not establish VoiceOver traversal or all conditional data states.

## Prevention

- Select the actual sheet or named inline pane before scrolling; expose the target with a bounded, directional gesture and assert its real full frame and content.
- Preserve the observed system control labels and verify native dismissal and the return route; do not replace interaction with a test-only close action.
- For Duo, verify actual hinge angle and active-display readbacks before and after capture. A successful setter alone does not prove the correct display. Keep preflight mismatches separately from test outcomes.

## Lessons Learned

A missing label and a geometry overshoot can produce different failures in the same bundle. Inspect the actual hierarchy and viewport before correcting test navigation, and retain raw failures when later cases pass. In the open-Duo preflights, sensor and display observations disagreed; their cause was not established, so no cause or repair should be inferred from the setter exit alone.
