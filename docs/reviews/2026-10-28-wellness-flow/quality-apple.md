---
tags: [wellness, flow, quality, apple]
date: 2026-10-28
category: review
status: reviewed
---

# Apple UX quality review — Wellness Flow

## Final iPad visual delta (app `6c1d3f77`, test-only HEAD `887c2d3e`)

Read-only inspection of the two new iPad PNGs in `.codex-checks/wellness/ipad-body-attachments/0F293E0F-F1AA-479B-ADF9-7D1C203AEA2D.png` and `.codex-checks/wellness/ipad-final-attachments/AA413269-AC72-4ACE-9C80-0C90E5F3DC0D.png`, plus staged `ipad-H01-Wellness-Flow-hero-light.png`, `hero-MaxAX.png`, `health-MaxAX.png`, and `body-MaxAX.png`. The parent reports the new four-complete-body-tile assertion passed 1/1; I did not execute it.

- **P1/P2: no iPad layout or meaning defect found in the inspected frames.** Regular-width iPad puts the hero's status and four score components in two readable columns, then pairs observed sleep with forecast and the full health grid with body changes. The new whole-frame health/body image shows all six primary indicators and all four body tiles at once. All current values, units, per-metric changes, previous measurements and dates, sparklines, and navigation cues remain visible. At Maximum AX, the hero switches to an external score and the content becomes one column, preserving score labels and card actions rather than shrinking text.
- **Wrist temperature meaning: resolved.** `WellnessViewModel.swift:446-458` computes the displayed value relative to a personal baseline; `WellnessMetricCard.swift:93-99` adds “Change from personal baseline.” The new iPad body attachment visibly places that phrase under `+0.0 °C`, so readers are not led to treat the number as an absolute wrist temperature. This also meets the approved proposal's baseline-delta meaning.
- **P3 optional polish:** In the nested 2×2 wide cards, labels such as “Respiratory Rate” and “Lean Body Mass” use two or three lines; freshness and measured date often use two lines. They remain fully readable in the new complete frame, with no truncated value or unit. “Today Oct 28 at 00:00” repeats the date context but retains the precise measurement time. A wider inner tile or tighter secondary copy could improve rhythm later; this is not a blocker or a reason to remove valid context.
- **Coverage:** The new whole-frame body/health attachment shows the lower posture card only partly. The iPad hero and Maximum AX conclusions above use the named staged captures. No iPad VoiceOver or numerical contrast audit was run by this reviewer.

