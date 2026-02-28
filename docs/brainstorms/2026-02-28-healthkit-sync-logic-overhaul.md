---
tags: [healthkit, sync, background-delivery, observer-query, pull-to-refresh, foreground-refresh, performance]
date: 2026-02-28
category: brainstorm
status: draft
---

# Brainstorm: HealthKit 싱크 로직 전면 점검

## Problem Statement

현재 앱은 HealthKit 데이터를 **수동 pull-to-refresh** 또는 **최초 `.task`** 실행 시에만 가져옴. 백그라운드에서 포그라운드 복귀 시 자동 갱신이 없고, HealthKit 변경을 실시간으로 감지하지 못함. 사용자가 Apple Watch에서 운동 완료 → 앱 전환 시 최신 데이터가 반영되지 않아 "데이터 지연" 체감이 발생.

## Target Users

- Apple Watch 사용자: 운동 후 즉시 결과를 확인하고 싶은 사용자
- 다중 건강앱 사용자: 타사 앱이 HealthKit에 기록한 데이터가 자동으로 반영되길 기대
- 일상 사용자: 앱 전환(백그라운드→포그라운드) 시 항상 최신 데이터를 기대

## Success Criteria

1. **포그라운드 복귀 시 자동 갱신**: 1분 이상 백그라운드 체류 후 복귀하면 전체 탭 자동 reload
2. **HealthKit 변경 실시간 감지**: HRV, RHR, Sleep, Steps, Weight, Workout 등 주요 데이터 타입의 HealthKit Observer 등록
3. **Background Delivery**: 앱이 꺼져 있어도 HealthKit 변경 시 백그라운드 wake + 캐시 무효화
4. **기존 Pull-to-refresh 유지**: 사용자가 명시적으로 새로고침할 수 있는 경로 보존
5. **과도한 쿼리 방지**: throttle 메커니즘으로 1분 이내 중복 refresh 차단

## Current Architecture Analysis

### 현재 상태

| 기능 | 구현 상태 | 위치 |
|------|----------|------|
| Pull-to-refresh | 4개 View에서 구현 | `waveRefreshable()` modifier |
| `.task` 초기 로딩 | 모든 탭에서 구현 | 각 View의 `.task` / `.task(id:)` |
| SharedHealthDataService | 5분 TTL 캐시 | `SharedHealthDataServiceImpl` (actor) |
| 포그라운드 전환 감지 | **미구현** | — |
| HealthKit Observer | **미구현** | — |
| Background Delivery | **미구현** | — |

### 기존 데이터 흐름

```
앱 실행 → .task → VM.loadData() → SharedHealthDataService.fetchSnapshot() → HealthKit Query
                                         ↓ (5분 TTL 캐시)
Pull-to-refresh → VM.loadData() → SharedHealthDataService.invalidateCache() → HealthKit Query
```

### 목표 데이터 흐름

```
앱 실행 → .task → VM.loadData() → SharedHealthDataService.fetchSnapshot() → HealthKit Query
                                         ↓ (캐시)
포그라운드 복귀 (1분+) → invalidateCache → 전체 탭 reload signal
                                         ↓
HK Observer 트리거 → invalidateCache → 활성 탭 reload signal
                                         ↓
Background Delivery → invalidateCache → (다음 포그라운드 시 fresh fetch)
                                         ↓
Pull-to-refresh → invalidateCache → 해당 탭 reload
```

## Proposed Approach

### 1. Foreground Refresh (포그라운드 전환 시 자동 갱신)

**구현 위치**: `ContentView.swift`

**핵심 메커니즘**:
- `@Environment(\.scenePhase)` 모니터링
- `background → active` 전환 감지
- 마지막 refresh 시각 기록 → 1분 미만이면 skip
- `SharedHealthDataService.invalidateCache()` 호출
- 전체 탭에 reload signal 전달 (각 VM의 `loadData()` 트리거)

**설계 고려사항**:
- `scenePhase`는 `ContentView` 레벨에서 1곳만 감시 (탭별 중복 감시 금지)
- reload signal은 `@State refreshSignal: Int`로 전달, 각 View의 `.task(id:)` 연동
- SharedHealthDataService 캐시 무효화 → 자동으로 다음 fetch에서 fresh query
- Correction #17: Task.isCancelled 검사 후 state 업데이트

### 2. HealthKit Observer (포그라운드 실시간 감지)

**구현 위치**: `Data/HealthKit/HealthKitObserverManager.swift` (신규)

**감시 대상 HKSampleType**:

| 타입 | HKQuantityType | 영향 탭 |
|------|---------------|---------|
| HRV (SDNN) | `.heartRateVariabilitySDNN` | Today, Train |
| RHR | `.restingHeartRate` | Today, Train |
| Sleep | `.categoryType(.sleepAnalysis)` | Today, Wellness |
| Steps | `.stepCount` | Today |
| Weight | `.bodyMass` | Wellness |
| Body Fat | `.bodyFatPercentage` | Wellness |
| BMI | `.bodyMassIndex` | Wellness |
| Workout | `.workoutType()` | Train, Exercise |

