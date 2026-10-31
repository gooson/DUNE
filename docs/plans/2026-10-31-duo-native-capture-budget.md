---
topic: Bounded Duo native screenshot command budget
date: 2026-10-31
status: in_progress
confidence: high
---

# Plan: bounded Duo native screenshot command budget

## Problem and scope

T09's owned Duo open captures twice failed the screenshot subprocess's eight-second cap while the enclosing checkpoint retained time. The only approved executor change is `timeout=min(8, budget)` to `min(15, budget)` in `scripts/duo-visual-audit.py`. Keep the 25-second whole checkpoint, ordinary 30-second hold, two-second deadline margin, two built-in displays, fresh nonempty PNG and hierarchy, and safe ACK checks unchanged. This is a separate tooling PR; no app, UI fixture, device or product mock changes.

## Steps

1. Freeze the clean worktree and inspect the existing capture contract, proposal and `CaptureContracts` tests. Do not consume the approved one future T09 Duo open integration attempt in this tool branch.
2. Make the one-line cap change. Add focused fake-clock tests in `scripts/tests/test_duo_visual_audit.py`: a nine-second primary can complete inside a 25-second checkpoint; a screenshot exceeding its allocated cap still fails; a short remaining deadline bounds timeout and prevents ACK. Retain existing expired/stale/unsafe-path and two-display tests.
3. Run Python syntax checks and the exact `scripts.tests.test_duo_visual_audit` module once through the standard `codex-pipeline.py` unit wrapper with a bounded owner deadline. Inspect raw receipt, diff and changed-file scope. Independent reviewers and the parent own later Review/Compound/Ship.

## Acceptance and limits

The fake-clock success must produce two fresh PNGs, hierarchy and ACK; both failure cases must leave no ACK and mark invalid evidence. No native Duo integration, app build or broad regression is part of this tool PR verification. Preserve original T09 failed receipts and retry counters; the one user-approved future integration remains unconsumed.
