---
title: Sleep prediction visual hierarchy and loaded notification evidence
date: 2026-11-02
category: architecture
tags: [swiftui, sleep-prediction, dynamic-type, notification-routing, visual-evidence]
severity: moderate
status: validation-in-progress
---

# Sleep prediction detail and its loaded notification consumer

## Problem

The previous small confidence capsule did not give the prediction confidence a clear hierarchy. A translucent centered score and horizontal factor rows also needed more space at accessibility text sizes. The same detail is presented by a bedtime notification, but detecting its wrapper alone does not establish that a prediction actually loaded. A screenshot after Back shows the notification hub, rather than the detail.

## Solution

`SleepPredictionDetailView` now uses its own opaque score surface, the existing compact ring at ordinary text sizes, and a stacked text score at accessibility sizes. Confidence uses the actual low/medium/high enum with one/two/three qualitative marks; these are not probabilities. Existing outlook symbols, factor content and impacts, tips and empty variants remain. Decorative factor glyphs use a small fixed font within a larger slot so enlarged text does not overlap them. The prediction model and use case remain unchanged.

The T15 wrapper in `ContentView` is an accessibility containing group so both the wrapper and loaded child identifiers remain available. The existing default bedtime-route test waits for the computed score and loaded child, confirms Today is selected, captures that loaded viewport, then taps the native Back button and verifies the hub return. It does not replace the computed result with a strict fixture. H03 uses the existing strict design fixture; its 78/two-factor view must remain distinct from the default computed T15 capture.

The H03 Back helper uses an existing hittable native rail button when available and the navigation-bar button otherwise. The native rail's accessibility rectangle is not assessed as a custom 44-point control. Existing window-bounds checks and actual return assertions remain.

## Verification and limits

The final UI target compiled at validation `59fdf60f`; relevant source and selected methods match public product commit `67e5ea09`. The final-glyph Phone maximum-text case passed once, including actual Back and disappearance of the detail. Prior Phone normal/confidence and iPad normal/maximum evidence is retained under explicit relevant-source closure; whole validation and PR trees are not equal. The ordinary default T15 historical image proves a loaded prediction, not the newly added Back assertions.

Duo closed/open route results, publication and final quality review are still pending at this document's initial checkpoint. The final evidence gallery will record actual pose readbacks, image hashes, loaded default scores, exact selected tests and original histories. No full local regression, repeated iPad matrix or Watch runtime is required for this private iOS layout change; existing CI remains enabled.

## Prevention

Capture a shared consumer only after its actual loaded leaf exists. Preserve the default route's inputs and distinguish strict design fixtures from live computed values. Select explicit pre-Back checkpoints; never infer a detail screen from a successful wrapper query or a teardown image. Reuse prior tests only with reviewed source, input and method equivalence, and describe which new assertions they do not cover. Inspect each actual image and preserve raw failures and active display readbacks.

## Lessons learned

A passing navigation test and a useful visual comparison need different evidence. Native adaptive navigation may expose a Back button outside the navigation bar. Targeted final-glyph and route checks close the actual remaining gaps without repeating the prediction model tests or all previously verified states. Existing execution and retry limits remain in force; a new test name or phase does not create another attempt.

Rule promotion: no `.claude/**` change. The existing evidence, ownership and retry rules already describe the reusable practice.
