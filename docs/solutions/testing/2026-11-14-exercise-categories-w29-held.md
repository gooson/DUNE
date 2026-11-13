---
tags: [swiftui, detail-redesign, w29, native-capture]
category: testing
date: 2026-11-14
severity: minor
status: unresolved-held
---

# W29 source and native gate

Original behavior, values, icons, periods, navigation, and persistence were kept. Split owner `DUNE/Presentation/Exercise/Components/UserCategoryManagementView.swift` SHA `6a26bd734c5f41812c589d2c7f7924e56a2547c20060078ff5ac7209e97ad9f4` matches the reviewed member or wrapper in frozen `d731fd8cc162c7be5134e7100330fdff83bef64a`. No separate split-only SDK rerun was performed.

[Original passed/diagnostic PNG and AX with selector receipts](../../design/full-redesign-map/review/exercise-categories-w29-2026-11-07/index.html). Gate: `held`. Duo current-source capture pending. No full regression or Watch parity result is inferred. No manual Save/HealthKit write is inferred from visual captures. Skipped iPad Categories toolbar overflow is pending, not pass; no closed More route replay.

The conceptual layout/theme maps are distinct from actual app captures. This is a held draft and must not be merged.

## Verification and prevention

Captured on 2026-11-07; finalized on 2026-11-14. Original Phone run was 6 passed/1 failed; the same-ID two-case retry passed 2/2, addressing the normal Insights selector failure and the separately failed MAX long-row native gate. Other five selectors were reused. iPad executed seven: five passed, two Categories cases skipped, zero failed. Skips do not count as passes. Failed and clipped captures remain diagnostics. No source-family failure counters were reset.

Full frames must exclude navigation and tab overlays; isHittable alone does not prove text readability. The normal chart uses a segmented Picker and the accessibility chart a menu button. Closed period-control captures precede taps; later passed assertions check all three options and changed/restored ranges.

Native findings: ["First Phone MAX long-row capture clipped below tab bar despite selector pass; diagnostic only.", "Retry full custom row AX y345.0–852.7 is fully within viewport bounded by nav maxY116 and tab minY873; screenshot shows name and Duration + Distance."]

The Categories Save and reopen flow was verified only in the isolated Phone fixture; no live HealthKit persistence is claimed. Required iPad entry remains skipped.
