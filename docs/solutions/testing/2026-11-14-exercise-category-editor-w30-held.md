---
tags: [swiftui, detail-redesign, w30, native-capture]
category: testing
date: 2026-11-14
severity: minor
status: unresolved-held
---

# W30 source and native gate

Original behavior, values, icons, periods, navigation, and persistence were kept. Split owner `DUNE/Presentation/Exercise/Components/UserCategoryManagementView.swift` SHA `70b1881473ac8d4413b2461e279aa81b96673d6c02f1ec882d16e926f262ddce` matches the reviewed member or wrapper in frozen `d731fd8cc162c7be5134e7100330fdff83bef64a`. No separate split-only SDK rerun was performed.

[Original passed/diagnostic PNG and AX with selector receipts](../../design/full-redesign-map/review/exercise-category-editor-w30-2026-11-07/index.html). Gate: `held`. Duo current-source capture pending. No full regression or Watch parity result is inferred. No manual Save/HealthKit write is inferred from visual captures. Skipped iPad Categories toolbar overflow is pending, not pass; no closed More route replay.

The conceptual layout/theme maps are distinct from actual app captures. This is a held draft and must not be merged.

## Verification and prevention

Captured on 2026-11-07; finalized on 2026-11-14. Original Phone run was 6 passed/1 failed; the same-ID two-case retry passed 2/2, addressing the normal Insights selector failure and the separately failed MAX long-row native gate. Other five selectors were reused. iPad executed seven: five passed, two Categories cases skipped, zero failed. Skips do not count as passes. Failed and clipped captures remain diagnostics. No source-family failure counters were reset.

Full frames must exclude navigation and tab overlays; isHittable alone does not prove text readability. The normal chart uses a segmented Picker and the accessibility chart a menu button. Closed period-control captures precede taps; later passed assertions check all three options and changed/restored ranges.

Native findings: ["MAX selected input-type picker visually ellipsizes Duration + Distance, though AX value is complete. This is outside the changed icon/color grid; full visible string is unproven."]

The Categories Save and reopen flow was verified only in the isolated Phone fixture; no live HealthKit persistence is claimed. Required iPad entry remains skipped.
