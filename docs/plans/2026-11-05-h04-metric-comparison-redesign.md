---
tags: [design, wellness, comparison, ios, ipados, duo]
date: 2026-11-05
category: plan
status: completed
---

# H04 · Native metric comparison redesign

## Result and scope

The comparison sheet now has a palette-backed title, one visible period/date range, and two separate metric cards. The parent computes one exact ClosedRange and passes that same value to both chart X scales. Each metric keeps its own unit, Y scale, selection binding and MetricDetailViewModel. The existing explanation that trends do not establish cause remains.

Preserve both independently selectable metric IDs and original resolved icons, all D/W/M/6M/Y choices, native sheet/Done, loading/error/retry/empty and limited-history behavior, positive-sleep filtering, sleep bars and other metric line/point marks. Preserve the existing wide layout at available width >=760 and non-accessibility sizes; narrow and accessibility layouts stack. The sole consumer remains WellnessView, with its existing disabled rule when fewer than two distinct comparable metrics are available. This is a time comparison, not an age/sex reference; the separate T06 body-fat reference remains outside H04.

The app change is limited to MetricComparisonView.swift. At accessibility sizes, a wrapping native Menu label and direct native Buttons retain selection IDs, selected checkmarks and traits. Ordinary sizes retain native Pickers. Light chart marks darken their original category color once before Chart rendering, and selected menu labels use TextSecondary. Dark marks and category icon colors retain their original values. No query, model, service, write path, new catalog key, Watch or Vision consumer changed.

## Implementation and design maps

1. Establish the dedicated H04 layout contract and preserved theme prototype before implementation. Synchronize layout/theme indexes, theme manifest and README, with prototype values explicitly illustrative.
2. Implement the shared range, title, card treatment and accessibility controls in MetricComparisonView.swift. Keep the existing WellnessView consumer and MetricDetailViewModel lifecycle.
3. Update only H04-local tests/helpers in WellnessRegressionTests.swift. Use the existing long-history fixture to isolate collection/history metadata; require real HRV and Weight plots and distinct ms/kg units, one changed W-to-M date, reachable controls and Done return. Helpers use unique IDs and live clipped geometry with existing bounded waits/gestures.
4. Refresh only H04 in four affected actual-map tiers and their Wellness boards, capture indexes and H04 comparison records. Add a separate native review gallery with original paired PNG/AX. Retain four previous images as historical identity references, not matched-source before captures. Compare map cards by embedded screen ID rather than catalog position, and preserve all non-H04 entries/cards/board pixels.

## Completed targeted validation

Five effective cases passed across four sequential device profiles, with one owned simulator at a time. The changed app/UI target actually compiled. The UI test source revisions differ; the app bytes are identical across all final selected cases (SHA-256 `106c95c56d656ab55ce56377e5dc3f4ab6ed365b31918539cc2a73ee470eb28a`).

| Case | Actual test source | Result | Reviewed PNG/AX pairs |
| --- | --- | --- | --- |
| Duo closed normal | 14f9d4aa | Passed case inside FAILED aggregate 2/1/1 | 6 |
| Duo open normal | 14f9d4aa | Passed 1/1 | 6 |
| Duo closed dark/MAX | bfd03486 | Passed 1/1 operator continuation | 7 |
| iPhone normal | 89031bea | Passed 1/1 operator continuation | 6 |
| iPad normal | 89031bea | Passed 1/1 | 6 |

The normal selector is `DUNEUITests/WellnessRegressionTests/testCompareMetricsSharesPeriodAndDismisses`; MAX is `DUNEUITests/WellnessRegressionTests/testCompareMetricsDarkMaximumAccessibility`. The new normal Period helper was verified on phone/iPad, not newly executed on Duo. Earlier normal Duo evidence preserves the same app behavior and passed selection/date/plot/dismissal contract. MAX method/helpers are byte-identical between bfd and890.

Independent source/delta, SwiftUI/Apple/native and publication reviews are recorded separately. All31 selected pairs have matched original source, device, case and file hashes. Duo pose/active display was read back before and after: closed0°/LCD and open180°/LCD-1. Light essential marks measured6.99:1 and selected picker text6.49:1 against the card. No new unit algorithm exists, so no redundant unit, full regression, Watch or Vision run was added.

## Failure lineage and limits

All10 frozen native archives remain intact: 13 historical XCTest cases, 6 passed and7 failed. These totals are not a green aggregate. Original closed and phone pipeline failures remain failed; successful case/operator evidence is separate. Causes addressed were nested native menu IDs, an index-bound stale AX query, virtualized menu position, light mark contrast, bounded Month return, and a phone Period control hidden under native navigation despite broad scroll containment. The phone first-launch AX timeout recovered to a complete Wellness tree in the same attempt, and its following run entered H04; no host-lock or precise startup root cause is claimed. A sandbox-only xcresult export failure was corrected without another UI execution.

Native app captures are English. W/M interactions are observed; D/6M/Y, unchanged error/empty/history paths and wide-layout logic were preserved in source, not all separately exercised. The iPad month checkpoint reaches the Weight picker at the sheet edge; the complete second plot was checked in its week capture. No VoiceOver, every metric/locale or live HealthKit claim is made. Old images lack a source/UID/pose/AX join and remain identity-only.

The actual gallery is `docs/design/full-redesign-map/review/h04-metric-comparison-native-2026-11-05/`. All three used H04 simulator UIDs are absent after cleanup. Frozen raw evidence is retained; only hash-identical duplicate SDK cache bundles were removed. The reusable rollout worktree and immediately needed UI build cache remain for H05.
