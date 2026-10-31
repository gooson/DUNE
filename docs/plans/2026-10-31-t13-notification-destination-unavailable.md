---
tags: [notification, detail-redesign, swiftui, ios]
date: 2026-10-31
status: in-progress
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
