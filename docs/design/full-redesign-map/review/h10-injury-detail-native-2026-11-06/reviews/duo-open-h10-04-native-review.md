# H09/H10 Duo open route review

**Scope:** Independent read-only native PNG/AX review of H09 History → H10 Detail at source `04e2ec0add31d110734452d854767a25407b7eca`, Duo open, English/Light, normal text. Owned UID `8F673AD3-77DB-4951-9824-84B302DF4299`; hinge readback `180.0` before and after. LCD1 was active and LCD0 inactive. Active files are named `2007x2853` and contain `2853×2007` pixels. The single H10 SDK method passed (`1/1`, no skip). [SHA inventory](duo-open-h10-04-native-review.json) contains 14 named PNG/AX pairs from checkpoints 002–015.

## Finding

- **P3 — redundant decorative status image in AX.** H10 exposes `Active` and later `Recovered` as text plus a separate symbol image (`Adhesive Bandage Strip, Filled` / `Selected`). This is the same pre-existing AX tree detail observed on other profiles; VoiceOver traversal was not run.

No P1/P2 or new route-specific native finding in the reviewed open Duo evidence.

## Evidence readback

| Checkpoints | PNG/AX observation |
|---|---|
| 002–004 · H09 | Active Knee and recovered Shoulder show original fields, symbols, badges, dates, and manual trailing chevrons. AX row Buttons are `847×88` pt with complete labels and original `injury-history-row-0/1` IDs. |
| 005–008 · first tap and H10 | The first Knee row tap opens Injury Detail. Knee / Left / Minor / Active / 5 days, severity guidance, timeline Start Nov 1 / End Ongoing / Recorded Nov 6, and memo “Mild pain during squats” are visible and have matching AX content. |
| 009–010 · Edit Save | Edit Injury sheet opens with Cancel/Save. Save returns to the same detail, preserving the fields and Mark Recovered action. |
| 011–012 · Mark Recovered | One action changes the still-open detail to `Recovered`; AX retains `injury-detail-screen`, status is `Recovered`, and `injury-detail-mark-recovered` is absent. Timeline and memo remain visible. |
| 013–015 · Back to H09 | History shows only Recovered section with Knee and Shoulder. Knee row has no Active badge and its AX label has ended `11/1 ~ 11/6`; the before-teardown capture confirms this state. |

No clipped content, icon/text collision, control overlap, or misplaced chevron is seen at this normal text size. This selector-scoped pass does not establish MAX Dynamic Type, Dark appearance, other locales, VoiceOver speech order, swipe/context gestures, or a full regression run. No Root tracked file, app source, simulator, build, or test was changed by this review.

**Archive:** `.codex-checks/batch01/evidence/duo-open-h10-04e2ec0a-passed/{execution-metadata.json,summary.json,result.json,host/checkpoints.jsonl,host/angle-before.txt,host/angle-after.txt,host/displays-before.json,host/displays-after.json,host/NNN-2007x2853.png,host/NNN-hierarchy.txt}`.
