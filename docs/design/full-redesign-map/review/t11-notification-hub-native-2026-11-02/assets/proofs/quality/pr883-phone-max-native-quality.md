# PR883 Phone maximum-text native quality

## Summary

One reviewer applied three distinct lenses: SwiftUI layout, Apple UX, and UI-test quality. This is one review, not three agents. P1/P2/P3 actionable findings: 0. No UI testing issues found in the reviewed scope.

Evidence: parent-reported approved extra Phone run, validation `ae2598a6`, `DashboardSmokeTests/testNotificationHubSummaryAtMaximumAccessibilitySize` PASS 1/1. Read the attachment manifest and five named original PNGs under `.codex-checks/t11/evidence/pr883-phone-max-approved-extra-final-2026-11-02`. Manifest identifies iPhone18 Pro Max, 1320×2868 captures, dark maximum accessibility text. No execution was performed here. Original failed `t11-ui-hub` record remains preserved; approved extra consumed1/remaining0. This review authorizes no further runtime.

## Findings

None.

## SwiftUI lens

The summary stacks its icon, multiline unread state and Read All action, leaving settings/more controls on a separate row. `5B16C33F` shows the full two-line unread state, full Read All label, separate gear/menu, and all three native segments within horizontal bounds. Content respects card margins rather than narrowing the body into the icon-leading header column.

`DEE81A54` shows Health selected and the complete two-line Sleep Debt Alert title beside the original sleep symbol. Time and Unread status are on separate lines, without title/time competition. Its body continues below the visible area. `6AD257BC` intentionally scrolls that same row upward, exposing the complete wrapped body “You slept6h20m last night. Prioritize recovery today.” and Sleep Detail destination hint across the full card width. The displaced title beneath/above navigation is normal scroll continuation, not a clipping finding.

`B2829268` shows News selected, the complete What's New title and version beside its original sparkles symbol. `5E9E5542` is the corresponding release-intro checkpoint; the source permits full vertical intro growth and positions it below the icon/title header across the card width. The existing test's partial-readable-body contract does not require an entire long release intro to fit one screen. No horizontal title/body truncation or overlapping controls was established. Large-image tool presentation alone is not used to infer a rendering defect.

## Apple UX lens

The dominant unread status and Read All action provide a clear summary hierarchy. The native segmented All/Health/News control remains a single recognizable filter with selected-state feedback. Read All, settings and more are visually separate actions; the gear and overflow symbols retain their conventional roles. Original category symbols, text Unread indicators and destination hints avoid relying on a colored dot alone. Cards have consistent alignment and spacing, while the scrollable List accommodates large text. Standard native back/title and bottom tab controls remain visible.

This is visual/source assessment, not a VoiceOver session, measured contrast certification, or interaction test of gear/menu/back/swipe actions. No external HIG compliance certification is claimed.

## UI-test lens

Current targeted method goes beyond screenshots/existence: it checks front list ownership, complete viewport/hittable containment and >=44pt height for settings/Read All, non-overlap, three native segments and horizontal visibility, actual Health/News taps with selected-state assertions, complete title visibility, and readable body portions below the toolbar/above tabs. It also checks body/intro leading edge extends left of the icon-leading title and retains nonempty text. Existing navigation/toolbar coverage remains separate; this targeted PASS does not prove every action or all inbox states.

No assertion was replaced by screenshot success. Missing-element handling in the bounded ten-attempt reveal helper chooses an explicit direction before querying frames, and gestures stay within the front list viewport. The actual named checkpoints corroborate title/body movement and filter selection rather than claiming all content is simultaneously on-screen.

## Source validity and scope

Read-only comparison of the current T11 worktree, parent-identified `bfed`/`7be` lineage, against validation source confirms equality only for the relevant hub prefix before `private struct NotificationMessageDetailView` (753 lines). SHA-256 of that prefix: `70c59efd9d8730ab310cf23419b0818ab52a057be078c90fd8ef484b76dbad44`. MAX method plus private reveal helpers also match: SHA-256 `ad58e5c116f8cf14a80de497855e95c327e2e3aa82beb47933caf5fafa05489b`.

The full NotificationHubView.swift files have different lengths (T11 810 lines; validation880) because the tail also includes T12/T13 work. No whole-file equality, T12/T13 validation, or independent Git commit verification is claimed.

## Missing Test Cases

None newly required for the changed T11 maximum-text behavior on this reviewed Phone configuration. No new/full UI or generic regression recommendation follows from this review. Normal-size, iPad, Duo, empty-state, read/delete persistence and route behavior require their own existing source-scoped evidence; they are not established by this one Phone method.

## iPad-Specific Risks

No iPad run or sidebar interaction was examined here. This Phone evidence covers bottom-tab native List presentation only and does not imply iPad or Duo completion.

## Coverage Rating

Adequate for T11 Phone dark maximum-text summary/filter and health/release title/body layout. Original failure and approved-extra ledger remain intact. Runtime: authorized available GPT-6.1 Sol medium fallback. No tests/builds/devices/CI/Git operations, source edits or new agents were used; only this `/private/tmp` report was written.
