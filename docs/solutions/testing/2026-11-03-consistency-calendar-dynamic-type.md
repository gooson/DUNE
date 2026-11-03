---
tags: [swiftui, dynamic-type, calendar, accessibility, lazy-grid, native-ui-testing]
category: testing
date: 2026-11-03
status: reviewed
severity: important
related_files:
  - DUNE/Presentation/Activity/Consistency/ConsistencyDetailView.swift
  - DUNEUITests/Full/ActivityExerciseRegressionTests.swift
  - Shared/Resources/Localizable.xcstrings
related_solutions: []
---

# Consistency calendar: keep two-digit days readable at maximum text

## Problem

At the maximum accessibility text size on the closed Duo, the seven flexible calendar columns narrowed two-digit days until each digit wrapped vertically. The `9e77710a` original MAX selector failed: the day-28 accessibility leaf was 25.17 points wide while the matching caption2 monospaced digits required 49.10 points. The active-display PNG also shows the vertical digit split. This was a real displayed defect, not a test threshold problem.

Earlier, the normal test found its actual monthly `3/16` value under the calendar parent's identifier; history leaves inherited their parent identifier too. At MAX, another attempt failed before reaching the calendar because the lazy day rows had not been exposed when the test demanded existence. These observations are separate from the eventual glyph defect.

## Solution

`ConsistencyDetailView` retains the seven flexible columns for non-accessibility text sizes. At accessibility sizes it uses seven caption2-scaled fixed-width columns inside a native horizontal scroll, so weekday headers and dates remain aligned and text keeps its full Dynamic Type size. Calendar and history use explicit accessibility containers to preserve their child identifiers. The MAX monthly-progress header stacks its existing icon, title and real count when width is constrained.

The focused selector first reveals lazy rows within bounded scrolling, then verifies each real date/value and the full leaf frame. It also checks a two-digit day against the UIKit caption2 font's measured width and single-line height, captures both ends of the horizontal calendar, and verifies Back. The app's HealthKit/manual merge, individual 20-minute qualifying rule, streak calculations, original icons and view model are unchanged.

The historical `3c5b652e` closed-Duo MAX run passed its exact selector 1/1 with nine valid acknowledged host checkpoints and 0°/LCD readbacks. The independent native review observed full two-digit dates at both horizontal positions; it found no P1/P2, and recorded pre-existing English `1 days` as P3. `fa4ba738` corrects that single-day history copy (`1 day`, `1일`, `1日`) while retaining the existing plural expression for other counts. The later fa4 open-Duo normal 1/1 capture visibly shows `1 day` and has seven valid acknowledged checkpoints with 180°/LCD-1 before and after. These are distinct source revisions and states.

The earlier `be23b071` closed normal test passed within a mixed run that failed overall (one normal pass, one MAX failure). Reuse is limited to the independently compared non-accessibility content/layout, excluding pixel identity and the subsequently corrected English singular text; it is not a fresh fa4 capture or a 2/2 pass. Failed 30b/be23/9e results and the actual raw records remain preserved. A separate pre-UI wrapper/approval problem executed zero UI tests and is not a test result. Raw boot/migration warnings remain disclosed without asserting repair.

## Verification

The original normal selector passed on four required profiles: closed Duo at be23 (the single passed case inside the failed mixed bundle), and open Duo, iPhone and iPad each 1/1 at fa4. The original closed-Duo MAX selector passed 1/1 at 3c with nine acknowledged checkpoints. Native reviewers inspected all selected-profile PNG/AX evidence. Historical source/copy limits above remain; this is not a uniform fa4 five-case run.

The actual fa4 Phone and iPad cases passed 1/1 and their seven paired PNG/AX checkpoints per profile show full calendar numerals, actual streak/progress/history and corrected `1 day`. The same copy is visible in fa4 open-Duo evidence. All task-owned devices were deleted sequentially after sealed evidence and native review; no foreign device was touched.

Actual fa4 CI [Build iOS](https://github.com/gooson/DUNE/actions/runs/41599085729) and [Unit Tests](https://github.com/gooson/DUNE/actions/runs/41599085708) succeeded. The view model, query and service were unchanged; no redundant local full suite was added. The [source-aware actual gallery](../../design/full-redesign-map/review/a11-consistency-native-2026-11-03/index.html) retains each capture revision and original image/AX joins. Nineteen existing map outputs were checked separately from the new gallery, with unrelated rows preserved.

## Prevention

- Exercise a real two-digit calendar day at the largest supported text size, using measured glyph and viewport bounds as well as native screenshots.
- Reveal a lazy row before asserting its existence; retain bounded movement and value/geometry assertions.
- Review accessibility parent/child identifiers in an actual hierarchy rather than assuming child IDs survive a container ID.
- Preserve per-case outcomes and capture revisions when a mixed run is reused; source comparison cannot establish pixel identity.

## Lessons Learned

A test can pass source review yet fail on actual narrow columns, and a test can fail before a lazy view is materialized. The useful correction required both the real rendered glyph evidence and separate accessibility/navigation diagnosis. Native inspection remains necessary for wrapping, contrast and VoiceOver behavior; this record makes no universal accessibility claim.

VoiceOver speech/traversal, every locale/state and measured contrast were not established by these screenshots or AX dumps. Original failures and zero-case setup/postprocessing errors remain distinct from passed native tests.
