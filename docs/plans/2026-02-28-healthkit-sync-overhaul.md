---
tags: [healthkit, sync, background-delivery, observer-query, foreground-refresh]
date: 2026-02-28
category: plan
status: draft
---

# Plan: HealthKit Sync Logic Overhaul

## Summary

HealthKit 데이터 싱크를 3가지 경로(포그라운드 복귀, HKObserverQuery, Background Delivery)로 자동화하고, 기존 pull-to-refresh와 통합합니다.

## Architecture

```
ContentView (scenePhase)
     │
     ▼
AppRefreshCoordinator (1분 throttle)
     │
     ├── invalidateCache() → SharedHealthDataServiceImpl
     │
     └── refreshSignal += 1 → 각 탭 View의 .task(id:) 트리거
                                    │
                                    ▼
                              VM.loadData() → SharedHealthDataService.fetchSnapshot()
                                                     │ (캐시 miss → fresh HealthKit query)

HealthKitObserverManager (HKObserverQuery × 8)
     │
     ├── observer callback → AppRefreshCoordinator.requestRefresh()
     │
     └── enableBackgroundDelivery() → 백그라운드 wake → invalidateCacheOnly()
```

## Implementation Steps

### Step 1: AppRefreshCoordinator Protocol (Domain)

**파일**: `DUNE/Domain/Services/AppRefreshCoordinator.swift` (신규)

```swift
import Foundation

enum RefreshSource: String, Sendable {
    case foreground
    case healthKitObserver
    case backgroundDelivery
    case pullToRefresh
}

protocol AppRefreshCoordinating: Sendable {
    func requestRefresh(source: RefreshSource) async -> Bool
    func forceRefresh() async
    func invalidateCacheOnly() async
}
```

### Step 2: AppRefreshCoordinatorImpl (Data)

**파일**: `DUNE/Data/Services/AppRefreshCoordinatorImpl.swift` (신규)

- actor로 구현 (thread-safe)
- `lastRefreshDate: Date?` — 마지막 실제 refresh 시각
- `throttleInterval: TimeInterval = 60` — 1분
- `requestRefresh()` → throttle 체크 → `sharedHealthDataService.invalidateCache()` → onRefreshNeeded callback
- `forceRefresh()` → throttle 무시 → 즉시 invalidate + callback
- `invalidateCacheOnly()` → 캐시만 무효화, reload signal 없음 (Background Delivery용)
- `onRefreshNeeded: @Sendable () async -> Void` callback으로 UI reload signal 전달

### Step 3: HealthKitObserverManager (Data)

**파일**: `DUNE/Data/HealthKit/HealthKitObserverManager.swift` (신규)

**Observer 등록 대상 (8 타입)**:

| HK Type | Background Delivery Frequency |
|---------|-------------------------------|
| `.heartRateVariabilitySDNN` | `.immediate` |
| `.restingHeartRate` | `.immediate` |
| `HKCategoryType(.sleepAnalysis)` | `.immediate` |
| `.stepCount` | `.hourly` |
| `.bodyMass` | `.hourly` |
| `.bodyFatPercentage` | `.hourly` |
| `.bodyMassIndex` | `.hourly` |
| `HKObjectType.workoutType()` | `.hourly` |

**구현 요소**:
- `HKHealthStore`의 `execute(HKObserverQuery)` 호출
- 각 observer callback에서 `coordinator.requestRefresh(source: .healthKitObserver)`
- `enableBackgroundDelivery(for:frequency:)` — 각 타입별 등록
- 타입별 throttle: `lastNotificationDate[type]` 딕셔너리로 1분 간격 제한
- observer query 참조 보관 → `stopObserving()` 시 cleanup
- HealthKit 권한 미승인 타입은 silent skip (에러 로그만)

### Step 4: ContentView — scenePhase 감시 + refreshSignal

**파일**: `DUNE/App/ContentView.swift` (수정)

변경 내용:
- `@Environment(\.scenePhase) private var scenePhase` 추가
- `@State private var refreshSignal = 0` 추가
- `let refreshCoordinator: AppRefreshCoordinating?` 파라미터 추가
- `.onChange(of: scenePhase)` — `.background → .active` 전환 시 `coordinator.requestRefresh(source: .foreground)` 호출
- `refreshSignal`을 각 탭 View에 전달

```swift
.onChange(of: scenePhase) { oldPhase, newPhase in
    if oldPhase == .background, newPhase == .active {
        Task {
            if let refreshed = await refreshCoordinator?.requestRefresh(source: .foreground),
               refreshed {
                refreshSignal += 1
            }
        }
    }
}
```

### Step 5: DUNEApp — 의존성 조립

**파일**: `DUNE/App/DUNEApp.swift` (수정)

변경 내용:
- `AppRefreshCoordinatorImpl` 생성 (sharedHealthDataService 주입)
- `HealthKitObserverManager` 생성 (coordinator 주입)
- refreshSignal callback 연결
- `ContentView`에 `refreshCoordinator` 전달
- 앱 시작 시 observer 등록 (`startObserving()`)