**핵심 메커니즘**:
- `HKObserverQuery`로 각 타입별 변경 감지 등록
- observer callback → `SharedHealthDataService.invalidateCache()` + reload signal
- observer query는 `HealthKitObserverManager`에서 일괄 관리 (lifecycle)
- **throttle 필수**: 동일 타입 변경이 1분 이내 연속 발생 시 첫 callback만 처리

**HKObserverQuery 특성**:
- 포그라운드에서만 callback 실행 (백그라운드는 Background Delivery 필요)
- 어떤 샘플이 변경되었는지는 알려주지 않음 (변경 '발생' 사실만 알림)
- `completionHandler()` 반드시 호출해야 다음 알림 수신 가능

### 3. Background Delivery (백그라운드 wake)

**구현 위치**: `DUNEApp.swift` + `HealthKitObserverManager`

**핵심 메커니즘**:
- `HKHealthStore.enableBackgroundDelivery(for:frequency:)` 호출
- frequency: `.immediate` (HRV, RHR, Sleep) / `.hourly` (Steps, Weight 등)
- 백그라운드 wake 시 → 캐시 무효화만 수행 (무거운 쿼리 금지)
- 다음 포그라운드 진입 시 fresh data fetch

**Info.plist 요구사항**:
- `UIBackgroundModes`: `processing` (이미 있을 수 있음, 확인 필요)
- HealthKit background delivery는 별도 entitlement 불필요 (HealthKit 자체 entitlement로 충분)

**배터리 고려사항**:
- `.immediate`는 핵심 지표(HRV/RHR/Sleep)에만 사용 — Condition Score에 직접 영향
- Steps/Weight/BMI는 `.hourly`로 충분 — 시급성 낮음
- 백그라운드에서는 캐시 무효화만, 실제 쿼리는 포그라운드 진입 시

### 4. Refresh Coordination (통합 조율 레이어)

**구현 위치**: `Domain/Services/AppRefreshCoordinator.swift` (신규)

**역할**:
- 전체 refresh 요청의 단일 진입점
- throttle 관리 (1분 minimum interval)
- refresh 소스 추적 (foreground / observer / pull-to-refresh / background delivery)
- SharedHealthDataService 캐시 무효화 조율
- 각 탭 VM에 reload signal 전달

**인터페이스 (안)**:

```swift
protocol AppRefreshCoordinating: Sendable {
    /// Triggers a full app refresh if enough time has elapsed since last refresh.
    /// Returns true if refresh was triggered, false if throttled.
    func requestRefresh(source: RefreshSource) async -> Bool

    /// Forces refresh regardless of throttle (pull-to-refresh).
    func forceRefresh() async

    /// Invalidates cache without triggering reload (background delivery).
    func invalidateCacheOnly() async
}
```

## Constraints

### 기술적 제약
- **HealthKit 권한**: Observer 등록은 해당 타입의 read 권한 필요. 미승인 타입은 silent skip
- **Background Delivery 제한**: 앱이 force-quit 되면 delivery 중단. 다음 실행 시 재등록 필요
- **HKObserverQuery는 변경 내용을 알려주지 않음**: "무엇이 바뀌었는지"가 아닌 "바뀜" 사실만 전달
- **배터리**: `.immediate` 빈도는 핵심 지표에만 제한. 과도한 background wake는 배터리 소모

### 아키텍처 제약
- **Correction #16**: Task 재실행 시 cancel-before-spawn 필수
- **Correction #17**: isLoading 리셋 전 Task.isCancelled 검사
- **Correction #78**: `.task(id:)` 패턴으로 onAppear + onChange 통합
- **Correction #132**: Void async 함수에서 `defer { isLoading = false }` 사용
- **SharedHealthDataService는 actor**: concurrent access safe, invalidateCache()는 async

### 레이어 경계
- `HealthKitObserverManager`는 Data 레이어 (HealthKit 직접 의존)
- `AppRefreshCoordinator`는 Domain 레이어 (protocol로 정의, Data에서 구현)
- `scenePhase` 감시는 Presentation 레이어 (ContentView)

## Edge Cases

| 시나리오 | 대응 |
|---------|------|
| HealthKit 권한 미승인 | Observer 등록 silent skip. pull-to-refresh + foreground refresh만 동작 |
| 앱 force-quit 후 재실행 | Background Delivery 재등록. `.task`에서 fresh load |
| 1분 이내 연속 포그라운드 전환 | throttle로 skip (마지막 refresh 시각 체크) |
| Observer callback 중 앱이 백그라운드로 전환 | completionHandler 반드시 호출. 캐시 무효화만 수행 |
| 여러 HK 타입이 동시에 변경 | 첫 callback에서 invalidateCache + reload, 이후 callback은 throttle |
| SharedHealthDataService in-flight 중 invalidate | 진행 중인 task 완료 대기 후 캐시 만료 마킹 |
| Background Delivery + 포그라운드 전환 동시 | 둘 다 invalidateCache → 첫 fetch만 실행 (in-flight dedup) |

