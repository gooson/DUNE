---
tags: [swiftui, training-readiness, score-hero, dynamic-type, native-evidence]
category: architecture
date: 2026-11-03
severity: minor
status: implemented
related_files:
  - DUNE/Presentation/Activity/TrainingReadiness/TrainingReadinessDetailView.swift
  - DUNEUITests/Full/TrainingReadinessDetailRedesignTests.swift
related_solutions:
  - architecture/2026-11-02-wellness-score-detail-evidence-layout.md
---

# Training readiness contributions and trend controls

## Problem

Training Readiness needed a prominent score and a consistent visual treatment for all five contribution types. Its period, date range, trend controls and summary were separate sections, making the same period context harder to scan. Accessibility text also needed room for the factor title, weight, value and existing chart.

## Solution

The private detail now uses the existing opaque score palette and compact ring, with an external text score at accessibility sizes. Each of the five real contributions has its original symbol, model weight, actual score and horizontal score bar. The bar represents the component score out of100, not its weight or a population probability. Original score composition and calculation content remain available. Summary/highlights and the period/chart context form clearer groups without changing their bindings, calculations, history inputs, period choices, subscore charts or point selection.

The existing time-of-day card uses its adaptive layout. At accessibility sizes the main chart can use its existing scaled height rather than a fixed outer height. Decorative factor glyphs use a small fixed font in a wider slot at accessibility sizes and remain hidden from accessibility. The score model, use case, view model and refresh ownership are unchanged.

Native adaptive navigation may expose its Back button outside the navigation bar. The two existing normal/MAX test methods now prefer the existing hittable rail button and otherwise use their original navigation-bar query. Title, real tap and Activity-return assertions remain; normal also asserts detail disappearance. No general navigation abstraction or new test selector was introduced.

## Verification and limits

The current A02 app and relevant inputs match validation2ea9688d; its UI target actually compiled successfully. Both Duo normal cases passed once, including five preserved contribution weights, five period choices and real Back to Activity. Closed uses actual0°/LCD, open180°/LCD-1, with five strict capture acknowledgements per run. Their original top captures show score78/Moderate, night adjustment+6, component scores54/82/82/91/55 and weights30/25/20/15/10. Those values are examples from the existing seeded calculations, not fixed product data.

Historical iPad functional/normal evidence at2379 and final accessibility evidence at945d remain bounded by reviewed source/input closure. The final glyph change is primarily accessibility-specific; its ordinary clipped glyph slot also needs explicit visual/source review. Old iPad navigation receipts do not prove the newly added rail-query branch. Phone normal/MAX passed in one exact2/2 run; each method used actual native Back. Final scoped quality is PASS WITH NOTES, with only the documented architecture P3 deferred. Four canonical A02 rows and their Activity boards are now installed, preserving H03/T15/H02, other screens and Watch. Whole public and validation trees are not equal: a later additive ChangeBadge foreground override defaults to nil in this consumer, while an unrelated notification fallback is outside this flow.

Five independent code reviews found no P1/P2 findings. One architecture P3 notes that hero and legacy composition keep two copies of the same five-factor mapping. Current values match the use case. Extraction is deferred to keep this visual change local and preserve the legacy calculation presentation; no current scoring error is implied. Agent instructions and `.claude/**` are unchanged.

## Prevention

Keep the displayed score and bar semantics explicit. Preserve original period and selection bindings when regrouping their context. Reuse earlier positive results only after checking actual source, fixtures, device state and the assertions they executed. Capture a normal top viewport before lower-section probing; do not use a post-Back Activity screenshot as a detail comparison. Keep actual pose and original image bytes separate from inferred filename orientation.

## Lessons learned

A visual contribution summary can show score, model weight and type together without modifying the scoring pipeline. Large text can require a text score and chart-owned height while keeping the original content and navigation. Necessary final-device checks can reuse the established iPad functional matrix rather than automatically repeating five cases on every device. Historical failures and missing provenance remain explicit.

Rule promotion: no new `.claude/**` rule. The existing scoped validation, source closure, device ownership and actual-map rules apply.

Final evidence: the normal Phone viewport shows all five contributions, while maximum-text attachments separately show its initial hero, a scrolled tall-chart viewport and the final calculation paragraphs. The original attachment named “hero and trend” actually shows the scrolled trend; no whole-plot or all-factor-at-once claim is made. Historical iPad normal glyphs visibly fit their20pt slots, so the added clipping does not change that inspected normal top state. Native large titles ellipsize initially and become complete inline titles after scrolling. Existing global old-capture provenance remains dirty with exact per-image source/pose unknown; each old before still shows the correct Training Readiness screen.
