---
tags: [ci, github-actions, simulator, timeout, xcodebuild, test-infrastructure, pre-boot]
category: testing
date: 2026-03-30
status: implemented
severity: important
related_files:
  - scripts/lib/simulator-boot.sh
  - scripts/test-unit.sh
  - scripts/test-ui.sh
  - scripts/test-watch-ui.sh
  - DUNEWatchTests/WatchRPEEstimatorTests.swift
related_solutions:
  - docs/solutions/testing/2026-03-08-ui-smoke-toolbar-tap-stability.md
---

# Solution: CI Simulator Boot Timeout Fix

## Problem

GitHub Actions nightly test runs consistently failed (5/5 recent runs) with two distinct root causes.

### Symptoms

1. **Watch unit test**: `WatchRPEEstimatorTests.swift:142` — compilation error "missing argument for parameter 'duration' in call" (exit code 65)
2. **iOS unit test**: Build succeeded at 19:38, but xcodebuild hung for 42 minutes with zero test output before 45-min timeout killed it
3. **iOS UI test**: Tests started running but individual tests exceeded 2-min allowance → "Failed to terminate app" → cascading failures → 90-min timeout
4. Watch UI test: consistently passed (only successful job)

### Root Cause

1. `CompletedSetData` gained a `duration: TimeInterval?` field, but `WatchRPEEstimatorTests.makeSet()` helper was not updated
2. `test-unit.sh` had no simulator pre-boot — relied entirely on `xcodebuild test` to boot the simulator, which intermittently hangs on GitHub Actions `macos-15` runners
3. `test-ui.sh` had pre-boot but no boot-wait verification, plus a too-aggressive 120s default test execution time allowance (some CI tests take 170+ seconds)

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatchTests/WatchRPEEstimatorTests.swift` | Add `duration: nil` to `makeSet()` | Match updated `CompletedSetData` init |
| `scripts/lib/simulator-boot.sh` | New shared helper with `timeout 5` wrapped `simctl` check | DRY + prevent `simctl` itself from hanging |
| `scripts/test-unit.sh` | Add pre-boot via shared helper | Prevent 45-min hang on simulator boot |
| `scripts/test-ui.sh` | Use shared boot helper + increase time allowances (300s/600s) | Fail-fast boot + prevent cascading failures |
| `scripts/test-watch-ui.sh` | Use shared boot helper | Consistency |

### Key Code

```bash
# scripts/lib/simulator-boot.sh
wait_for_simulator_boot() {
    local udid="$1" label="$2" timeout=120 elapsed=0
    xcrun simctl boot "$udid" 2>/dev/null || true
    while [[ "$elapsed" -lt "$timeout" ]]; do
        if timeout 5 xcrun simctl list devices 2>/dev/null \
            | grep "$udid" | grep -q "Booted"; then
            return 0
        fi
        sleep 2; elapsed=$((elapsed + 2))
    done
    echo "ERROR: ${label} simulator failed to boot within ${timeout}s."
    exit 1
}
```

## Prevention

### Checklist Addition

- [ ] @Model 필드 추가 시 모든 테스트 헬퍼도 업데이트되었는지 확인
- [ ] CI 테스트 스크립트 수정 시 `scripts/lib/simulator-boot.sh` 재사용 여부 확인

### Rule Addition (if applicable)

Not needed — covered by existing `testing-required.md` rule. The `@Model` field sync issue is a general discipline matter, not a new pattern.

## Lessons Learned

- `xcodebuild test`의 implicit simulator boot는 CI에서 비결정적으로 hang할 수 있다. 항상 explicit pre-boot + timeout 대기가 안전하다.
- `simctl list devices` 자체도 CoreSimulator daemon 문제 시 hang 가능 → `timeout` 래퍼 필수
- 테스트 time allowance는 CI 환경의 실제 실행 시간을 기준으로 설정해야 한다 (로컬 기준 X)
- Watch 시뮬레이터는 iOS보다 안정적으로 부팅됨 — iOS 시뮬레이터에 더 방어적 접근 필요
