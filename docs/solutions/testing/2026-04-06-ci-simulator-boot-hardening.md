---
tags: [ci, github-actions, simulator, timeout, retry, diagnostics, boot, backoff]
category: testing
date: 2026-04-06
status: implemented
severity: important
related_files:
  - scripts/lib/simulator-boot.sh
  - .github/workflows/test-ui-nightly.yml
  - .github/workflows/test-ui.yml
  - .github/workflows/test-unit.yml
related_solutions:
  - docs/solutions/testing/2026-03-30-ci-simulator-boot-timeout.md
  - docs/solutions/testing/2026-03-03-ios-build-destination-fallback-hardening.md
---

# Solution: CI Simulator Boot Hardening (Retry + Diagnostics)

## Problem

All 4 nightly CI jobs (iOS unit, iOS UI, watch unit, watch UI) failed consistently since March 29, 2026. Every run showed the same pattern: simulators found by UDID but failed to boot within 120s.

### Symptoms

- All 4 jobs in `test-ui-nightly.yml` fail with `ERROR: {platform} simulator failed to boot within 120s`
- 5+ consecutive nightly runs identically affected
- No useful diagnostics in CI logs — boot errors suppressed by `2>/dev/null || true`
- Coincided with GitHub Actions runner image update (`macos-15-arm64/20260330.0243`)

### Root Cause

1. **Boot errors silently suppressed**: `xcrun simctl boot "$udid" 2>/dev/null || true` hid the actual failure reason
2. **No retry logic**: Single boot attempt — if boot failed for transient reasons, no recovery
3. **Fixed 120s timeout**: Insufficient for cold boot on CI runners, no way to override
4. **No diagnostic dump**: On failure, no information about available runtimes/devices was logged
5. **Runner image change**: `macos-15-arm64/20260330.0243` likely changed simulator boot behavior

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `scripts/lib/simulator-boot.sh` | Full rewrite: retry, backoff, diagnostics, validation | Fix silent failures + add resilience |
| `.github/workflows/test-ui-nightly.yml` | Add env vars + diagnostic step | Extended timeout/retries + runtime visibility |
| `.github/workflows/test-ui.yml` | Add env vars + diagnostic step | Same hardening for PR tests |
| `.github/workflows/test-unit.yml` | Add env vars + diagnostic step | Same hardening for PR tests |

### Key Design Decisions

1. **Stepped backoff**: Poll interval 2s→4s→6s→8s→10s (capped). Reduces simctl calls from ~150 to ~30 over 300s
2. **Configurable via env**: `SIMULATOR_BOOT_TIMEOUT` (default 120s) and `SIMULATOR_BOOT_RETRIES` (default 1). CI sets 300s/2
3. **Boot error capture**: Removed `2>/dev/null` — stderr logged (truncated to 200 chars for safety)
4. **Pre-flight UDID check**: Validates device exists before attempting boot
5. **Integer validation**: Env vars validated as integers to prevent bash arithmetic errors
6. **Unified diagnostics**: All workflow diagnostic steps use identical grep pattern

## Prevention

### Checklist Addition

- [ ] CI simulator boot scripts must capture and log errors (no `2>/dev/null` on boot commands)
- [ ] Boot functions must have configurable timeout and retry with diagnostic dump on failure
- [ ] Runner image updates should be monitored (check nightly run status after image date changes)

### Monitoring

Watch for pattern in nightly runs:
- All 4 jobs fail simultaneously with boot timeout → likely runner image issue
- Single job fails → likely test-specific issue

## Lessons Learned

- **Never suppress boot errors silently** — `2>/dev/null || true` on critical commands makes CI failures undiagnosable
- **Runner images change without notice** — GitHub Actions updates `macos-15-arm64` image periodically; simulator behavior can change
- **Diagnostic steps are cheap insurance** — `xcrun simctl list runtimes` before tests gives instant visibility into runtime availability
- **Stepped backoff matters** — fixed 2s poll with 300s timeout creates 150 unnecessary process spawns
