# iPad mini native review: H12 and H13

**Scope and disposition:** Read-only review of the two passing normal Light iPad mini Sleep explanation cases at App revision `2d1656bb`. No P1/P2 visual finding in these two screens. The full archive is **not a passing batch**: 3 cases passed, 1 H10 case failed, 0 skipped. H11 is outside this review.

Archive: `/Users/shanks/.codex/worktrees/detail-redesign-l03/Health/.codex-checks/batch01/evidence/ipad-2d1656bb-partial-failed`. SDK configuration `Design Capture`, iPad mini (A20 Pro), iOS Simulator 27.2, 1512×2316. The selected PNG/AX pairs and their SHA-256 hashes are in `ipad-h12-h13-native-review.json` (10 pairs: open, body, guide, close, teardown for each screen).

## H12 — `testSleepDebtExplanationOpens()` — Passed

- Open/body captures `92C728F6...` and `910E042C...` show a centered sheet with complete “How Sleep Debt Works” title, separate information symbol, visible Close control, and readable Baseline, How It Adds Up, and Excess Sleep copy. The initial medium detent clips the beginning of Levels at its viewport bottom as expected; the expanded levels capture supplies that content.
- Expanded capture `7C618806...` shows every level and original range: Well Rested `< 2h`, Slightly Short `2–5h`, Sleep Debt `5–10h`, Severe Debt `> 10h`. Distinct SF symbols and original colored dots are visible; labels and right-aligned ranges do not overlap.
- Close capture `4862F591...` and teardown show the underlying Sleep screen. The close hierarchy lacks `sleep-debt-info-sheet`.

## H13 — `testWakeAnalysisExplanationOpens()` — Passed

- Open/body captures `724F42CD...` and `D713BB16...` show “What is WASO?”, the separate moon symbol, Close, and readable Definition, How It's Measured, and Scoring copy. Original explanation text and figures, including 5 minutes and 15%, remain present in AX.
- Expanded guide capture `36B7C369...` shows Excellent `< 10 min`, Good `10–20 min`, Fair `20–30 min`, Poor `> 30 min`, with distinct SF symbols and original colored dots. Labels, ranges, and section icons are visually separated and readable.
- Close capture `9675B7E0...` and teardown show the underlying Sleep screen. The close hierarchy lacks `sleep-waso-info-sheet`.

This visual conclusion covers only normal text size, Light appearance, the two seeded iPad mini explanation routes, and these archived states. It does not establish MAX, Dark, empty data, H10, or H11 quality. No SDK rerun or Root tracked write was performed for this review.
