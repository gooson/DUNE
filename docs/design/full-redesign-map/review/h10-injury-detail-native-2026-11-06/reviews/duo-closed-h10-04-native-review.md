# H09/H10 Duo closed route review

**Scope:** Independent read-only native PNG/AX review of H09 History rows and H10 Detail on the fresh Duo closed archive at source `04e2ec0add31d110734452d854767a25407b7eca`, English/Light, normal and maximum accessibility text. The owned Duo UID was `8F673AD3-77DB-4951-9824-84B302DF4299`; hinge readback was `0.0` before and after, active display `1398×2034` with the second display inactive. Both named H10 SDK methods passed (`2/2`, no skips). [SHA inventory](duo-closed-h10-04-native-review.json) contains 23 selected PNG/AX pairs from checkpoints 002–011 and 014–026.

## Findings

- **P3 — MAX row chevron alignment varies with text width.** The manual chevron sits just after the stacked Knee content in checkpoint 002, while the Shoulder row in 010–011 places it farther right. It remains visible, does not cross text, and the AX Button covers the full `362` pt row width. The first tap opens H10. Aligning it to the trailing edge would make the navigation affordance steadier at AX sizes.
- **P3 — MAX Recovered chip breaks the word.** The Shoulder status renders `Recov-` / `ered` in checkpoints 003–005. The entire chip is visible and AX label is `Recovered`; the split is a visual readability issue already present in prior Duo MAX evidence.
- **P3 — status symbol is separately exposed in AX.** H10 has a status text element and a second image element (`Selected` for Recovered; `Adhesive Bandage Strip, Filled` for Active). This is an existing AX tree observation. VoiceOver traversal was not run.

No P1/P2 finding in the reviewed closed Duo H09/H10 evidence.

## MAX evidence

Checkpoints 002–003 show History with the new chevron and the first tap into recovered Shoulder detail. Checkpoints 004–009 reach Shoulder / Right / Moderate / Recovered, 10 days, original severity guidance, timeline Start Oct 17 / End Oct 27 / Recorded Nov 6, and memo “Recovered shoulder strain” through scrolling. The large content expands vertically without a horizontal cut or symbol/text collision. Checkpoints 010–011 show History again with both rows and the new chevrons after Back.

## Normal evidence

Checkpoints 014–016 show Active Knee and recovered Shoulder in History, then the first row tap opens H10. Checkpoints 017–019 show Knee / Left / Minor / Active / 5 days, severity guidance, timeline Start Nov 1 / End Ongoing / Recorded Nov 6, and “Mild pain during squats”. At 020 the Edit Injury form has Cancel/Save; 021 returns to detail after Save. At 022–023 one Mark Recovered action leaves `injury-detail-screen` open, changes status to `Recovered`, keeps timeline/memo, and removes `injury-detail-mark-recovered` from AX. Checkpoints 024–026 return to History with only Recovered section; Knee and Shoulder rows remain and Knee has ended range `11/1 ~ 11/6` without an Active badge. Normal row chevrons are at the trailing edge and AX Button frames cover the row width.

This is source `04` evidence only. It does not establish Dark appearance, other locales, VoiceOver speech order, swipe/context menu gestures, or other device states. The archived SDK pass is selector scoped, not a full regression pass. No Root tracked file, app source, simulator, build, or test was changed by this review.

**Archive:** `.codex-checks/batch01/evidence/duo-closed-h10-04e2ec0a-passed/{execution-metadata.json,summary.json,result.json,host/checkpoints.jsonl,host/angle-before.txt,host/angle-after.txt,host/displays-before.json,host/displays-after.json,host/NNN-1398x2034.png,host/NNN-hierarchy.txt}`.
