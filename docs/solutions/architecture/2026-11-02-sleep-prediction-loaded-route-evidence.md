---
title: Sleep prediction visual hierarchy and loaded notification evidence
date: 2026-11-02
category: architecture
tags: [swiftui, sleep-prediction, dynamic-type, notification-routing, visual-evidence]
severity: moderate
status: implemented
---

# Sleep prediction detail and its loaded notification consumer

## Problem

The previous small confidence capsule did not give the prediction confidence a clear hierarchy. A translucent centered score and horizontal factor rows also needed more space at accessibility text sizes. The same detail is presented by a bedtime notification, but detecting its wrapper alone does not establish that a prediction actually loaded. A screenshot after Back shows the notification hub, rather than the detail.

## Solution

`SleepPredictionDetailView` now uses its own opaque score surface, the existing compact ring at ordinary text sizes, and a stacked text score at accessibility sizes. Confidence uses the actual low/medium/high enum with one/two/three qualitative marks; these are not probabilities. Existing outlook symbols, factor content and impacts, tips and empty variants remain. Decorative factor glyphs use a small fixed font within a larger slot so enlarged text does not overlap them. The prediction model and use case remain unchanged.

The T15 wrapper in `ContentView` is an accessibility containing group. Its identifier names the shared root, while score, guide and confidence leaf identifiers remain exposed. The same root cannot be required to expose both the wrapper ID and a second root ID. The existing default bedtime-route test waits for the computed score, guide and confidence leaves, confirms Today is selected, captures that loaded viewport, then taps the native Back button and verifies the hub return. It does not replace the computed result with a strict fixture. H03 uses the existing strict design fixture; its 78/two-factor view must remain distinct from the default computed T15 capture.

The H03 Back helper uses an existing hittable native rail button when available and the navigation-bar button otherwise. The native rail's accessibility rectangle is not assessed as a custom 44-point control. Existing window-bounds checks and actual return assertions remain.

## Verification and limits

The initial final-glyph UI target compiled at validation `59fdf60f`; relevant source and selected methods match public product commit `67e5ea09`. The final-glyph Phone maximum-text case passed once, including actual Back and disappearance of the detail. Prior Phone normal/confidence and iPad normal/maximum evidence is retained under explicit relevant-source closure; whole validation and PR trees are not equal. The ordinary default T15 historical image proves a loaded prediction, not the newly added Back assertions.

Duo closed/open route results and final quality review are complete. The [installed eight-pair gallery](../../design/full-redesign-map/review/h03-t15-sleep-prediction-native-2026-11-02/index.html) records actual pose readbacks, image hashes, loaded default scores, exact selected tests and original histories. No full local regression, repeated iPad matrix or Watch runtime is required for this private iOS layout change; existing CI remains enabled.

## Prevention

Capture a shared consumer only after its actual loaded leaf exists. Preserve the default route's inputs and distinguish strict design fixtures from live computed values. Select explicit pre-Back checkpoints; never infer a detail screen from a successful wrapper query or a teardown image. Reuse prior tests only with reviewed source, input and method equivalence, and describe which new assertions they do not cover. Inspect each actual image and preserve raw failures and active display readbacks.

## Lessons learned

A passing navigation test and a useful visual comparison need different evidence. Native adaptive navigation may expose a Back button outside the navigation bar. Targeted final-glyph and route checks close the actual remaining gaps without repeating the prediction model tests or all previously verified states. Existing execution and retry limits remain in force; a new test name or phase does not create another attempt.

Rule promotion: no `.claude/**` change. The existing evidence, ownership and retry rules already describe the reusable practice.

Closed Duo H03 passed inside a mixed 2/1/1 run. The default T15 first failed before tapping a virtualized row; a scoped bounded reveal corrected that failure. Its conditional retry then loaded score72/Good/Medium but exposed an incorrect test assumption about a second root ID. That assertion is corrected to mandatory actual guide and confidence leaves, preserving wrapper/score/Today/capture/Back/hub checks; target compile passed at02cc8c81. Both original failures remain, and no Back success is inferred from the loaded failure screenshot. The explicitly approved additional T15 execution passed once, including actual Back, hub return and Today selection; its remaining allowance is zero.

Final outcome: five necessary new positive UI cases (Phone MAX1, closedH03normal1, openH03/T15normal2, closedT15normal1), with both earlier T15 failures retained. Closed uses actual0°/LCD and open180°/LCD-1. All eight canonical H03/T15 rows and their two board groups are installed; other rows/images, H02 and Watch remain unchanged. Final scoped quality has P1=0/P2=0/P3=0. Product67e5 iOS CI build and2734 Swift tests/302 suites plus12 XCTest cases passed. Its Watch job failed before test execution because cloning failed and destination ID was empty; this is preserved as PRETEST failure, not Watch PASS. No new prediction logic or local full/Watch execution was required.
