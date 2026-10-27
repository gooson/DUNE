---
tags: [wellness, flow, quality, astra]
date: 2026-10-28
category: review
status: reviewed
---

# Astra final native quality review — Wellness Flow

Reviewed app HEAD `b1dbdfda`, 2026-10-28. Read-only source and native PNG review. The shared snapshot `/var/folders/fs/kn1rj4b522jcn45jm__5jwx40000gq/T/codex-context-253btsc5` was checked and returned `current` before reuse. No tracked files, tests, builds, or simulators were changed or executed. The earlier two prototype reviews were reused, not repeated.

## Verdict

**PASS WITH NOTES for the reviewed scope at `6c1d3f77`: current P1/P2 = 0.** The prior wrist-temperature P2 is resolved. Capsule shape and nested label/date wrapping remain optional P3 polish. This is not all-device, all-locales, VoiceOver, or whole-suite approval.

## Targeted recheck at `6c1d3f77`

Only the original findings and the three component deltas from `b1dbdfda..6c1d3f77` were rechecked; the original snapshot is not presented as current for this commit. No build, test, or simulator execution was performed.

- **Wrist-temperature P2 — resolved.** `WellnessMetricCard.healthContext` now explicitly shows `Change from personal baseline` for wrist temperature. The string catalog contains en/ko/ja translations. The caption is visible beside the correct baseline-relative value in `.codex-checks/wellness/ipad-body-attachments/0F293E0F-F1AA-479B-ADF9-7D1C203AEA2D.png`, inspected at this recheck. It remains ordinary accessible Text rather than hidden decoration; native VoiceOver traversal was not tested here.
- **Sleep scaling edge case — resolved at source level.** The denominator is now `max(600, recentSamples.map(\.minutes).max() ?? 600)`. `recentSamples` already excludes nonfinite/nonpositive entries, so durations above ten hours are no longer all saturated to the same height. Capsule shape is retained as an optional P3 art-direction choice. This targeted source review did not execute a long-sleep fixture.
- Removing unused hero inputs does not change the score formula or the values consumed by the hero.
- The inspected iPad light PNG shows all six primary health tiles and all four body tiles, explicit wrist context, `%p` body-fat change, previous values/dates, and no invented BMI/lean-mass trend. Narrow nested tiles cause label/date wrapping, including `Respira- / tory Rate`, but values and actions remain readable. This is optional P3 polish, not a data or navigation blocker.
- Parent reports the iPad health semantic assertion/capture 1/1 and full-body frame capture 1/1 passed. These are reused reported targeted results, not this reviewer's execution. Phone health at the latest source and Duo remain pending upstream; no all-UI pass is claimed.

The new image establishes the inspected iPad light health/body region only. It does not establish iPad dark, all iPad states, or Duo approval.

## Targeted Duo viewport pixel review

App source `6c1d3f77`, test source `08b320c7`. Inspected only these three fresh PNGs under `.codex-checks/wellness/gallery-staging/images/`:

- `duo-closed-H01-Wellness-Flow-hero-light.png`: closed viewport 466×678pt / 1398×2034px. The Wellness hero stays in one column; ring, score, narrative, evaluation date, four evidence rows, and disclosure remain readable without card-content clipping.
- `duo-open-H01-Wellness-Flow-hero-light.png`: open viewport 951×669pt / 2853×2007px. Hero uses score/narrative and evidence columns; observed sleep and prediction are paired below with distinct labels and values. No overlap or illegible primary content was found in the changed cards.
- `duo-open-H01-Wellness-Flow-health-detail-light.png`: health/body side-by-side layout preserves six metric categories, body comparisons/units/prior dates, the explicit wrist baseline caption, and Add Body Record. Content at the image's top/bottom is naturally outside this scrolled viewport, not evidence of clipped card layout. The existing P3 nested title/date wrapping remains, including the respiratory-rate label; no new P1/P2 found.

**Duo visual delta verdict: current P1/P2 = 0 in these inspected light viewport regions.** The system multiview/control chrome, including `2개의 보기가 열려 있음`, was not treated as changed Wellness UI. Parent reports closed 2/2 and open 2/2 selectors passed with active-panel, fresh ACK/AX, display rotation, and PNG validation; no test or device operation was repeated here.

These are viewport-layout observations. The open display reports LCD-1 rotation 90, while canonical nativeSize and the physical-orientation getter do not directly represent the captured orientation. No hinge-angle getter is available: `actualAngle=null`, `angleVerified=false`. This review does **not** certify a physical angle or fold transition, dark Duo, AX Duo, or all offscreen states.

## Original findings at `b1dbdfda` (lifecycle above supersedes status)

