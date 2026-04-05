---
tags: [ci, github-actions, simulator, boot, timeout, retry, diagnostics]
date: 2026-04-06
category: plan
status: draft
---

# Plan: CI Simulator Boot Hardening

## Problem Statement

GitHub Actions nightly tests have been failing consistently since ~March 29, 2026. All 4 jobs (iOS unit, iOS UI, watch unit, watch UI) fail with "simulator failed to boot within 120s" on the `macos-15` runner with Xcode 26.2.

### Root Cause Analysis

1. **Runner image change**: `macos-15-arm64/20260330.0243` changed simulator availability/behavior
2. **Silent failure**: `simulator-boot.sh` suppresses boot errors (`2>/dev/null || true`) — no diagnostics
3. **No retry logic**: Single boot attempt with hard-coded 120s timeout
4. **No runtime validation**: Attempts to boot without verifying the runtime is available
5. **No diagnostic dump**: On failure, no information about available runtimes/devices is logged

### Evidence

- 5+ consecutive nightly runs fail identically (all 4 jobs, same error)
- Pre-March-29 runs had different failure patterns (1h+ timeouts, actual test failures)
- Same UDIDs appear across runs → simulator devices exist, but can't boot

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/lib/simulator-boot.sh` | Major rewrite | Add diagnostics, retry, runtime check |
| `.github/workflows/test-ui-nightly.yml` | Update | Add diagnostic step, update runner |

## Implementation Steps

### Step 1: Enhance `simulator-boot.sh` with diagnostics and retry

1. **Capture boot errors**: Remove `2>/dev/null` from `xcrun simctl boot`, log stderr
2. **Add runtime availability check**: Before boot, verify the simulator's runtime is installed and available
3. **Add retry logic**: On boot failure, `shutdown` → wait → `boot` again (max 2 retries)
4. **Increase CI timeout**: Use `SIMULATOR_BOOT_TIMEOUT` env var (default 120s, CI can set 300s)
5. **Diagnostic dump on failure**: Log `xcrun simctl list runtimes`, device state, boot errors

### Step 2: Update workflow with diagnostics and fallback

1. **Add diagnostic step**: Before test run, log `xcrun simctl list runtimes` and `xcrun simctl list devices available`
2. **Set boot timeout**: Pass `SIMULATOR_BOOT_TIMEOUT=300` to test scripts
3. **Try `macos-latest` runner**: If `macos-15` can't boot Xcode 26 sims, `macos-latest` may map to macOS 26

## Test Strategy

1. **Local test**: Run `scripts/test-unit.sh --ios-only` locally to verify script changes don't break local workflow
2. **CI test**: Trigger manual workflow dispatch after merge to verify nightly passes
3. **Edge case**: Verify graceful failure message when runtime truly unavailable

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| `macos-latest` may not map to macOS 26 yet | Keep `macos-15` as documented fallback, add comment |
| Increased timeout slows down actual test failures | Retry logic catches boot-specific failures faster than waiting full timeout |
| Runtime check adds startup time | Minimal overhead (~1s for `simctl list runtimes`) |

## Alternatives Considered

1. **Pin runner image version**: Rejected — fragile, doesn't solve root cause
2. **Skip simulator boot, let xcodebuild handle it**: Rejected — this was the pre-March-30 approach that caused 45-min hangs
3. **Disable nightly tests**: Rejected — tests are needed for quality gate
