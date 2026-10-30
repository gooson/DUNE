---
tags: [score-detail, fixed-window, raw-summary, refactoring, swift-testing]
category: architecture
date: 2026-10-30
severity: minor
related_files:
  - DUNE/Presentation/Shared/Detail/ScoreDetailHistory.swift
  - DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift
related_solutions:
  - 2026-10-30-condition-detail-redesign.md
---

# Solution: Share the tested score history contract

## Problem

T04 had validated fixed-duration window and raw-point summary logic inside its ViewModel. T05 needed the same rules; copying them would allow future page boundaries and summary behavior to diverge. Existing callers and meaningful edge tests already used the T04 static methods.

## Solution

Move exactly the two existing bodies to a Foundation-only `ScoreDetailHistory` enum in Presentation/Shared/Detail. Keep T04 static signatures as delegates, forwarding Calendar and all inputs. Add iOS project membership through the standard regeneration script. No protocols, state, query policy, Domain calculation, UI, or new algorithm is introduced.

| File | Change / reason |
|---|---|
| ScoreDetailHistory.swift | One shared fixed-window and half-open raw summary implementation |
| ConditionScoreDetailViewModel.swift | Compatibility delegates preserve callers and existing tests |

The current window includes today, pages remain contiguous, and raw samples are summarized before plot aggregation. Existing26 boundary tests plus2 selected UI checks confirm the extraction. Full suites are not claimed.

## Prevention

- Share the same window/summary contract in T05 and later score details rather than duplicating it.
- Preserve default Calendar, finite-positive duration guards and half-open current/prior filters when extracting.
- Classify verification by actual caller graph and target membership; a Shared path is not proof that Watch uses a file.
- Keep a failed before-detail chart assumption and a stalled result cleanup separate from successful changed-path evidence. Do not repair unrelated app/test code to force an otherwise unrelated smoke assertion green.

## Lessons Learned

A small shared contract can preserve validated behavior without a new framework. Existing meaningful tests should continue to exercise the compatibility entry points; new tests that merely repeat an extraction are unnecessary. A test-plan name does not establish full coverage: record the exact selectors and completed receipt.