- **P2 — wrist temperature lacks its baseline-relative meaning.** `DUNE/Presentation/Wellness/WellnessViewModel.swift:446-458` supplies `temp.value - baseline` and baseline-subtracted history, but `WellnessMetricCard.swift:94-105` only supplies context when `baselineDetail` or `change` exists; both are nil for this card. The final health light/dark PNGs show `Wrist Temp +0.0 °C` without saying this is a change from the personal baseline. The approved layout contract explicitly preserves this meaning. Add a short localized baseline-relative explanation for `.wristTemperature`, with the same information available to accessibility. Do not add a normal range or medical interpretation. This was also under-explained in the older VitalCard, but it remains an unmet explicit contract of this redesign.
- **P3 — sleep chart visual scale remains a polish/edge-case limitation.** `WellnessSleepSummaryCard.swift:78-81` uses wide capsules with an 8–54pt clamped height. The reviewed default-size capture reads as a row of near-circles rather than low vertical bars; the fixed 600-minute ceiling also saturates all readings above ten hours. Numeric latest/average values remain separate. A bounded-width rounded rectangle and a scale that covers the actual sample maximum would communicate durations more faithfully. The latest source has no fabricated missing-day values; this observation does not imply fabricated sleep measurements.
- **P3 retained tradeoff:** the shared injury memo is a one-line preview with full text reachable through its edit route, as established in `quality-apple.md`; it is not a new blocking issue. The Maximum AX posture heading's prior word-splitting issue is resolved in the new PNG.

## Source and evidence checked

- Native Wellness root, ViewModel delta, body comparison DTO, new/revised Wellness cards, posture children, unit-test delta and UI test routes/fixtures. Existing `quality-apple.md` and `quality-swiftui.md` findings were reused and their resolved source paths checked.
- Body comparisons retain each metric's real latest value/date, select the latest valid observation on or before the seven-day calendar cutoff, show the prior date, distinguish missing comparison from valid zero, and use `%p` for body fat. Weight/body-fat histories are chronological; no BMI/lean-mass sparkline is synthesized. The separate observable comparison dictionary avoids relying on the existing VitalCardData equality implementation.
- Independent local posture/injury records and manual body entry remain outside the HealthKit-data gate; Query isolation and eager layout remain. Posture score updates include latest record identity/score/metric payload, and unmeasurable records avoid numeric scores. Preview-only fixtures are behind existing UI-test controls rather than used as live measurements.
- Shared 104pt ring, DUNE surfaces/category tokens, 0–100 component evidence, separate observed sleep/forecast, dated body values, and distinct photo/Watch content are preserved. Ocean's new ring and text are readable in the inspected light PNG. No numeric contrast measurement was performed.
- Reused `.codex-checks/wellness/unit-counts.json`: exit 0, 19 tests, two suites, passed. This is the recorded targeted result, not a newly run or full-suite result. Parent reports final phone delta 3/3 passed; I inspected its attachment manifest and pixels, not an independent rerun. The two notification-hub smoke failures remain parent-reported, out-of-scope locale mismatches, not erased or counted as passes.

## Actual images inspected

From `.codex-checks/wellness/phone-final-attachments/` (source `b1dbdfda`):

- Health light `0855939D-F356-43AF-BCAF-8BBD20E07F83.png` and dark `BAA26053-D418-4F00-8999-367B25BF1F4C.png`.
- Ocean hero `1062A6A3-F1F6-4FE4-AFAB-A4FA6B76F7C4.png`.
- Maximum AX posture `E6168719-F227-4521-9A17-BAA3BEE21230.png`, body `8174EE8C-DAD9-4553-A094-EA5378E73B89.png`, hero `90054EAD-450D-4C59-AA53-4D997BBB013E.png`.

From `.codex-checks/wellness/gallery-staging/images/` (earlier `22ea46ae` captures; unchanged Desert default-size components per scoped delta): `iphone-H01-Wellness-Flow-{hero-light,hero-dark,body-light,body-dark,posture-light,posture-dark,prediction-light,sleep-light}.png`.

The new health images show the heart-rate/oxygen/respiration/temperature rows and their units/own-scale charts clearly. The top HRV/RHR rows are partially outside those viewports, so this is not an assertion that every health tile was visually checked in full. Maximum AX inspected main values remain readable; posture's full word now wraps without hyphenating.

## Unverified scope

Duo regions/states beyond the three inspected light viewport frames, physical hinge angle and fold transition; iPad regions/states other than the explicitly inspected light health/body frame; Watch nonempty metric state; native VoiceOver traversal/announcements; numerical contrast; Japanese/Korean runtime layout and all non-Desert themes beyond the inspected Ocean hero. Latest phone health delta was pending upstream at the preceding source recheck and is not reassessed by this Duo-only review. Maximum AX captures are viewport samples, not proof of every offscreen row. No final shipping or whole-suite verdict is inferred from these bounded results.
