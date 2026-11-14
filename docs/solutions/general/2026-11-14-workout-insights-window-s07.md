---
tags: [swiftui, detail-redesign, s07, native-capture]
category: general
date: 2026-11-14
severity: minor
status: resolved-with-explicit-limits
---

# S07 source and native gate

Original behavior, values, icons, periods, navigation, and persistence were kept. Split owner `DUNE/App/DUNEApp.swift` SHA `bd91be652e3582c5a2c90e5a4beb18fb32300ddbd7ca29d5adc9c531bfe9ba90` matches the reviewed member or wrapper in frozen `d731fd8cc162c7be5134e7100330fdff83bef64a`. No separate split-only SDK rerun was performed.

[Original passed/diagnostic PNG and AX with selector receipts](../../design/full-redesign-map/review/workout-insights-window-s07-2026-11-07/index.html). Gate: `eligible`. Duo current-source capture pending. No full regression or Watch parity result is inferred. No manual Save/HealthKit write is inferred from visual captures.

The conceptual layout/theme maps are distinct from actual app captures. Only the passed profiles and states shown in the manifest are promoted.

## Verification and prevention

Captured on 2026-11-07; finalized on 2026-11-14. Original Phone run was 6 passed/1 failed; the same-ID two-case retry passed 2/2, addressing the normal Insights selector failure and the separately failed MAX long-row native gate. Other five selectors were reused. iPad executed seven: five passed, two Categories cases skipped, zero failed. Skips do not count as passes. Failed and clipped captures remain diagnostics. No source-family failure counters were reset.

Full frames must exclude navigation and tab overlays; isHittable alone does not prove text readability. The normal chart uses a segmented Picker and the accessibility chart a menu button. Closed period-control captures precede taps; later passed assertions check all three options and changed/restored ranges.

Native findings: ["Normal and MAX iPad show loaded statistics and close; scrolling exposes additional statistics.", "MAX Picker button is fully readable and contained in viewport (AX frame x261–495.5, y175–252.5); same-view PNG is expected before tap.", "Passed selector subsequently taps Last Week, This Month, This Week; checks localized option labels, hittability, actual comparison range changes, and restored initial range."]
