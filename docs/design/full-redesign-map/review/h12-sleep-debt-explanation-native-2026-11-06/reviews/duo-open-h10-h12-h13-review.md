# Duo open native review: H10, H12, H13

**Disposition:** No P1/P2 finding in the reviewed native captures. This is a read-only, scoped visual and AX review of source revision `2d1656bb` on the Duo's active internal display. The archive's four selected SDK cases passed with zero skips; this report reviews H10, H12, and H13 only. H11 belongs to the other independent reviewer.

## Evidence identity

- Archive: `/Users/shanks/.codex/worktrees/detail-redesign-l03/Health/.codex-checks/batch01/evidence/duo-open-2d1656bb-passed`
- SDK `summary.json`: 4 passed, 0 failed, 0 skipped; configuration `Duo Visual Audit`, iOS Simulator 27.2, device `081F5764-D395-45A7-9ABE-A6AFE879F4A6`.
- Both `angle-before.txt` and `angle-after.txt`: `180.0`. Both display readbacks: outer `LCD` 1398×2034 inactive/off; internal `LCD-1` 2007×2853 active/on, orientation `rot90`. Reviewed only `*-2007x2853.png` and matching hierarchy text; black outer captures are excluded.
- Per-file SHA-256 inventory: `duo-open-h10-h12-h13-review.json` in this directory. The inventory covers 18 selected checkpoints, each active-display PNG and hierarchy pair, plus metadata hashes.

## H10 Injury Detail

- Checkpoint 020 shows the active Knee hero with Left, Minor, Active/bandage symbol, 5 days, and “Can exercise with caution.” The white hero uses clear spacing and legible contrast on the wide internal display. AX fields independently match these labels.
- Checkpoints 020–022 expose Timeline: Start `Nov 1, 2026`, End `Ongoing`, Recorded `Nov 6, 2026 at 00:53`; 022 shows the Memo `Mild pain during squats`. The timeline and memo remain readable after scrolling, with no observed overlap or clipping.
- 023 opens Edit with the existing selection visible; 024 returns to detail after Save; 025/026 return to History and show its marker. AX retains `injury-detail-mark-recovered` and `injury-detail-edit`. This case does not execute Mark Recovered or inspect a recovered detail.

## H12 Sleep Debt explanation

- 003 shows the complete “How Sleep Debt Works” hero, separate symbol, 44-point Close control, Baseline, How It Adds Up, and Excess Sleep copy in the centered sheet. 004 reaches all Levels rows: Well Rested `< 2h`, Slightly Short `2–5h`, Sleep Debt `5–10h`, Severe Debt `> 10h`. The original small color indicators remain alongside the symbols; rows and ranges have clear separation and no observed clipping.
- 005/006 show the sheet dismissed and the underlying Sleep detail. The sheet AX marker is absent after Close.

## H13 WASO explanation

- 008 shows the medium-detent hero “What is WASO?” and Definition start. 009–011 show the expanded/scrollable Definition, How It's Measured, and Scoring sections and original body copy. 012 reaches the Score Guide rows: Excellent `< 10 min`, Good `10–20 min`, Fair `20–30 min`, Poor `> 30 min`, with their symbols and original color indicators. The text and ranges are readable without observed overlap or clipping.
- 013/014 show Close dismissal to the underlying Sleep detail; the sheet AX marker is absent.

## Limits

This review covers open Duo, standard text size, Light appearance, seeded cases, and the selected H10/H12/H13 checkpoints. It does not establish Dark, MAX, iPad, empty data, recovered injury detail, or other route behavior. Native visual/AX findings here do not replace the archived SDK result or expand its four-case scope.
