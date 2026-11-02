---
topic: T14 notification workout target fallback
date: 2026-10-31
status: approved
confidence: high
related_solutions:
  - architecture/2026-03-03-notification-inbox-routing.md
---

# Implementation Plan: T14 Notification Target Not Found

## Context

A notification can refer to a workout that is no longer available locally. The existing fallback preserves the route and ID, but its centered stack has little visual hierarchy and can clip at large text sizes. T14 in the full redesign map calls for a single readable detail column on iPhone, iPad, and Duo.

## Requirements

- Preserve `exclamationmark.magnifyingglass`, “Exercise not found”, the existing explanation, the selectable actual `workoutID`, and native “Notification” navigation and Back behavior.
- Do not invent a workout, retry action, cause, status, or count. Preserve the Activity and inbox routing code.
- Use theme-aware opaque hero color, Dynamic Type, scroll, and a capped decorative symbol. Text and the ID must remain reachable at maximum accessibility size.

## Approach

Use the existing `ScoreHeroPalette` inside `NotificationTargetNotFoundView`, a native `ScrollView`, an opaque title card, and a separate ID region. Center the content within a bounded reading width. Keep the original symbol decorative and keep each text element separate in the accessibility tree.

| Alternative | Decision |
|---|---|
| Add a Go Back or Retry button | Rejected: the existing native Back action is sufficient; retry has no behavior. |
| Reuse the centered fixed-height stack | Rejected: it cannot reliably reveal long text or ID at maximum Dynamic Type. |

## Affected Files

| File | Change |
|---|---|
| `DUNE/Presentation/Shared/NotificationTargetNotFoundView.swift` | Screen-only composition and identifiers |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | Exact missing-workout and dark maximum-text checks |
| `docs/design/layout-map/notification-target-not-found-t14.html` | Responsive layout contract |
| `docs/design/theme-map/themes/dune-notification-target-not-found-t14.html` | DUNE direction study, not an app capture |
| Design map indexes and manifest | Link the T14 contracts |

## Steps and Verification

1. Save layout/theme contracts and index links before app edits; validate links and theme map generation.
2. Implement the scrollable fallback while preserving text, symbol, ID, and native navigation; source parse and scoped build are required after the source is frozen.
3. Extend the existing missing-workout route selector and add one dark maximum-text selector. The parent owns native iPhone, iPad, and Duo captures and the actual T14 design-map refresh.

## Risks

- A parent accessibility identifier can mask child text IDs. Put any new group ID on an element with `.accessibilityElement(children: .contain)`, and keep the root ID on the native scroll container.
- iPad top tabs must not be treated as a bottom viewport obstruction in UI geometry checks.
- Theme-map artwork is a source contract, not proof of the final app; actual-device PNGs remain pending.


## Resumed minimum verification — 2026-11-02

Actual main9b90ad2b preserves completed T11–T13. T14 app file5d0f is byte-identical to d310/8e6/validation3fac. Relevant normal/MAX, row-reveal, fallback viewport/text, hub entry, Back helper and seeded base class are identical to8e6/3fac; the whole Activity test file differs. Normal remains exact d310 passed source. The old8e6 TEST BUILD SUCCEEDED log was copied and hashed before precommit artifact cleanup.

Authoritative t14-ui-missing-workout/check-b4830a6483d594d8a900cdf2 keeps two FAILED attempts: startup2/0/2, then repaired-session2/1/1 with only normal passed and dark missing-row entry failed. Reuse the precise normal node, never the mixed group as PASS. The fixed dark source is compiled, not yet natively passed. Global ledger has the user's original T14 approved extra1/consumed0; T11 consumed1/remaining0 is separate. Older pending-exception prose is historical, not current authority.

Use exactly one guarded original Phone dark/MAX selector after infrastructure readiness only. Verify raw ID/history/hash, fixed clean source and owned device; exclusively mark consumption and atomically debit the existing slot before standard-runner dispatch. No refund/repeat under another ID, no original history/reset/executor modification. A linked exception receipt records only the authorized extra. Existing normalPhone is not rerun by that allowance. Add only iPad normal1 and Duo closed/open normal1 each, strict SDK/active-LCD/ACK evidence, one owned device at a time. All new native results/maps/Compound/ship remain pending at this checkpoint.

Coverage stays explicit: normal verifies exact title/message/workoutID and actual visible fallback, but does not tap Back despite the screenshot caption. Only MAX performs actual native Back-to-Activity. The normal wide cases do not claim exercised navigation. No speculative checkpoint/back patch, added unit/full UI/Watch or duplicate standalone build.

Five source reviews and UI test-design/source quality found P1=0/P2=0. One P3 maintenance tradeoff is explicitly deferred: factoring the three viewport helpers would touch already merged T12/T13 tests and alter the reviewed pending-MAX source for no behavior defect. Keep this PR screen-scoped and preserve its evidence; no source fix/retest is needed for that maintenance suggestion. Theme union10/24, links, Swift parse and exact source closure passed.
