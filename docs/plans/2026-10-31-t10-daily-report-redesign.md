---
topic: T10 daily health report redesign
date: 2026-10-31
status: approved
confidence: high
related_solutions: [docs/solutions/architecture/2026-03-29-today-phase2-enhancements.md, docs/solutions/architecture/2026-10-28-vital-card-history-observation.md]
related_brainstorms: []
---

# Implementation Plan: T10 Daily Health Report

## Context and research

The approved T10 proposal (`.codex-checks/t10/reviewed-proposal.json`) turns the notification destination from a compact summary into a report with clear condition, activity, sleep, and narrative sections. The current destination (`DailyDigestNotificationView`) delegates condition, steps, workout narrative, and full-summary disclosure to `DailyDigestCard`, adds a separate sleep card, and keeps authorization/loading/no-data states. Notification routing owns push/back. The existing T10 actual PNGs predate this change and cannot prove it. Existing daily digest summaries and scores come from `DashboardViewModel` and `DailyDigest`; this work must not synthesize measurements or alter queries.

## Requirements

- Present a coherent report cover and distinct sections for observed condition, steps/workout, sleep, and the generated daily narrative. Preserve original SF Symbols, every recorded metric, the original summary text and disclosure, navigation, loading, permission failure, and empty states.
- A metric section appears only when its source value exists. Never draw a quantitative looking graph from decorative fixed data. Keep partial-data content usable.
- Use DS color, typography, card, spacing, dark mode, Dynamic Type, VoiceOver, and Reduce Motion conventions. Localize new user-facing text in en/ko/ja with manual string catalog entries.
- Preserve notification entry and back routing; do not add prototype-only state controls to production.

## Approach

Build a report-specific composition in `DailyDigestNotificationView` while retaining the existing shared dashboard card elsewhere. The report reads `DailyDigest.metrics` and presents measured values directly. Reuse `DailyDigestSummaryText` for disclosure. Use static symbolic artwork with SF Symbols and semantic DS colors; no invented score ring or charts.

| Alternative | Decision | Reason |
|---|---|---|
| Redesign `DailyDigestCard` globally | Reject | Would change the Today dashboard consumer outside T10. |
| Copy prototype state tabs into app | Reject | No such debug controls exist in the native destination. |

## Affected files

| File | Change |
|---|---|
| `docs/plans/2026-10-31-t10-daily-report-redesign.md` | Plan and verification contract |
| `docs/design/layout-map/daily-report-proposal.md`, `docs/design/layout-map/index.html` | T10 layout contract and index |
| `docs/design/theme-map/themes/dune-daily-report.html`, `manifest.json`, `README.md`, generated `index.html` | Preserved visual study and theme map |
| `DUNE/Presentation/Dashboard/DailyDigestNotificationView.swift` | T10-only report composition |
| `Shared/Resources/Localizable.xcstrings` | New en/ko/ja copy only |
| `DUNEUITests/Full/NotificationRoutingRegressionTests.swift` | Focused route, disclosure, and state assertions |
| `docs/design/phone-design-map/actual/*/images/T10.png` and capture indices | Refresh affected actual screens after simulator execution; never reuse old PNGs as new evidence |
| `.codex-checks/t10/implementation-state.json` | Truthful handoff ledger |

## Steps and proof

1. Save this plan. Read the original T10/source, DS/UX/localization rules and related solutions. Create the T10 layout map and preserved theme study, register them in their indices, and run the theme-map generator/check. **This precedes app edits.**
2. Implement the report-specific layout using existing data and state branches. Ensure the workout label and full source sentence stack at accessibility sizes, duplicate decorative section artwork disappears at those sizes, long narrative text wraps without truncation, and illustration stays decorative for VoiceOver.
3. Add manual catalog keys, run `swift scripts/format-xcstrings.swift`, then `swift scripts/format-xcstrings.swift --check --check-manual` before and after the eventual build.
4. Add focused UI assertions on seeded notification response and deferred readiness. Inspect `git diff --check`, catalog/theme checks and source parse. Do not call build/unit/UI/simulator or commit in this delegated source-only phase.
5. Parent-owned verification: one scoped iOS build, exact UI selectors `NotificationResponseRoutingUITests/testNotificationResponseOpensSummaryAndBackReturnsToToday`, `DeferredDigestNotificationRoutingUITests/testSummaryWaitsForHealthKitReadinessWithoutShowingEmptyState`, and `TodayReadingUITests/testNotificationDigestReportPreservesDataAndDisclosure`. Use the standard runner with worktree-owned simulator, jobs 2, index store off, parallel tests off, and owned process deadline. Do not run full regression. Capture actual T10 on affected iPhone, iPad, Duo folded/open states, including dark and max Dynamic Type as feasible, then update capture indices; this remains pending until real PNGs exist.

## Risks and limits

- The shared card remains a Today consumer; report-specific disclosure must preserve its first-sentence preview semantics while not altering the dashboard card.
- Test fixture values are observed seeded data only. Dynamic content and partial data can change section height; verify full title and frame visibility rather than requiring long paragraphs to fit one viewport.
- Scope is T10 iOS destination. Watch has no T10 view. The actual map cannot be marked current until new native captures are produced.
