---
tags: [review, codex, session-audit, simulator, concurrency]
category: review
date: 2026-10-25
status: resolved
---

# Code Review Report

> Date: 2026-10-25
> Scope: Session usage audit and isolated UI runner improvements against origin/main
> Files reviewed: 18 implementation/documentation files; this report records dispositions

## Summary

| Priority | Count | Status |
|---|---:|---|
| P1 - Critical | 0 | None |
| P2 - Important | 4 | Resolved (includes one Resolve recheck finding) |
| P3 - Minor | 1 | Resolved |

Security, Performance, Architecture, Data Integrity, Simplicity and Agent-Native reviews ran independently in two parallel waves. App quality is assessed for tooling only; no app/UI/catalog changes are included. Localization is not applicable. The original Today branch and all unrelated dirty app/design files remain outside this PR.

## P1 Findings

None.

## P2 Findings

### [Data Integrity] data-001 — Legacy reset deduplication

- **File**: `scripts/audit-agent-sessions.py`
- **Issue**: A cumulative sequence such as 10 → 20 → 10 → 20 within one turn can have legitimate reset values discarded as duplicate archive entries.
- **Resolution**: Include timestamp and event identity in deduplication; copied 10 → 20 → 10 → 20 fixtures total 40 with four usage events.
- **Status**: Resolved.

### [Performance] perf-001 — Outside-window history retention

- **File**: `scripts/audit-agent-sessions.py`
- **Issue**: Full normalized usage records are retained for all lifetime history even for a narrow window.
- **Resolution**: Keep full normalized usage only for eligible window records, pre-start ID tombstones, and latest per-session legacy baselines. Compact ID sets still grow with history; constant memory is not claimed.
- **Status**: Resolved.

### [Agent-Native] agent-001 — Manual capture lock scope

- **File**: `.codex/ui-execution.md`
- **Issue**: The manual capture instruction unconditionally requires a repository lock despite the approved isolated worktree exception.
- **Resolution**: Require the selected scope's lock, with repository as default and the same isolation checks before opting into worktree scope.
- **Status**: Resolved. Default serialization and same-worktree exclusion remain explicit.

### [Performance] perf-002 — Unrelated late files reread during Resolve

- **File**: `scripts/audit-agent-sessions.py`
- **Issue**: The initial memory fix reread every path containing late Claude blocks even when message IDs did not overlap the window.
- **Resolution**: Track compact late IDs by path and reread only paths intersecting eligible message IDs. Regression confirms an overlapping path is read twice and an unrelated path once.
- **Status**: Resolved.

## P3 Findings

### [Security] sec-001 — Private output file permissions

- **File**: `scripts/audit-agent-sessions.py`
- **Issue**: Detailed local audit JSON can be created with permissions broader than the owner.
- **Resolution**: Same-directory temporary output, explicit mode 0600, fsync and atomic replace; 0644 replacement and symlink-target preservation tests pass.
- **Status**: Resolved.

## Verification

The 18 copied task files initially matched the tested original worktree byte for byte. Existing evidence includes locked-host iPhone and Watch targeted XCTest (one each, six new PNGs), audit/host contracts, lock/deadline/registry contracts, runner integration, shell syntax and parity. Changes during Resolve require focused new checks; unchanged simulator integration is reused. The user explicitly chose to finish with locked-state results, so unlocked A/B is deferred rather than a shipping gate.

## Next Steps

All findings have been rechecked against the current diff; none remain open. Final PR/quality review and remote merge are recorded by the ship workflow.

Resolve verification: audit synthetic suite **14/14 passed**. An actual-window rescan preserved token totals, all provider/model/project/role groups, event counts, tool counts and output proxy totals. Output mode is 0600. Extra files discovered after the original audit contain no events in the fixed window.
