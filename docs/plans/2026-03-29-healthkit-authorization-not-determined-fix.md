---
tags: [healthkit, authorization, breathing-disturbance, error-handling, race-condition]
date: 2026-03-29
category: plan
status: approved
---

# Plan: Fix HealthKit "Authorization not determined" error for breathing disturbance queries

## Problem

`[Sleep] Breathing disturbances fetch failed: DUNE.HealthKitError.queryFailed("Authorization not determined")`

HealthKit queries throw "Authorization not determined" when `requestAuthorization()` hasn't been called yet. The deferred authorization pattern (from `2026-03-11-launch-permission-deferral-stability.md`) only gates Dashboard queries via `canLoadHealthKitData`, but other views (Wellness tab → MetricDetailViewModel) can trigger HK queries before auth is requested.

## Root Cause

1. `DUNEApp` calls `requestAuthorization()` as a **deferred** task after launch experience completes
2. `canLoadHealthKitData` flag only flows to `DashboardView` / `DashboardViewModel`
3. `MetricDetailViewModel.loadBreathingDisturbances()` (line 466-472) queries HK without this gate
4. `HealthKitManager.execute()` wraps the raw HK error as `HealthKitError.queryFailed("Authorization not determined")`
5. Same issue affects `AllDataViewModel` and potentially other HK query paths

## Solution: Graceful empty-result fallback in HealthKitManager.execute()

Instead of plumbing `canLoadHealthKitData` through every view hierarchy (high blast radius), handle the "Authorization not determined" error at the source — `HealthKitManager`.

When `execute()` catches an HKError with code `.errorAuthorizationNotDetermined`, return empty results instead of throwing. This is consistent with Apple's design: read-only types return empty data when access is denied.

### Affected Files

| File | Change | Risk |
|------|--------|------|
| `DUNE/Data/HealthKit/HealthKitManager.swift` | Catch HKError `.errorAuthorizationNotDetermined` in `execute()`, `executeStatistics()`, `executeStatisticsCollection()` — return empty/nil | Low — graceful degradation |

### Implementation Steps

**Step 1**: Modify `execute<S: HKSample>()` to catch `HKError.errorAuthorizationNotDetermined`
- Return empty array `[]` instead of throwing
- Log at `.info` level (not `.error`) since this is expected during startup

**Step 2**: Modify `executeStatistics()` to catch the same error
- Return `nil` instead of throwing

**Step 3**: Modify `executeStatisticsCollection()` to catch the same error
- Return empty `HKStatisticsCollection` or rethrow (depending on API)
- Since `HKStatisticsCollection` has no public empty initializer, check if `nil` return is feasible or if throwing is needed here
- Callers already handle errors, so logging at `.info` and rethrowing with a clearer message is acceptable

### Test Strategy

- Update existing `SleepViewModelTests` or `BreathingDisturbanceQueryServiceTests` to verify no throw on auth-not-determined
- Verify existing tests still pass

### Edge Cases

- App cold start where auth is pending → queries return empty, views show placeholder → auth granted → refresh triggers → queries return real data
- This matches the existing Dashboard behavior

### Risks

- None significant — returning empty for "auth not determined" matches "auth denied" behavior for read types
