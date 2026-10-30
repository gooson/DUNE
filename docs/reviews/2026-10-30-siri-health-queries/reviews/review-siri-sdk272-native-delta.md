# Siri health query native UI: SDK 27.2 visual delta review

Reviewed 2026-10-30 against `.codex-checks/review-siri-native-ux.md`. Evidence: `.codex-checks/siri-native-sdk272-reviewed/manifest.json`, `overview.png`, and individual actual PNGs `SQ02-workoutSummary`, `SQ07-bodyTrend`, `SQ08-sleep`, `SQ10-metricComparison`, and `SQ11-workoutComparison`. The manifest lists 17 fresh 1206 × 2622 px iPhone 18 Pro captures on iOS 27.2 / Xcode 27.2 (27B52), from source commit `be22072d`, using synthetic DEBUG fixture data in the native app. These are not Siri system UI captures.

## P1/P2 delta

| Previous finding | SDK 27.2 observation | Status |
| --- | --- | --- |
| P2 · SQ10 aggregate comparison dates looked like individual sample dates | The Workout Records, Active Duration, and Average Recorded Sleep cards now label **Current: Oct 1–30, 2026** and **Previous: Sep 1–30, 2026** beneath their aggregate values. SQ11 retains individual Oct 24 and Oct 6 dates for per-record comparisons. | Resolved visually |
| P2 · SQ02/SQ08/SQ10/SQ13 duration charts had raw numeric ticks without units | The visible SQ02 and SQ08 duration plots now mark the vertical axis **s**. The numerical tick values remain seconds, consistent with the underlying plotted values; the large result values remain formatted as durations. The SQ10 chart starts below the captured viewport, and the overview shows no legible axis detail for SQ13, so their individual unit labels cannot be independently confirmed from these PNGs. | Resolved for SQ02/SQ08; SQ10/SQ13 visual confirmation open |

No new P1 or P2 issue was observed in the SDK 27.2 overview or inspected individual images. The previous P3 items remain outside this delta review: partially cut top chart ticks, an implicit body weight change in SQ07, and repeated report text in SQ13. They are not promoted to P2 based on these captures.

## Verification limits

The capture run reports all 14 query kinds, software keyboard, and explicit no-data captures passing on SDK 27.2. This review inspected PNGs only and did not rerun tests or operate a simulator. An initial maximum accessibility text run failed when the native Menu was offscreen before the result hero; a separate test-only fix is being handled elsewhere. These images do not establish maximum accessibility text behavior, VoiceOver, native Siri invocation or spoken output, physical device, iPad, Duo, or live HealthKit provenance. They also do not establish resolution of the earlier Browse-period tap or Share mini-popover interaction findings.