## Scope

### MVP (Must-have)
1. **포그라운드 전환 시 자동 갱신** (scenePhase + 1분 throttle)
2. **HKObserverQuery 등록** (핵심 8개 타입)
3. **Background Delivery 등록** (HRV/RHR/Sleep: immediate, 나머지: hourly)
4. **AppRefreshCoordinator** (throttle + cache invalidation + reload signal)
5. **기존 pull-to-refresh 유지** (forceRefresh 경로)

### Nice-to-have (Future)
- `HKAnchoredObjectQuery`로 delta sync (변경된 샘플만 추적)
- Watch→iPhone 실시간 운동 완료 알림으로 즉시 Exercise 탭 갱신
- 탭별 세밀한 Observer 매핑 (HRV 변경 시 Today+Train만 reload, Wellness는 skip)
- Notification으로 사용자에게 데이터 갱신 알림 (e.g. "새로운 수면 데이터가 동기화되었습니다")
- Widgets 데이터 동기화 (WidgetKit timeline reload)

## Open Questions

1. **Exercise 탭이 ContentView에서 보이지 않음** — ActivityView 내부에 포함? 아니면 별도 탭?
   - → Activity(Train) 내부에 Exercise가 포함된 구조로 보임. 확인 필요
2. **Background Delivery UIBackgroundModes 설정 현황** — xcodegen `project.yml`에 이미 설정되어 있는지 확인 필요
3. **HealthKit 권한 요청 시점** — 현재 권한 요청 flow가 Observer 등록 전에 완료되는지 확인 필요

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│  Presentation Layer                                      │
│                                                          │
│  ContentView ──── @Environment(\.scenePhase) ────┐      │
│      │                                            │      │
│      ├── DashboardView  (.task(id: refreshSignal))│      │
│      ├── ActivityView   (.task(id: refreshSignal))│      │
│      └── WellnessView   (.task(id: refreshSignal))│      │
│                                                   │      │
│  scenePhase: .background → .active ──────────────┘      │
│                    │                                     │
│                    ▼ (1분 throttle)                      │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│  Domain Layer                                            │
│                                                          │
│  AppRefreshCoordinator (protocol)                        │
│      │                                                   │
│      ├── requestRefresh(source:) → Bool                  │
│      ├── forceRefresh()                                  │
│      └── invalidateCacheOnly()                           │
│                                                          │
│  SharedHealthDataService (protocol)                      │
│      ├── fetchSnapshot() → SharedHealthSnapshot          │
│      └── invalidateCache()                               │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│  Data Layer                                              │
│                                                          │
│  AppRefreshCoordinatorImpl (actor)                        │
│      ├── lastRefreshDate: Date?                          │
│      ├── throttleInterval: TimeInterval = 60             │
│      └── SharedHealthDataService.invalidateCache()       │
│                                                          │
│  HealthKitObserverManager (new)                          │
│      ├── HKObserverQuery × 8 types                      │
│      ├── HKHealthStore.enableBackgroundDelivery()        │
│      ├── observer callback → coordinator.requestRefresh  │
│      └── throttle per type (1 min)                       │
│                                                          │
│  SharedHealthDataServiceImpl (existing actor)            │
│      ├── 5분 TTL 캐시 (유지)                             │
│      └── in-flight dedup (유지)                          │
└─────────────────────────────────────────────────────────┘
```

## Affected Files (예상)

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/App/ContentView.swift` | scenePhase 감시, refreshSignal 전달 |
| `DUNE/App/DUNEApp.swift` | AppRefreshCoordinator 생성, Background Delivery 등록 |
| `DUNE/Domain/Services/AppRefreshCoordinator.swift` | **신규** — refresh 조율 protocol |
| `DUNE/Data/Services/AppRefreshCoordinatorImpl.swift` | **신규** — throttle + cache 관리 |
| `DUNE/Data/HealthKit/HealthKitObserverManager.swift` | **신규** — HKObserverQuery + Background Delivery |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | refreshSignal 연동 |
| `DUNE/Presentation/Activity/ActivityView.swift` | refreshSignal 연동 |
| `DUNE/Presentation/Wellness/WellnessView.swift` | refreshSignal 연동 |
| `Dailve/project.yml` | UIBackgroundModes 확인/추가 |

## Related Corrections

- **#16**: Cancel-before-spawn 필수
- **#17**: isLoading 리셋 전 Task.isCancelled 검사
- **#78**: `.task(id:)` 통합 패턴
- **#111**: ViewModel computed property UseCase 캐싱
- **#132**: Void async 함수는 `defer` 사용 필수

## Next Steps

- [ ] `/plan healthkit-sync-overhaul` 으로 구현 계획 생성
