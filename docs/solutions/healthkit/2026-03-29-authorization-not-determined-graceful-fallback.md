---
tags: [healthkit, authorization, error-handling, breathing-disturbance, race-condition, deferred-auth]
date: 2026-03-29
category: healthkit
status: implemented
severity: important
related_files:
  - DUNE/Data/HealthKit/HealthKitManager.swift
related_solutions:
  - docs/solutions/architecture/2026-03-11-launch-permission-deferral-stability.md
---

# Solution: Graceful fallback for HealthKit "Authorization not determined" queries

## Problem

HealthKit queries fail with `HKError.errorAuthorizationNotDetermined` when `requestAuthorization()` hasn't been called yet. This manifests as error-level log noise during app startup:

```
[Sleep] Breathing disturbances fetch failed: DUNE.HealthKitError.queryFailed("Authorization not determined")
HK sample query failed: Authorization not determined
```

### Root Cause

The deferred authorization pattern (introduced in `2026-03-11-launch-permission-deferral-stability.md`) gates Dashboard HK queries via `canLoadHealthKitData`, but other code paths (MetricDetailViewModel, AllDataViewModel, WellnessViewModel) can trigger HK queries before auth is requested. The `HealthKitManager.execute()` methods caught these as generic errors and logged at `.error` level.

## Solution

Catch `HKError.errorAuthorizationNotDetermined` specifically in all three `HealthKitManager` execute methods:

| Method | Auth-not-determined behavior |
|--------|------------------------------|
| `execute()` (sample queries) | Return `[]` + log `.info` |
| `executeStatistics()` | Return `nil` + log `.info` |
| `executeStatisticsCollection()` | Rethrow as `queryFailed` + log `.info` (no empty initializer available) |

This matches Apple's design for read-only types: denied access returns empty data, not errors.

## Prevention

- When adding new HK query paths, the execute methods now handle auth-not-determined gracefully — no per-caller gating needed
- The `canLoadHealthKitData` gate remains for Dashboard (intentional optimization to avoid unnecessary empty queries), but it's no longer the only defense

## Lessons Learned

- Centralized error handling at the data access layer is more robust than plumbing authorization gates through every view hierarchy
- HealthKit's `authorizationStatus(for:)` is unreliable for read types (always returns `.notDetermined`) — the actual error code from query execution is the reliable signal