### Step 6: 각 탭 View — refreshSignal 연동

**DashboardView.swift** (수정):
- `let refreshSignal: Int` 파라미터 추가 (기존 `scrollToTopSignal`과 동일 패턴)
- 기존 `.task { await viewModel.loadData() }` → `.task(id: refreshSignal) { await viewModel.loadData() }`

**ActivityView.swift** (수정):
- `let refreshSignal: Int` 파라미터 추가
- 기존 `.task(id: recentRecords.count)` → `.task(id: "\(recentRecords.count)-\(refreshSignal)")`
  - Note: Correction #87 — content-aware key 사용

**WellnessView.swift** (수정):
- `let refreshSignal: Int` 파라미터 추가
- 기존 `.task { viewModel.loadData() }` → `.task(id: refreshSignal) { viewModel.loadData() }`

### Step 7: project.yml — UIBackgroundModes 추가

**파일**: `DUNE/project.yml` (수정)

```yaml
settings:
  base:
    INFOPLIST_KEY_UIBackgroundModes: "processing"
```

또는 Info.plist key로:
```yaml
info:
  properties:
    UIBackgroundModes:
      - processing
```

### Step 8: SharedHealthDataService — invalidate 시 in-flight 대응

**파일**: `DUNE/Data/Services/SharedHealthDataServiceImpl.swift` (수정)

현재 `invalidateCache()`가 `inFlightTask = nil`로 진행 중 task를 버림. 이는 이미 await 중인 caller에게 영향 없음 (기존 task.value는 완료됨). 하지만 명확성을 위해:
- `invalidateCache()` 호출 시 `cachedSnapshot`, `cacheExpiresAt`만 nil. `inFlightTask`는 완료 후 자동 nil.
- 변경 불필요 — 현재 구현이 안전함 확인.

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `DUNE/Domain/Services/AppRefreshCoordinator.swift` | **신규** | Protocol + RefreshSource enum |
| `DUNE/Data/Services/AppRefreshCoordinatorImpl.swift` | **신규** | Actor 구현 (throttle + invalidation) |
| `DUNE/Data/HealthKit/HealthKitObserverManager.swift` | **신규** | HKObserverQuery + Background Delivery |
| `DUNE/App/ContentView.swift` | 수정 | scenePhase + refreshSignal |
| `DUNE/App/DUNEApp.swift` | 수정 | 의존성 조립 + observer 시작 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | 수정 | refreshSignal 연동 |
| `DUNE/Presentation/Activity/ActivityView.swift` | 수정 | refreshSignal 연동 |
| `DUNE/Presentation/Wellness/WellnessView.swift` | 수정 | refreshSignal 연동 |
| `DUNE/project.yml` | 수정 | UIBackgroundModes 추가 |
| `DUNETests/AppRefreshCoordinatorTests.swift` | **신규** | Throttle 로직 테스트 |
| `DUNETests/HealthKitObserverManagerTests.swift` | **신규** | Observer 등록/callback 테스트 |

## Testing Strategy

### Unit Tests (필수)

**AppRefreshCoordinatorTests**:
- `test_requestRefresh_firstCall_returnsTrue`
- `test_requestRefresh_withinThrottle_returnsFalse`
- `test_requestRefresh_afterThrottle_returnsTrue`
- `test_forceRefresh_ignoresThrottle`
- `test_invalidateCacheOnly_doesNotTriggerCallback`
- `test_differentSources_allThrottled`

**HealthKitObserverManagerTests**:
- `test_startObserving_registersQueries` (mock HKHealthStore)
- `test_observerCallback_triggersCoordinator`
- `test_throttle_preventsRapidCallbacks`
- `test_stopObserving_cleansUpQueries`

### Integration Test (수동)
- 앱 실행 → 백그라운드 → Apple Health에서 수동 데이터 추가 → 포그라운드 복귀 → 데이터 반영 확인

## Relevant Corrections

| # | 내용 | 적용 위치 |
|---|------|----------|
| #16 | Cancel-before-spawn | WellnessView.task(id:) |
| #17 | Task.isCancelled 검사 | 모든 VM loadData |
| #78 | .task(id:) 통합 | 각 View refresh 트리거 |
| #87 | content-aware Hasher key | ActivityView .task(id:) |
| #92 | TaskGroup catch 에러 식별 로그 | HealthKitObserverManager |
| #132 | Void async defer 사용 | ActivityVM loadData |

## Risks & Mitigations

| 리스크 | 대응 |
|--------|------|
| Background Delivery가 배터리 소모 | 핵심 3타입만 `.immediate`, 나머지 `.hourly` |
| Observer callback 폭주 | 타입별 1분 throttle + coordinator 전체 1분 throttle |
| scenePhase가 iPad multitasking에서 빈번 | 1분 throttle로 과도한 reload 방지 |
| HealthKit 권한 미승인 | silent skip + 로그. pull-to-refresh는 항상 동작 |
