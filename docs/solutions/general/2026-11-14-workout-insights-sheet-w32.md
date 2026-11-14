---
tags: [swiftui, detail-redesign, w32, native-capture]
category: general
date: 2026-11-14
severity: minor
status: resolved-with-explicit-limits
---

# W32 source and native gate

Original behavior, values, icons, periods, navigation, and persistence were kept. Split owner `DUNE/Presentation/Exercise/WorkoutSessionView.swift` SHA `2f9b9a27c4ff31c8bd25144c9777a4d74c43d1bab142c1db2ac05a747eafb655` matches the reviewed member or wrapper in frozen `d731fd8cc162c7be5134e7100330fdff83bef64a`. No separate split-only SDK rerun was performed.

[Original passed/diagnostic PNG and AX with selector receipts](../../design/full-redesign-map/review/workout-insights-sheet-w32-2026-11-07/index.html). Gate: `conditional`. Duo current-source capture pending. No full regression or Watch parity result is inferred. No manual Save/HealthKit write is inferred from visual captures. iPad forced sheet fallback has fresh normal only; iPad MAX visits S07 separate window and remains W32-pending.

The conceptual layout/theme maps are distinct from actual app captures. Only the passed profiles and states shown in the manifest are promoted.

## Verification and prevention

Captured on 2026-11-07; finalized on 2026-11-14. Original Phone run was 6 passed/1 failed; the same-ID two-case retry passed 2/2, addressing the normal Insights selector failure and the separately failed MAX long-row native gate. Other five selectors were reused. iPad executed seven: five passed, two Categories cases skipped, zero failed. Skips do not count as passes. Failed and clipped captures remain diagnostics. No source-family failure counters were reset.

Full frames must exclude navigation and tab overlays; isHittable alone does not prove text readability. The normal chart uses a segmented Picker and the accessibility chart a menu button. Closed period-control captures precede taps; later passed assertions check all three options and changed/restored ranges.

Native findings: ["First Phone normal capture belongs to failed chart metric role selector and remains diagnostic; same-ID retry passes.", "Phone MAX Picker button is fully readable and contained in viewport (AX frame x102.7–337.7, y330.3–407.6); same-view PNG is expected before tap. Passed selector subsequently checks all three option labels, changed ranges, and restore.", "iPad normal fallback sheet top and returned interactive workout are distinct current-source pairs."]