Apple principle delta for iPad: **Purpose, Agency, Responsibility, Familiarity, Flexibility, Simplicity, Craft, Delight — conform in the inspected iPad frames.** The exact-value/label/date visibility supports Responsibility; adaptive two-column-to-one-column layout supports Flexibility; secondary text wrapping is optional Craft polish. [Design principles](https://developer.apple.com/design/human-interface-guidelines/design-principles), [layout](https://developer.apple.com/design/human-interface-guidelines/layout), [accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).

Read-only source and native PNG review of the Wellness flow against `docs/design/layout-map/wellness-redesign-proposal.md` and Activity. The parent reports a generic build and 19 unit tests passed; I did not rerun them. I inspected the exact H01-labelled light, dark, and Maximum AX iPhone attachments from `phone-attachments/manifest.json`. The current suite is being rerun after three test-helper failures and also has two unrelated notification failures; these PNGs are visual evidence, not a whole-suite pass. VoiceOver behavior and measured contrast remain unverified.

## Visual delta from H01 attachments

- **P1: none found in the inspected pixels.** Dark hero, body, prediction, and posture remain readable, with no visible overlap or clipped primary score. The four 0–100 evidence bars and the separate observed sleep and “Predicted score” labels read clearly. Light/dark body panels preserve per-metric change units (`kg`, `%p`, unitless BMI), previous values/dates, and the absence of invented BMI/lean-mass graphs.
- **P3 optional polish — active-injury memo previews only one line at Maximum AX.** The Maximum AX `H01-Wellness-Flow-health-MaxAX` attachment (`F8130283-801F-4E35-92B8-8BDBF29408F3.png`) shows “Mild pain d…” where the default-size card shows the longer note. This is the shared `InjuryCardView.swift:49-54` one-line preview, not evidence of data loss: the entire card is a `Button` (`:8-10`), Wellness routes it to `injuryViewModel.startEditing(record)` (`WellnessView.swift:113-116,546-550`), and the edit sheet's memo field receives the full saved text (`InjuryViewModel.swift:80-90`, `InjuryFormSheet.swift:132-134`). The approved Flow specifies a compact active-injury summary and edit action. Letting the preview wrap at accessibility sizes could improve glanceability, but this does not warrant expanding the shared injury component in this Wellness change. Native VoiceOver reading of the full `Text` was not independently tested.
- **P3 — Maximum AX posture title wraps awkwardly.** The `H01-Wellness-Flow-posture-MaxAX` attachment (`92ECEE84-E79F-4CB9-99E4-787ED4528D93.png`) breaks “Assessment” into “Assess- / ment” beside a large chevron. The date, 86/100, assessment type, and separate Capture/Realtime actions remain readable in the adjacent `posture-actions-MaxAX` attachment. Let the title/chevron lay out without splitting the word if a compact title or stacked header can preserve the destination cue.
- **P3 coverage limit — health card details and Watch data state.** The H01 `health-light`/`health-dark`/`health-MaxAX` frames show only the beginning of Health Indicators and first metric tile at the viewport edge; the complete metric grid is not visible in a single inspected attachment. The Watch card in these fixtures is the “Apple Watch required” state, so the dated summary and new AX metric row were source-checked but cannot be visually confirmed from these captures. No contrast ratio was measured.

Attachment IDs reviewed: hero `5F9398E9`/`C43AC99F`/`FED5252E`; health `B61D7CD0`/`75F87A11`/`F8130283`; body `C1FFBAE5`/`FC0B8B29`/`EB15BEB1`; posture `0A704F28`/`8DA59A2E`/`92ECEE84` and actions `DDDCAB33`/`4DC60489`/`0EF3D951` (light/dark/Maximum AX respectively). All are `H01-Wellness-Flow-*` attachments under `.codex-checks/wellness/phone-attachments/`.

## Current delta after `22ea46ae`

- **P1 Watch “Today” mislabel: resolved at source level.** The header now renders `summary.date` as month/day (`WatchPostureSummaryCard.swift:63-66`). Retention across midnight can show older data, but it no longer asserts that the observation was today. Freshness or receipt time is not yet shown and should be assessed only if the later Watch capture exposes a misleading state.
- **P2 Watch large text layout: resolved at source level.** `WatchPostureSummaryCard.swift:73-105` switches the metric row to a leading-aligned `VStackLayout` at accessibility sizes. The attached fixture has no Watch data, so this particular row has not been visually inspected.
- **P2 forecast meaning: resolved at source level.** `WellnessSleepPredictionCard.swift:67-84` now places localized “Predicted score” directly before the number and retains the confidence text. The same label appears for en/ko/ja in the string catalog. Native VoiceOver behavior of the containing link has not yet been inspected.
- **P3 native visual pass: expanded but bounded.** The earlier iPhone light/en hero probe is now supplemented by eight exact H01 captures each for light, dark, and Maximum AX. Body/posture values and action buttons are visible; the full health grid, non-empty Watch row, VoiceOver, and contrast measurement remain outside this evidence.

The parent reports that its targeted UI probe passed 1/1 after moving accessibility identifiers to the intended row/link/title anchors. I did not run or independently inspect that test log.

## Original findings (P1/P2 resolved in the delta above)

- **P1 — Watch summary can be labelled “Today” after its observation day.** `WatchPostureSummaryCard.swift:62-65` shows a hard-coded “Today” for any data. `WatchSessionManager.swift:522-525` checks the day on receipt, but `receivedPostureSummary` is retained and `WellnessViewModel.swift:119-120` copies it without rechecking the day. After midnight or when returning to a long-lived session, yesterday's sitting/walking counters can read as today's. Use the summary's `date` in the card and treat a prior-day summary as older or missing. Display the observation/receipt context available from the model; avoid claiming live monitoring. This is a data-trust issue under Apple's **Responsibility** principle.
- **P2 — Watch four-metric row does not adapt to accessibility text.** `WatchPostureSummaryCard.swift:72-101` always uses one `HStack` for Sitting, Walking, Reminders, and Gait. Unlike `WellnessView.swift:453-475`, `WellnessBodySummaryCard.swift:34-40`, and the posture actions, it has no accessibility-size one-column switch. At narrow width and large Dynamic Type, the values/labels can compress or wrap unpredictably. Change to an adaptive one-column layout for accessibility sizes and inspect the resulting capture. Apple's [layout guidance](https://developer.apple.com/design/human-interface-guidelines/layout) calls for text-size and window-width adaptation.
- **P2 — The numeric sleep forecast is not explicitly named as a prediction in the card's accessible content.** `WellnessSleepPredictionCard.swift:18-28,66-85` titles the card “Tonight's Sleep” then presents a score and outlook; its `NavigationLink` has no explicit label/value. Sighted users can infer forecast from “Tonight,” but a VoiceOver user landing on a link can hear a sleep score without an explicit predicted/observed distinction. Label the number “Predicted sleep score” in the visible copy or the accessible value, and keep confidence attached. This serves Apple's **Responsibility** and [accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility) on clearly describing content.
- **P3 — nested surfaces and contrast.** Light/dark hero, body, and posture surfaces are visually distinguishable in the new native attachments. The health grid is only partly visible, and no numeric contrast audit has been performed. Apple's [accessibility reference](https://developer.apple.com/design/human-interface-guidelines/accessibility) gives 4.5:1 for ordinary text at 17pt or smaller.

## Checked source-level alignment

- Flow order is hero → recent observed sleep → tonight forecast → active injury → indicators → body → Watch → photo assessment → injury history (`WellnessView.swift:92-154`); wide layout pairs related cards and accessibility Dynamic Type returns to one column (`:382-392`).
- Hero uses the shared 104pt ring and four 0–100 component-score labels; its calculation explanation expands (`WellnessHeroCard.swift:115-203`). Native line lengths and icon/track visibility still need captures.
- Recent sleep uses recorded dates and a 7-day mean only with at least two valid samples (`WellnessSleepSummaryCard.swift:12-31,59-90`). Metric rows include freshness/date. Body changes use per-metric comparisons and `%p` for body-fat change (`WellnessMetricCard.swift:20-26,105-136`). Photo and Watch posture are separate; the photo guide is hidden at accessibility sizes (`WellnessView.swift:628-690`).
- `CardNavigationHeader` defaults to a 44pt high tappable header (`CardNavigationHeader.swift:3-28`); full-card links and posture actions provide larger areas (`WellnessView.swift:699-734`). The 44pt target is grounded in Apple's [accessibility reference](https://developer.apple.com/design/human-interface-guidelines/accessibility).

## Eight design principles

| Apple principle | Verdict for current source |
|---|---|
| Purpose | **Conforms** — status, sleep, evidence, indicators, and body changes follow the approved reading goal. |
| Agency | **Conforms** — details, capture, realtime, and manual entry are explicit controls. |
| Responsibility | **Conforms for inspected data** — observed sleep, forecast, measured photo score, and per-metric body comparison are identified; dated Watch value is source-checked only. |
| Familiarity | **Conforms** — Activity's compact ring, score bars, section/header navigation, and DUNE tokens recur. |
| Flexibility | **Conforms in inspected layout** — hero, body, and posture actions reflow at Maximum AX; the shared injury card keeps a one-line preview with full memo reachable through its button. Non-empty Watch metrics remain visually unverified. |
| Simplicity | **Conforms** — forecast factors and lower-priority fitness indicators are disclosed on demand. |
| Craft | **Mostly confirmed for 402pt iPhone** — light/dark hero, body, posture, and forecast have clear hierarchy; Maximum AX posture title wrapping is a polish issue. Full health-grid and contrast audit are pending. |
| Delight | **Conforms at source level** — restrained static gold/terrain details support the wellness tone. |

Principle basis: [Apple Design Principles](https://developer.apple.com/design/human-interface-guidelines/design-principles). No source edits, build, test, or simulator run were performed for this review.
