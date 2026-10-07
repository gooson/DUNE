# Duo ship integration verification

Date: 2026-10-07
Branch: `codex/iphone-duo-experience`
Upstream integrated: `92c4a058146a48c40ec5dca10d6e4d34630c396b`
Integration commit: `bd02f2fa`

## Main synchronization

The DashboardViewModel conflict preserves both the DEBUG-only audit clock and main's forced daily digest path. Notification detail can request the digest before evening; ordinary dashboard loading retains its default behavior. Main's notification destinations and project registrations are included.

## Validation

- Xcode 27.1: DUNETests build-for-testing succeeded, including the integrated app sources.
- Filtered test-without-building on the dedicated iPhone Duo simulator: 49 tests in DashboardViewModelTests, NotificationInboxManagerTests and NotificationPresentationPlannerTests passed; xcodebuild exited 0. XCTest's zero count precedes the Swift Testing result and is not the actual executed total.
- A read-only PR reviewer inspected the synchronization delta and integration-critical window routing, workout rest activity, weekly plan and posture capture changes. No confirmed P1/P2 finding remained in those inspected paths.
- Previously fixed layout findings were reconciled against the current source and the scoped native evidence recorded in the linked reports. No known unresolved P1/P2 in that reviewed scope remains. Earlier findings superseded by fixes are not independent proof of current behavior.
- Existing six-file uncommitted changes were excluded from shipping and preserved in a recovery stash with a SHA256 manifest. Untracked native evidence was also excluded. No iPad window or focus was controlled.

## Evidence and limits

See [CLI fold validation](2026-10-06-duo-cli-fold-validation.md), [remaining route coverage](2026-10-06-duo-remaining-route-coverage.md), and [final app quality review](assets/2026-10-06-duo-remaining/reviews/final-app-quality-review.md).

These reports document selected Closed, Book and Open layouts, accessibility sizes, workout entry/rest/rotation flows, charts, forms, templates and share preview. Some passing test bodies encountered later SDK cleanup timeouts; they remain separately identified rather than reported as successful end-to-end commands. The final singular workout copy change has compile/catalog checks, with native evidence predating that copy change.

This is not a complete UI matrix or a full unit/watch suite certification. Physical camera/live operation, upgraded persisted scenes/sessions, VoiceOver audio, and every route/font/locale/theme/pose combination remain unverified.
