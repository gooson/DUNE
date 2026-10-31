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
