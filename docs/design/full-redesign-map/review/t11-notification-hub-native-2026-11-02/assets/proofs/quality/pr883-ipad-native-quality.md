# PR883 iPad normal native quality

## Summary

One reviewer applied SwiftUI, Apple UX and UI-test-expert criteria to existing iPad normal-size controls evidence. This is one review with three lenses, not three agents. P1/P2/P3 actionable findings: 0. No UI testing issues found within the reviewed scope.

Parent reports validation `ae2598a6`, `TodaySettingsRegressionTests/testNotificationHubControlsTransitionToEmptyState` PASS1/1. Read seven original PNGs and attachment manifest in `.codex-checks/t11/evidence/pr883-ipad-hub-controls-final-2026-11-02`, plus the existing method and `auditTap` helper. Manifest identifies iPad Pro13-inch(M5), 2064×2752. No execution or device action was performed here.

## Findings

None.

## SwiftUI lens

- `B9214C4F`: Today root after setup. It establishes launch context, not a T11 hub-after image.
- `0F200A67`: valid hub initial All state after tapping the dashboard notification control. Summary shows3unread, with Read All/settings/more separately positioned. Native All/Health/News filter, release card and both health rows are fully visible. Headers, timestamps, bodies and destination hints fit without horizontal truncation or overlap. Rich row body starts below the icon-leading title area, retaining the available card width.
- `8FEC4C34`: Read All result shows caught-up status, disabled Read All, same release and two health items, with Unread labels removed. Layout remains aligned as unread labels disappear.
- `0C46EF0A`: more-menu Delete All action appears over the summary area; native menu presentation keeps the action label legible.
- `23EB49AC`: destructive confirmation popover contains full title, explanatory message and red Delete All action. Content fits within the native popover. This is the confirmation-visible frame.
- `B05F4AE7`: post-confirmation state, not confirmation-visible. Health rows have been removed while the read release card remains in All. Its filename names the preceding tap; it must not be labeled as the dialog itself.
- `8E1EFBF6`: Health selected with No Notifications empty state. It is Health-empty after deleting health notifications, not a completely empty combined inbox. Release remains available outside this filter.

The captured iPad keeps a bounded readable content column, native navigation/back control, and top tab/sidebar affordance. No new responsive layout defect was established. Large-image tool presentation alone was not used to infer transient rendering defects.

## Apple UX lens

The summary state and prominent Read All action are clear, while settings/overflow remain subordinate separate controls. Native segmented filtering preserves recognizable selection. Text Unread and caught-up feedback communicate status without relying on color. Read All disables after completion. Destructive deletion is behind overflow and a separate native confirmation with explicit consequence text. Retaining the release while Health becomes empty is consistent with the two content sources and should be described accurately in captions.

No VoiceOver session, contrast measurement, cancel/outside-popover interaction, or native-back tap was performed by this reviewer or inferred from a static PNG.

## UI-test lens

The existing controls method checks settings existence, initial Read All enabled state, actual Read All tap, predicate-driven disabled state, actual overflow/Delete All/confirmation taps, then Health filtering and empty-state existence. The PASS is supported by state assertions and actions, not screenshots alone. `auditTap` source calls `tap()` before `VisualAudit.capture`, explaining why action-named screenshots show resulting states: `0F200A67` is hub-after-entry, `23EB49AC` is dialog-after-menu-choice, and `B05F4AE7` is post-confirmation.

Settings is observed but not opened by this method. Native segment selection is exercised for Health at the end, not all three choices. Native back/sidebar routing, swipe actions, cancel behavior and persistence across relaunch are outside this evidence. No requirement to run new/general/full tests is inferred from these unchanged paths.

## Missing Test Cases

None newly required for the changed T11 normal iPad layout and retained controls flow in this review. Other existing source-scoped evidence covers distinct states. This one normal-size iPad method does not establish dark maximum-text iPad or Duo completion.

## iPad-Specific Risks

The run visibly uses native top tabs/sidebar affordance and a pushed hub. Content and native confirmation remain within the shown full-size iPad viewport. It does not cover sidebar-open navigation, multitasking widths, rotation or every iPad size class. The prior read-only T11 prefix comparison established equality of the relevant hub body against validation while excluding T12/T13 detail tails; no whole-file equivalence is claimed here.

## Coverage Rating

Adequate for this iPad normal controls/read/delete/filter-empty flow. Seven image roles are explicitly separated to prevent root/confirmation/Health-empty mislabeling. Runtime: authorized available GPT-6.1 Sol medium fallback. No tests/builds/devices/CI/Git operations, source changes or new agents were used; only this `/private/tmp` report was written.
