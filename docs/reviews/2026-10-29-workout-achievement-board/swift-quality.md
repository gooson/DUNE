# SwiftUI quality review — weekly workout board

Scope: read-only review of the approved **board** variant, layout proposal, `WorkoutAchievementBoard.swift`, `LifeView.swift` integration, board unit tests, action menu, and the linked UI assertions. No build, simulator, or source edit was performed here.

## Counts

Current open findings: P1: 0 · P2: 0 · P3: 0. Two findings resolved; one layout tradeoff accepted pending native evidence.

## Delta verification at HEAD `797b1e22`

1. **Resolved P2 — >12 completion semantics.** `WorkoutAchievementBoard.swift:138-154` keeps exact-count dots only through 12 and uses a continuous `ProgressView` with the actual completed/total values above 12. The new 12/13 model regression is at `DUNETests/WorkoutAchievementBoardTests.swift:64-70`. Static source review confirms the former all-filled 12-dot case is removed; test execution is outside this review.

2. **Accepted layout tradeoff — AX strength grid.** The adaptive scaled minimum (`WorkoutAchievementBoard.swift:59,364-365`) can yield one column at narrow accessibility widths. The approved implementation plan explicitly allows **two or one columns** for large text and regular half-width (`docs/plans/2026-10-29-workout-achievement-board.md:52-61`), superseding the browser proposal's two-column illustration. Native maximum-text capture remains necessary to check wrapping and clipping; this is no longer an open P3 finding.

3. **Resolved P3 — Week interval work.** The model and Monday week dates are stored during board initialization (`WorkoutAchievementBoard.swift:48-83`); header reads the stored values (`:116,171`). The previous computed calendar property is gone from the header/body path. `LifeView.swift:383-388` still provides day/time-zone refresh triggers.

## Checked without findings

- Menu keeps the existing 44-point action target and Edit/History/Archive actions (`LifeView.swift:741-755,762-831`); auto-linked goals do not gain manual past-record entry.
- Seven routine segments encode workout count, while both five- and seven-workout milestones remain visible (`WorkoutAchievementBoard.swift:291-341`). The service derives both from total workout count (`LifeAutoAchievementService.swift:89-95`).
- The board uses theme-backed colors rather than inline RGB values (`WorkoutAchievementBoard.swift:63-64,92-95`), and the running graphic is hidden from accessibility while the numeric progress is announced (`WorkoutAchievementBoard.swift:376-415`).
- Model tests cover grouping, denominator, bounded progress, missing groups, symbols, and the 12/13 fraction (`DUNETests/WorkoutAchievementBoardTests.swift:8-78`). They do not render the native layout.

## Limits

Static review only. Contrast, Dynamic Type wrapping, VoiceOver traversal, and half-width iPad/Duo geometry require the parent's planned device evidence. This report does not infer a build or UI-test result.
