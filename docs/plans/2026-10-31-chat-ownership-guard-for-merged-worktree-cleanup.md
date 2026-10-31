---
topic: Fail-closed ownership guard for merged-worktree cleanup
date: 2026-10-31
status: approved
confidence: high
related_solutions: [2026-10-31-auto-merged-worktree-cleanup]
---

# Implementation Plan: Fail-closed merged-worktree cleanup

## Context

The automatic Git hook can delete a clean merged checkout still owned by a paused Codex chat. Process and open-file checks do not establish chat ownership. No authoritative local chat-status source is available to this hook.

## Requirements and approach

- A `main` or `origin/main` reference update may inspect and log merged candidates but must never delete a branch, worktree, simulator, or DerivedData without authoritative chat-release proof.
- Use the existing read-only `cleanup(root, apply=False)` path for the hook. This is an explicit fail-closed policy until an authoritative owner/release source is introduced and reviewed. Keep the existing `--apply` path for an explicitly owner-approved manual `/ship` or `/cleanup` action.
- Preserve GitHub PR proof, dirty/untracked/ignored checks, locks, process/open-file checks, ref compare-and-delete, and owner-only simulator/DerivedData logic in the manual path. Do not add a heuristic override.
- Keep `dune.autoCleanupMerged=false` in the real repository during development. This work does not install or update the live hook bundle.

## Files and steps

1. Update `scripts/cleanup-merged-worktrees.py` so `hook` invokes the read-only path and emits an ownership-gate message.
2. Change `scripts/tests/test_cleanup_merged_worktrees.py` disposable-repository contracts: the real reference hook must preserve clean merged attached and unattached branches with empty process/file inventory; verify explicit manual apply still removes verified candidates. Include unknown owner as fail-closed.
3. Update `.codex/skill-compat.md` and `AGENTS.md` to state audit-only automatic behavior and explicit manual ownership approval. Run only the targeted Python contract module once with the standard pipeline wrapper and a deadline.

## Edge cases and validation

An idle chat may have no process, open file, uncommitted change, or ignored file. Missing chat metadata is not evidence of release. The automatic path therefore never performs destructive cleanup. A read-only audit can still fail due to GitHub or filesystem errors; hook failure must not block the Git reference update. The targeted disposable-repository test must prove both sides of the boundary; no app build or simulator is involved.

## Tradeoff

Automatic deletion is suspended until a trustworthy chat ownership/release API exists. The hook still reports candidates; an explicitly approved owner can run manual cleanup. This favors preserving an active chat over reclaiming idle storage.
