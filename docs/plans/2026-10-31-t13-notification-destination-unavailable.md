---
tags: [notification, detail-redesign, swiftui, ios]
date: 2026-10-31
status: verified
---

# T13 notification destination unavailable

## Goal and evidence

Redesign only `NotificationDestinationUnavailableView` in `NotificationHubView.swift` as a native detail surface for the existing failed destination route. The approved T13 prototype is `786c2c3cb8dab80ccb0f5db0414c23f0ae5e4894:docs/design/detail-redesign-map/data/dashboard.json`; its sample title, explanation, and placeholder ID are fixture copy, not app state. Current code supplies the truthful text, `itemID`, dismiss action, and navigation title. The existing four device captures in `docs/design/phone-design-map/actual` are before images.

## Research

- `docs/solutions/architecture/2026-03-03-notification-inbox-routing.md` and `docs/solutions/general/2026-03-04-notification-hub-chart-detail-routing.md` describe route fallback ownership in the inbox; no routing change is needed.
- Existing design uses `DetailWaveBackground`, `ScoreHeroPalette`, `DS.Spacing`, and opaque hero surfaces (`CloudSyncConsentView`/condition hero). Follow these patterns without new theme colors or motion.
- SwiftUI `ScrollView`, adaptive max width, and Dynamic Type fonts handle compact phone, wide iPad/Duo, and accessibility text without geometry or fixed height.

## Exact layout and theme contract

See `docs/design/layout-map/notification-destination-unavailable-t13.html` and `docs/design/theme-map/themes/dune-notification-unavailable-t13.html`. One centered column: opaque theme hero with original `arrow.triangle.branch` SF Symbol, original title and explanation; one `Go Back` button dismisses; item ID remains a quiet bottom footer. Keep the system navigation title `Notification`. No status, date, count, metric, additional button, or invented route. Light/dark use the existing palette and theme button foreground. Max width 560pt; scroll and full-width text/button at accessibility sizes. Theme illustration is a static proposal, not a native capture.

## Implementation

1. Replace only the private T13 view body. Preserve its input, environment dismiss, exact localized string keys, `ID: \(itemID)`, screen identifier, and navigation title. Leave T11/T12 view bodies unchanged.
2. Extend only `DesignMapNotificationDetailTests/testNotificationDestinationUnavailable` with assertions for explanation and reachable `Go Back`; capture while T13 is visible, then dismiss and assert inbox is reachable.
3. Parent QA lane runs the exact selector on affected iPhone/iPad/Duo postures, dark appearance, and accessibility size as appropriate; refreshes only actual T13 captures with provenance. This source-only lane runs no simulator/build/capture.

## Risks and verification

The fallback may be entered with a long ID; footer must wrap and remain reachable by scroll. On a short Duo landscape viewport, the action must stay reachable without clipped content. The T13 test checks the real seeded route and dismissal. Source checks compare pre/post T11/T12 text and confirm no new catalog keys. Runtime remains pending until the parent QA lane runs it.


## Resumed minimum verification — 2026-11-02

Actual latest main a6ec9be1 contains completed T11/T12. The merged prefix preserves both, while T13 equals original734db23d and frozen validation3fac15d4 (segment e76a). The entire shared app file also truly equals validation here; the UI test file does not, but the T13 normal/MAX/UUID/viewport-helper block is byte-identical to original and validation (dcece). No speculative back-query/capture patch is needed: T13 has its own Go Back identifier and a verified before-dismiss checkpoint.

Reuse clean734 Phone normal+dark/MAX2/2 PASS under this exact product/test/route/payload closure. Add only one existing normal case on iPad and one each on Duo closed/open, preserving explicit Go Back tap and actual hub return, exact original copy and real UUID assertions. Duo uses owned registration, SDK/active-display readbacks and strict native checkpoints; one device at a time, deadline1200 and no parallel heavy runner. No additional local unit/full UI/Watch or standalone duplicate build is warranted for this presentation-only change.

Five distinct source reviews and UI test-design/source quality found zero actionable findings. Theme union10themes/23studies, Swift parse and source preservation checks passed. Historical iPad baseline group contains a separate bedtime failure; only the original T13 node passed, and it is a before image, not redesigned runtime proof. New iPad/Duo results and final comparisons/Compound/ship remain pending at this checkpoint.


## Final native verification — 2026-11-02

- Publicff68a35c preserves T11/T12 maina6ec and original734 T13. The shared NotificationHubView.swift file truly equals frozen3fac here; the full UI test file does not, but T13 block, common entry helper and launch configuration match. This is no whole-repository equality claim.
- Historical clean734 Phone normal+dark/MAX2PASS reused. Fresh iPad normal1, Duo closed1 and open1 PASS; each Duo has strictACK7, before/after0°LCD or180°LCD-1. Original copy, UUID and actual Go Back/hub return remain verified. Actual Phone/iPad/Duo three-lens reviews found zero actionable issues. No extra local Phone/unit/full UI/Watch run.
- Closed first attempt failed before UI on SDK inventory4s timeout; raw0-test failure is retained. Same owned Booted/available device inventory0.461s established recovery; SAMEcheckID retained exactly one conditional retry success. Two original attempts and recovery evidence remain; no runner/app edit or third same-cause execution. Open passed its single planned attempt.
- [Installed native comparisons](../design/full-redesign-map/review/t13-notification-unavailable-native-2026-11-02/index.html):12 originalPNGs, fourT13-only rows/images and related rendered pages/Today boards; all other rows/images and Watch unchanged. UUIDs differ per fresh fixture launch, so this is a same-screen-family layout comparison, not one notification across devices. iPad mini/Pro13, historicaldates and oldDuo pose uncertainty are explicit. Old iPad baseline groupFAILED6/5/1bedtime is retained with exact T13 nodePASS; not a redesign PASS.
- Five source reviews, UI test-design and actual native quality are zero. [Compound solution](../solutions/general/2026-11-02-notification-unavailable-recovery-surface.md) records semantics, recovery and provenance. Final integration review/PR state are tracked separately.
- Currentff68 app build passed. Automatic full iOS CI subsequently completed: Swift Testing2734/302 suites and XCTest12 PASS, job125238631157; logs retained. Watch failed before tests with missing Destination id/exit64; its source/Shared/project/workflow/runner inputs are unchanged. Same unit inputs have T12iOS2734/302+XCTest12 and latest T11Watch213/29 PASS; necessary changed-scope verification uses current app/native/review evidence, not an added whole-suite rerun. Existing CI completion is followed separately.
- One owned device at a time; iPad4F2B and DuoE9E4 deleted and registry empty. Original .claude configuration, common settings and test runners unchanged.
