---
tags: [swiftui, detail-redesign, w33, native-capture]
category: general
date: 2026-11-14
severity: minor
status: resolved-with-explicit-limits
---

# W33 source and native gate

Original behavior, values, icons, periods, navigation, and persistence were kept. Split owner `DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift` SHA `fc1655387a9e635121cd7e86577002d9b0eafa774fea595c6dc6ff67dec61e08` matches the reviewed member or wrapper in frozen `d731fd8cc162c7be5134e7100330fdff83bef64a`. No separate split-only SDK rerun was performed.

[Original passed/diagnostic PNG and AX with selector receipts](../../design/full-redesign-map/review/workout-name-editor-w33-2026-11-07/index.html). Gate: `eligible`. Duo current-source capture pending. No full regression or Watch parity result is inferred. No manual Save/HealthKit write is inferred from visual captures. B12 W28 same-source captures remain historical provenance only; new W33 proof requires the fresh named B16+B17 capture.

The conceptual layout/theme maps are distinct from actual app captures. Only the passed profiles and states shown in the manifest are promoted.

## Verification and prevention

Captured on 2026-11-07; finalized on 2026-11-14. Original Phone run was 6 passed/1 failed; the same-ID two-case retry passed 2/2, addressing the normal Insights selector failure and the separately failed MAX long-row native gate. Other five selectors were reused. iPad executed seven: five passed, two Categories cases skipped, zero failed. Skips do not count as passes. Failed and clipped captures remain diagnostics. No source-family failure counters were reset.

Full frames must exclude navigation and tab overlays; isHittable alone does not prove text readability. The normal chart uses a segmented Picker and the accessibility chart a menu button. Closed period-control captures precede taps; later passed assertions check all three options and changed/restored ranges.

Native findings: ["Field, Cancel, Save and sheet title are accessible.", "MAX Phone sheet title visually ellipsizes; AX title remains complete. W33 app source was unchanged."]
