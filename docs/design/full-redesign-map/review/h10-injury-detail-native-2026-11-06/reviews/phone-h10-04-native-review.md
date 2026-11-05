# H09/H10 phone refresh native review

**Scope:** Independent read-only review of H09 History row → H10 Detail at source `04e2ec0add31d110734452d854767a25407b7eca`, iPhone 18 Pro Max, English/Light, normal text. The `1320×2868` capture archive passed all three requested SDK cases (H10, H12, H13); this report judges **H10 only**. [Evidence inventory](phone-h10-04-native-review.json) records 13 named PNG/AX pairs, exact source hashes, and SHA-256 values.

## Findings

- **P3 — redundant status symbol remains in AX.** H10 exposes the status text and its decorative image as separate elements: `Active` plus `Adhesive Bandage Strip, Filled`, then `Recovered` plus `Selected`. The visible text is complete. This is the same pre-existing AX tree detail seen on iPad and Duo, with VoiceOver traversal untested.

No P1/P2 or new H09/H10 route finding in the reviewed phone evidence.

## Evidence readback

| State | Native PNG and AX observation |
|---|---|
| H09 before tap | Active Knee and recovered Shoulder rows show original symbols, labels, durations, dates, and right chevrons. The whole row is an AX Button (`400×88` pt), with `injury-history-row-0/1` and complete labels. |
| First tap → H10 | The tap capture is already Injury Detail. Knee / Left / Minor / Active / 5 days, severity guidance, timeline start Nov 1 / end Ongoing / recorded Nov 6, and memo “Mild pain during squats” are visible in the normal viewport; matching detail IDs appear in AX. |
| Edit → Save | The Edit Injury form opens with Cancel/Save. Save dismisses it, returns to the same H10 detail, and retains Mark Recovered plus the unchanged data. |
| Mark Recovered | One action changes the still-open detail to `Recovered`; AX has `injury-detail-screen` and status `Recovered`, with **no** `injury-detail-mark-recovered`. The memo and timeline persist and the green recovered chip is visible. |
| Back → H09 | History returns with only Recovered section. Knee and Shoulder remain, and Knee's row label has an ended `11/1 ~ 11/6` range and no `Active`; the final before-teardown capture confirms the same classification. |

No clipped content, chevron collision, or control overlap is seen in the selected normal-size phone PNGs. This evidence does not establish MAX Dynamic Type, Dark appearance, other locales, VoiceOver speech order, or swipe/context gestures. The new route's Duo states are separate pending checks. No simulator, build, test, app source, or Root tracked file was changed for this review.

**Archive:** `.codex-checks/batch01/evidence/phone-refresh-04e2ec0a-passed/{execution-metadata.json,summary.json,result.json,run.xcresult,attachments/}`. Names and UUIDs for paired attachments came from read-only `xcresulttool get test-results activities` output.
