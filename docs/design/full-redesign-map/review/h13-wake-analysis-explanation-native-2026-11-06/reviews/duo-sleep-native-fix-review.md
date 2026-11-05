# H12/H13 Duo closed native fix review

Source revision `2d1656bb83a3a41ce02e1c41352769e0a867b032`. Read-only review of the final archive `.codex-checks/batch01/evidence/duo-closed-sleep-2d1656bb-passed`, using 1398 × 2034 active-display PNGs, paired AX hierarchies, runner result, and device metadata. Selected 25 capture pairs and SHA-256 hashes are in `duo-sleep-native-fix-review.json`; 23 of those PNGs were visually inspected. No simulator or test was run by this reviewer.

## Result

**The two previously reported MAX P2 visual defects are resolved in this Duo closed Light sample. No new P1/P2 finding in the sampled sheets.**

- H12 MAX `011` displays “How Sleep / Debt Works” as two complete-word lines. H13 MAX `020` displays “What is / WASO?” as complete-word lines. The info icon and Close sit in their own top row; both Close controls are visible without covering the title.
- H12 Baseline `011`, How It Adds Up `013`, Excess Sleep `015`, and the visible Levels rows `017` have separation between SF Symbol and heading/label. H13 Definition `020`, How It's Measured `022`, Scoring `023`, Score Guide `025`, and all four guide rows `026` also have no visible symbol/text collision. The 8 pt color dots remain distinct beside the original symbols. H12 `017` shows the last three rows; the first “Well Rested, < 2h” remains in that capture's AX tree and is visibly readable in normal `006`, but a separate MAX PNG with that row in the viewport was not captured.
- Normal H12 `005/006` and normal H13 `030/033/034` show readable card text, original icons, and the original ranges: H12 `< 2h`, `2–5h`, `5–10h`, `> 10h`; H13 `< 10 min`, `10–20 min`, `20–30 min`, `> 30 min`. Light card text and dark hero text show clear apparent contrast. This is visual review, not a measured contrast ratio or Dark appearance check.
- The six MAX body top/bottom pairs `011/012`, `013/014`, `015/016`, `020/021`, `022/023`, and `024/025` show the full paragraph starts and ends reachable by scrolling. Intermediate viewport crops are normal scroll positions, not text clipping. The 14-day baseline, 7-day shortfall sum, excess-sleep zero floor, WASO definition, Watch/5-minute explanation, and 0–100/15% scoring facts remain visible across paired states.
- H12 close checkpoint `018` has no debt sheet in AX and retains the Sleep metric. H13 close checkpoints `027/028`, and normal H13 `035/036`, have no WASO sheet in AX and retain the Sleep metric. The destination presentation and dismissal remain demonstrated; no new navigation behavior is claimed.

## SDK and device evidence

The archive `result.json` reports exactly the three requested selectors executed, **3 passed, 0 failed, 0 skipped**, exit 0: normal H12, normal H13, and combined MAX H12/H13. `host/runner-result.json` records return code 0 and 36 acknowledged checkpoints. Hinge readback is `0.0` before and after; `displays-before.json` records a single active LCD at 1398 × 2034 and inactive second LCD at 2007 × 2853 for the owned Duo. This passes the scoped closed-Duo Light visual and selector review only; it does not attest iPad, Dark, other Dynamic Type sizes, or the rest of the app.
