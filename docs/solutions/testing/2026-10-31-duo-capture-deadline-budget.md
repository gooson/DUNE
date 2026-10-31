---
tags: [duo, native-capture, deadline, subprocess-timeout, fail-closed]
category: testing
date: 2026-10-31
severity: important
related_files:
  - scripts/duo-visual-audit.py
  - scripts/tests/test_duo_visual_audit.py
related_solutions: []
---

# Bound each Duo screenshot inside the checkpoint deadline

## Problem

T09 Duo captures produced PNG files but failed the original per-command eight-second deadline. A valid-looking file does not establish a successful capture: both display commands and the checkpoint acknowledgment must satisfy the complete contract.

The capture command used `min(8, budget)` even when the existing checkpoint still had enough bounded time. The user approved a separate tooling change and one later T09 integration attempt.

## Solution

Use `timeout=min(15, budget)` for each screenshot subprocess. Keep the existing 25-second host checkpoint, the ordinary 30-second test hold, the two-second margin, fresh nonempty images for both displays, hierarchy validation, safe paths and acknowledgment checks unchanged. Timeouts still fail closed.

The targeted standard pipeline run passed all 33 tests. Three fake-clock contracts exercise a nine-second first screenshot followed by the second display, a command exceeding fifteen seconds, and a short remaining deadline that caps the command and prevents acknowledgment.

The actual T09 Duo integration is a separate pending consumer check. Its two earlier failures remain recorded; the approved additional attempt has not been consumed by the unit suite.

## Prevention

- Allocate subprocess time from the remaining checkpoint budget, not from file presence.
- Keep success, timeout and insufficient-budget tests independent of real wall-clock sleeps.
- Preserve original failed runs and distinguish tool contract tests from native app evidence.

## Lessons Learned

A per-command cap can reject a valid bounded operation while a larger whole-operation deadline remains. Raising that cap safely requires preserving the outer deadline and all freshness and acknowledgment conditions.
