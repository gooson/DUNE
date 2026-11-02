# A07 native quality — PASS WITH NOTES

**P1 = 0 · P2 = 0 · no actionable new UI P3.** This assesses the captured states, not publication or complete application accessibility.

| Current source aedf464d | Selectors passed | Captured evidence |
| --- | ---: | --- |
| iPad A20 normal | 2 | Manual week plus four HealthKit week types |
| iPad A20 dark MAX, approved extra | 1 | Manual week hero/comparison and month |
| iPhone 18 Pro Max normal | 2 | Manual week plus four HealthKit week types |
| Duo closed normal | 2 | Manual week/month and four HealthKit week types |
| Duo open normal | 2 | Manual week/month and four HealthKit week types |

- SwiftUI: independently inspected all six open Duo active-display host PNGs 004, 007, 010–013, and paired hierarchy checkpoints. The week/month states and each type are correct, hero values and type-specific glyphs fit, and timer/strength metric symbols match A06. Open summary is 2/2 PASS with 14/14 valid ACKs; pose proof records 180°/LCD-1 before and after. Named 2007x2853 files encode 2853×2007. Closed 0°/LCD also passed 2/2 with 14 valid ACKs. Other device images and AX were reviewed in `/private/tmp/pr894-quality-preliminary.md`.
- Apple UX: visible native heroes distinguish manual strength and four HealthKit types; the manual hero shows 6.4t, 2.0h, 750 kcal and three sessions. The MAX iPad hero and scrolled comparison are readable in their separate captured viewports. Previous icon consistency P3 is resolved by six source substitutions and current captures; original type icons and recent-session clock are preserved. In the narrow closed Duo weekly chart, date labels crowd and overlap. This chart code is unchanged by A07 and the same issue appears in the historical original Phone week; it is a pre-existing readability limitation, not a new UI P3 attributed to this change. Source performance review separately defers a P3 date-formatter caching concern.
- UI test: the table records nine current individual case passes, not nine distinct screenshots or a full regression. Prior iPad MAX failures in groups 3/2/1 and 1/0/1 are retained; the approved additional case passed once, with one consumed and zero remaining. The normal pre-polish 3f2 results remain historical, not current glyph proof. AX existence outside a visible viewport does not establish visual readability.
- Holistic: use Phone and iPad manual week as current canonical states, and Duo manual month for comparison with the historical Duo map month; current Duo week is supplemental. Strong historical iPad A20 before evidence identifies clean 1f7 manual week node PASS within a 5-pass/1-fail group and clean 936 four-HK week selector in a 2/2 group. Old Phone/Duo per-image model, execution source, AX and Duo pose remain unknown; do not imply matching provenance. The screenshots do not establish live VoiceOver, full localization, current 3M/6M native interactions, Phone MAX, empty fallback, or live fold-state continuity. Publication installation and its audit remain separate.

No tests, devices, source or Git mutation by reviewer.
