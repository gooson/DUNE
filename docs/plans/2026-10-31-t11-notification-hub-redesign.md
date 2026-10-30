---
tags: [design, notification, t11]
date: 2026-10-31
category: plan
status: approved
confidence: high
related_solutions: [2026-03-03-notification-inbox-routing, 2026-03-08-notification-root-push-from-current-screen]
---

# Implementation Plan: T11 Notification Hub

## Context and research

The approved T11 proposal covers the existing `NotificationHubView` only. The source has one `List`, a combined health and release unread count, All/Health/News filtering, read all, settings, destructive confirmation, swipe read/unread and deletion, latest-first health rows, and local routing. The existing [notification inbox layout contract](../design/layout-map/notification-inbox-proposal.md) and DUNE theme map set the baseline. Existing T11 actual PNGs are historical baseline, never evidence for this implementation. Routing solutions in `docs/solutions/architecture/` require the Today-owned push and notification navigation to remain intact.

## Requirements

- Make the unread status prominent using only `combinedUnreadCount`; keep read all, settings, and delete all accessible and honest for zero items.
- Keep a clear native segmented All/Health/News filter and one icon-leading row per health insight and release.
- Preserve stored order, payloads, release version/intro, read state, routes, swipe actions, and empty states. Do not add store writes or guessed values.
- Support light/dark, large Dynamic Type, Reduce Motion, VoiceOver, iPhone, iPad, and owned Duo postures.
- Leave `NotificationMessageDetailView` (T12) and `NotificationDestinationUnavailableView` (T13) unchanged even though they share the source file.

## Approach

Keep the native `List` and existing data flow. Strengthen the existing status card with prominent unread text and clear action hierarchy. Use the existing design tokens and original insight glyphs. At accessibility sizes, put each original glyph before the title/date header and give the health body and release intro the full card width below it. The health body has no line limit at accessibility sizes. Stack the status icon above its text at accessibility sizes. No new localization strings are needed.

| Alternative | Decision | Reason |
|---|---|---|
| Rebuild as a custom scroll view | Reject | Would weaken native swipe and list semantics. |
| Add decorative chart or counts by filter | Reject | No source for those values. |
| Keep current layout with spacing only | Reject | Does not establish a readable status/row hierarchy. |

## Affected files and steps

| File | Change |
|---|---|
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | T11 presentation only |
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` | Focused dark/max AX row geometry and reachability assertions |
| `docs/design/layout-map/notification-inbox-proposal.md`, `index.html` | Layout contract and discovery link |
| `docs/design/theme-map/themes/dune-notification-hub-redesign.html`, `manifest.json`, `README.md`, `index.html` | Preserved proposal and generated index |
| `.codex-checks/t11/implementation-state.json` | Source and pending verification ledger |

1. Update `docs/design/layout-map/notification-inbox-proposal.md`, layout index, and preserved theme map manifest/README/index before app edits. Document the T11 native layout contract and distinguish proposal from actual captures.
2. Edit only the T11 part of `DUNE/Presentation/Dashboard/NotificationHubView.swift`. Keep all mutations, destinations, filtering, and empty copy. Add status count emphasis, filter labeling, icon-leading rich rows, and large type fallback.
3. Source check: confirm shared T12/T13 structs and all action branches are unchanged, inspect diff, parse JSON, run theme map sync check, and inspect string catalog format without catalog edits.
4. Parent-owned verification: focused existing UI selectors on the real Today entry and the health/news/empty/read-all/delete flow, plus dark and maximum accessibility size reachability. Capture new actual T11 PNGs for affected iPhone, iPad, and Duo states; never reuse baseline PNGs.

## Verification contract and budget

| Changed behavior | Exact existing selector | Device/state | Exit condition |
|---|---|---|---|
| Today entry, initial status and visible controls | `DashboardSmokeTests/testNavigateToNotificationHub()` | owned iPhone regular | title and controls fully visible |
| Filter, read all, delete confirmation, empty | `TodaySettingsRegressionTests/testNotificationHubControlsTransitionToEmptyState()` | owned iPhone regular | all state transitions pass |
| Empty without seed | `TodaySettingsRegressionTests/testNotificationHubShowsEmptyStateWithoutSeed()` | owned iPhone regular | honest empty state |
| Maximum accessibility layout and dark colors | `DashboardSmokeTests/testNotificationHubSummaryAtMaximumAccessibilitySize()` | owned iPhone dark + max AX | status/actions/filter, health title and complete body, release title and complete intro visible; body/intro start left of title, within viewport |

Parent may add one dark-state and Duo/iPad focused visual selector where needed for new actual captures. Use the standard UI runner, one owned simulator at a time, jobs 2, index store off, no parallel testing, 1200-second targeted UI deadline. Reuse successful compilation evidence; no unrequested full suite. This source-only child executes no build, unit, UI, simulator, capture, or commit.

## Risks and boundaries

| Risk | Handling |
|---|---|
| Long title/date or unread badge crowding | Vertical metadata at accessibility sizes; parent verifies max AX. |
| Release and health row mismatch | Same icon-leading anatomy without changing release payload or order. |
| Shared source T12/T13 drift | Diff exact range and compare their declarations to base. |
| Device visual result unknown until runtime | Keep native capture and verification pending in implementation ledger. |

## Confidence

High for source scope and behavior preservation; native layout confidence remains pending the parent-owned captures and focused UI results.
