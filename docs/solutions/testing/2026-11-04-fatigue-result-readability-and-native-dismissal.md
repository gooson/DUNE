---
tags: [swiftui, dynamic-type, xctest, accessibility, fatigue, sheet, native-capture]
category: testing
date: 2026-11-04
severity: important
status: scoped-native-validation-complete
related_files:
  - DUNE/Presentation/Activity/Components/FatigueInfoSheet.swift
  - DUNEUITests/Full/ActivityExerciseRegressionTests.swift
  - DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift
related_solutions: []
---

# Fatigue detail: readable accessibility-size results and native sheet dismissal

## Problem

On source `b9634b5fb44323cecbdb02f66687c2abbb0374ca`, closed Duo normal and MAX both failed the original sheet-dismiss assertion after reaching the value and τ checks. Twelve downward swipes on the child scroll view did not close the expanded system sheet. Its actual hierarchy showed an accessible `Sheet Grabber` at the sheet's top edge.

Independent inspection of the same MAX run found a separate visible defect despite intact AX values: the displayed `0.02` occupied a 76.3 × 116.7-point frame and its digits wrapped vertically; “Fully Recovered” also fragmented. The result row's horizontal allocation could not accommodate the large text. Actual screenshots revealed a readability failure that existence and nonempty AX labels alone missed. The original 0/2 failure and its archive `.codex-checks/a14/evidence/duo-closed-b9634b5f-dismiss-and-max-layout-failed` are retained; the 1,848 raw bundle file hashes were independently verified during archival.

## Solution

`FatigueInfoSheet.swift` uses an accessibility-size vertical arrangement for result title, unbroken numeric score, level and τ; the standard-size arrangement remains horizontal. It retains the same data, calculation, level, τ and localization semantics. Result-level has a distinct accessibility identifier. The UI tests require the actual result value and level to be completely in the viewport and check the value's frame aspect ratio as a targeted guard. The aspect ratio is a heuristic, not proof of readable glyphs or a guarantee for other values, languages or text sizes: inspect matching actual PNG and AX.

The primary UI helper closes the actual native sheet using the observed unique, hittable grabber after checking the window and sheet-edge geometry. It retains the original child-nonexistence, parent-return and screenshot checks. No blind coordinate tap or product gesture change was added. The tests continue to check actual raw/decayed values, subtotal and modifier ranges, normalized chest result against `min(subtotal / 12, 1)` with display-rounding tolerance, and τ bounds based on the 96-hour chest base and actual rounded sleep/readiness modifiers. No calculation or domain service changed. The separate A03 inline route is intended to verify current child value visibility, dismissal and Back; it does not duplicate the primary numerical formula checks.

Corrected source `ec97aabe0b43cf225099c0c9dd2354a069548685` has an actual closed Duo normal/light plus dark MAX 2/2 pass, and open Duo normal 1/1 pass. Independent visual review of closed MAX observed `0.02` on one line, “Fully Recovered” as two intact words and τ `79h`; its AX and actual values matched the bounded math contract. Open normal's actual capture and dismissal were independently reviewed. The open-pose preparation set 180° once and observed a paired 180°/LCD-1 state on its first sample; this is a readiness observation, not an app pass or a claim about any prior mismatch's cause.

The remaining ec97 English normal cases passed on phone and iPad; the original Korean iPad inline case also passed at ec97. A subsequent current-source `bedf85663cf4997063e58a4b3d9e92224059f367` Korean iPad inline case passed with both translated headings and actual value/dismissal checks. Thus seven actual cases passed across the two revisions, not six new-head cases. The five ec97 English sheet cases remain historical receipts; the reviewed closure establishes bounded source and English-fallback equality, not a refreshed automatic test result. All four used device profiles were owned sequentially and removed. Original b963 0/2 remains a failure. Japanese rendering, other Korean profiles and text sizes, all themes/data states and VoiceOver speech or traversal remain unverified.

The localization issue was a separate inherited P3: two `LocalizedStringKey` section headings lacked catalog entries, so Korean showed the English fallback. Add manual en/ko/ja entries for the actual keys, verify no existing catalog entries change, and inspect the new Korean heading frames in a real current-source run. English source and fallback equality does not establish Japanese or other Korean rendering.

## Prevention

- Capture and inspect actual maximum-size result rows, including number, unit/status and τ, and compare them with the corresponding AX tree. Preserve full-frame checks, but do not treat an aspect ratio or accessible label as proof of legibility.
- Verify native dismissal through the observed system control and check both sheet disappearance and the real destination. A downward swipe in scrollable content is not evidence that the system sheet closed.
- Audit every `LocalizedStringKey` passed through a helper against the catalog, then verify changed locales and preserve exact source attribution.
- Keep formula assertions tied to displayed values and their rounding rather than hard-coded invented fixture values. Preserve the original failure archive separately from corrected-source results.

## Lessons learned

Accessibility geometry, visual typography, and sheet gestures answer different questions. An intact AX value can coexist with a badly wrapped visible number, while a content scroll can leave a system sheet open. Scoped native captures and actual user-facing dismissal checks made both failures observable without altering fatigue calculations. No new `.claude` rule or broad regression is needed for this bounded correction.
