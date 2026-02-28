---
tags: [healthkit, refresh, coordinator, observer, throttle, async-stream, background-delivery]
date: 2026-02-28
category: solution
status: implemented
---

# Coordinated HealthKit Refresh Architecture

## Problem

앱에 3가지 데이터 리프레시 트리거가 존재하지만 통합 관리 없이 각각 독립적으로 동작:
1. Pull-to-refresh (사용자 수동)
2. Background → Foreground 전환 (scenePhase)
3. HealthKit observer 콜백 (HKObserverQuery)

결과: 중복 리프레시, 과도한 API 호출, 일관성 없는 데이터 갱신.

## Solution

### Architecture

```
┌─────────────────────┐     ┌──────────────────────────┐
│  HealthKit Observer  │────▶│  AppRefreshCoordinator   │
│  (8 data types)      │     │  (actor, 60s throttle)   │
└─────────────────────┘     │                          │
                            │  ┌──────────────────┐    │
┌─────────────────────┐     │  │ invalidateCache  │    │
│  ScenePhase Change  │────▶│  │ yield(source)    │    │
│  (.background→.active)│    │  └──────────────────┘    │
└─────────────────────┘     │         │                │
                            │  AsyncStream<RefreshSource>
┌─────────────────────┐     │         │                │
│  Pull-to-Refresh    │─X──▶│  (bypasses coordinator)  │
│  (direct VM reload) │     └──────────────────────────┘
└─────────────────────┘              │
                            ┌────────▼─────────┐
                            │  ContentView      │
                            │  refreshSignal++  │
                            │  .task(id:)       │
                            └────────┬─────────┘
                      ┌──────────────┼──────────────┐
                      ▼              ▼              ▼
                DashboardView  ActivityView   WellnessView
```

### Key Components

1. **`AppRefreshCoordinating` (Domain protocol)**: `requestRefresh`, `forceRefresh`, `invalidateCacheOnly`, `refreshNeededStream`
2. **`AppRefreshCoordinatorImpl` (actor)**: 60s throttle, `AsyncStream<RefreshSource>` 방출
3. **`HealthKitObserverManager`**: 8개 HK 타입에 `HKObserverQuery` + `enableBackgroundDelivery` 등록
4. **ContentView**: `refreshNeededStream` 구독 → `refreshSignal` 증가 → `.task(id:)` 재실행

### Design Decisions

- **Actor vs class**: Coordinator는 actor — HealthKit 콜백(background thread) + UI(MainActor)에서 동시 접근
- **AsyncStream vs Combine**: Combine 미사용 프로젝트이므로 AsyncStream 선택. structured concurrency와 자연스럽게 통합
- **Pull-to-refresh는 coordinator 미경유**: 사용자 수동 트리거는 throttle 없이 즉시 반영해야 하므로 기존 waveRefreshable → VM.loadData() 직접 호출 유지
- **lastRefreshDate 초기값 = now**: 앱 시작 시 `.task`가 이미 데이터를 로드하므로 첫 1분은 throttle

### Observer Query Types

| Type | Frequency | 근거 |
|------|-----------|------|
| HRV (SDNN) | immediate | Condition Score 핵심 |
| Resting HR | immediate | Condition Score 핵심 |
| Sleep Analysis | immediate | Recovery Score 핵심 |
| Step Count | hourly | 일일 활동량 |
| Body Mass | hourly | 신체 조성 |
| Body Fat % | hourly | 신체 조성 |
| BMI | hourly | 신체 조성 |
| Workout | hourly | 운동 기록 |

### Review Findings & Fixes

- `HKObjectType.workoutType() as! HKSampleType` → `HKSampleType.workoutType()` (Correction #21)
- scenePhase onChange: cancel-before-spawn 패턴 적용 (Correction #16)
- `debugDescription` → `logDescription` (protocol shadow 방지)
- `addQuery` → `execute` 순서 (race safety)

## Prevention

- HKObserverQuery 콜백은 항상 `completionHandler()` 호출 (defer 패턴)
- Background delivery는 UIBackgroundModes 불필요 — HealthKit 자체 메커니즘
- AsyncStream continuation은 앱 수명과 동일하므로 finish 불필요
- Actor isolation이 throttle state의 race condition 자동 방지
