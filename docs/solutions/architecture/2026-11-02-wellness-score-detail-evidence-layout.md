---
tags: [swiftui, wellness-score, optional-data, dynamic-type, charts, native-navigation]
category: architecture
date: 2026-11-02
severity: minor
related_files:
  - DUNE/Presentation/Wellness/WellnessScoreDetailView.swift
  - DUNEUITests/Full/WellnessScoreDetailRedesignTests.swift
related_solutions:
  - architecture/2026-11-02-stored-notification-message-reading-layout.md
---

# A wellness detail hero that preserves the score and its evidence

## Problem

The existing wellness detail displayed the score, four optional component values, time-of-day effect, trend controls, summary and calculation cards with little visual grouping. The redesign needed a stronger hero and a single readable trend section without changing the score, source data, chart behavior or explanations.

Maximum Dynamic Type also exposed the difference between a decorative SF Symbol's intrinsic size and its small evidence-row slot. Enlarging the symbol with the surrounding text could clip it. On Duo the native Back control lives in the rail, so a navigation-bar-only test query did not represent the actual control.

## Solution

Keep the change local to `WellnessScoreDetailView`. `H02WellnessDetailHero` receives the original `WellnessScore`, uses the existing opaque hero palette and ring, and keeps the model's status, symbol, narrative and evaluation date. At accessibility sizes show the score outside the ring and stack the evidence. Decorative component symbols use a fixed16-point image in a26-point clipped slot at these sizes; their full metric labels remain readable.

The four component rows retain `Int?` values. A missing value remains an unavailable dash and an unfilled track. Clamping the display bar to0–100 does not replace a measured value or treat nil as zero. Keep the existing35/30/20/15 composition explanation, missing-weight normalization and every conditional contributor/body/condition calculation card.

Put the existing D/W/M/6M/Y picker, visible range, trend toggle, chart/empty branch, summaries and highlights in one `StandardCard`. Retain chart selection, scroll-position/domain and baseline bindings, plus non-day subscore charts. Use the existing adaptive time-of-day card and680-point reading width. The ViewModel, use case, models and storage/query consumers remain unchanged. Do not add period-step APIs that the original ViewModel does not supply.

For the normal UI test, prefer the existing hittable native `BackButton` rail and fall back to the original navigation-bar query. Keep the actual tap, Wellness-root return and detail-absence assertions. A screenshot that merely shows Back is not navigation coverage.

## Verification and evidence limits

The original Phone five-case run remains a mixed failure: two cases passed and three failed. Its same-ID conditional retry passed the three corrected interaction cases; preserve both records. The historical normal Phone capture is tied to its precise passed node, not to an all-PASS group. The later glyph-only accessibility change does not alter that normal branch.

The Nov2 iPad normal and dark/MAX cases passed at e83's exact241 tree. Fresh Duo closed/open normal cases each passed at validation6bfe with the reviewed native Back query, actual score/component equality and actual return. Each pose has four acknowledged captures, SDK angle and active-display readbacks; the selected detail is checkpoint2, not the post-Back root. The first closed preparation failed before test dispatch while angle0 and activeLCD-1 disagreed; preserve that0-test failure and its same-ID single conditional retry after actualLCD recovery.

Morning iPad93 and evening Duo87 are actual time-dependent scores with the same available component values99/90/75/unavailable and different adjustments. They are not identical runtime records or the prototype81. Source closure is limited to relevant product/test/consumer/catalog inputs, not a whole-tree claim. The final-glyph Phone dark/MAX case also passed exactly once at6bfe. Individually reviewed original PNGs show the external87, complete component symbols/labels, visible range/period controls and final calculation paragraphs. Its native large navigation title uses the existing ellipsis behavior before collapsing to the full inline title; the raw full-method screenshot name does not mean every paragraph fits simultaneously. MAX does not tap Back; fresh Duo normal cases provide that return proof. Final publication and CI status remain separate evidence.

## Prevention

- Keep missing health values distinct from zero and derive status and icons from the supplied model.
- Preserve period, chart-selection and calculation behavior when consolidating visual sections.
- Check exact original PNGs and test nodes; correct a mistaken image interpretation without changing the image or inventing a rendering defect.
- Verify both hinge angle and active display before accepting Duo captures. A recovered dependency does not erase a pretest failure.
- Reuse valid narrow evidence across phases and change only the native control query that the platform actually requires.

No scoring rule, seed flag or instruction-source change is needed for this presentation work.

## Lessons Learned

A stronger hero can expose the same score more clearly while preserving every source and optional-data branch. Actual source/date/state provenance is as important as visual alignment when the live score and time-of-day adjustment differ between captures.
