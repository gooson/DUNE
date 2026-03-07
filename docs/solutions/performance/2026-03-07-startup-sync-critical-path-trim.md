---
tags: [startup, launch, sharedhealthsnapshot, watchconnectivity, swiftdata, critical-path, async-let]
category: performance
date: 2026-03-07
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNE/Data/Services/MirroringSharedHealthDataService.swift
  - DUNE/Data/WatchConnectivity/WatchSessionManager.swift
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
  - DUNE/Presentation/Activity/ActivityViewModel.swift
  - DUNE/Presentation/Wellness/WellnessViewModel.swift
  - DUNETests/MirroringSharedHealthDataServiceTests.swift
  - DUNETests/DashboardViewModelTests.swift
  - DUNETests/ActivityViewModelTests.swift
  - DUNETests/WellnessViewModelTests.swift
related_solutions:
  - docs/solutions/performance/2026-02-15-healthkit-query-parallelization.md
  - docs/solutions/performance/2026-03-02-ipad-activity-sync-ui-lock-fix.md
  - docs/solutions/architecture/2026-03-03-macos-healthkit-cloud-mirror-foundation.md
  - docs/solutions/general/2026-03-03-watch-template-sync-watchconnectivity-fallback.md
---

# Solution: 앱 시작 sync 크리티컬 패스 축소

## Problem

앱 시작 직후 데이터 sync가 첫 인터랙션 경로에 과하게 묶여 있었다. 명시적인 메인 스레드 블로킹 코드는 없었지만, cold launch에서 불필요한 I/O와 후속 작업이 사용자에게 보이는 첫 화면 이전에 직렬화되고 있었다.

### Symptoms

- 스플래시 해제 직후 Watch 템플릿 sync가 메인 액터 경로에 붙어 있었다.
- Today, Activity, Wellness 초기 로드가 shared snapshot 완료를 기다린 뒤 독립 쿼리를 시작했다.
- `fetchSnapshot()`이 mirror persistence까지 끝나야 반환되어 skeleton 표시 시간이 길어질 수 있었다.

### Root Cause

- launch-time side effect(Watch sync, mirror persist)를 필수 blocking work처럼 배치했다.
- shared snapshot 의존성이 없는 쿼리들까지 같은 await 지점 뒤에 두어 cold-start 병렬성을 잃었다.
- Wellness는 `withTaskGroup` 구조 때문에 `async let`을 바로 재사용할 수 없어, 의도한 병렬화가 더 쉽게 빠질 수 있는 구조였다.

## Solution

launch 시 필요한 "데이터 읽기"와 "부수 효과 저장/전송"을 분리하고, snapshot 의존 여부에 따라 await 시점을 늦췄다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Services/MirroringSharedHealthDataService.swift` | mirror persistence를 `Task(priority: .utility)`로 분리 | snapshot 반환을 mirror I/O에 묶지 않기 위해 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | `ModelContainer` 기반 startup-safe sync overload 추가 | SwiftData fetch/mapping을 launch main actor 경로에서 제거하기 위해 |
| `DUNE/App/DUNEApp.swift` | 앱 시작 sync를 `mainContext` 대신 `modelContainer` 경로로 호출 | Watch 템플릿 payload 생성을 백그라운드로 이동하기 위해 |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | shared snapshot과 독립 쿼리를 동시에 시작하고, HRV/sleep 직전에만 await | Today 탭 cold-load 직렬화 제거 |
| `DUNE/Presentation/Activity/ActivityViewModel.swift` | 운동/걸음/워크아웃을 먼저 시작하고 training/sleep/readiness만 snapshot 뒤로 이동 | Activity 탭 startup 병렬성 회복 |
| `DUNE/Presentation/Wellness/WellnessViewModel.swift` | shared snapshot을 `Task`로 분리하고 body/vitals/heart-rate를 먼저 실행 | `withTaskGroup` 제약 아래서도 Wellness launch path 직렬화 제거 |
| `DUNETests/*` | startup ordering 및 non-blocking persistence 테스트 추가 | launch critical path 회귀 방지 |

### Key Code

```swift
func fetchSnapshot() async -> SharedHealthSnapshot {
    let snapshot = await baseService.fetchSnapshot()
    Task(priority: .utility) { [mirrorStore] in
        await mirrorStore.persist(snapshot: snapshot)
    }
    return snapshot
}
```

```swift
async let sharedSnapshotTask: SharedHealthSnapshot? = sharedHealthDataService?.fetchSnapshot()
async let exerciseTask = safeExerciseFetch(canQueryHealthKit: healthKitAvailable)
async let stepsTask = safeStepsFetch(canQueryHealthKit: healthKitAvailable)
async let weightTask = safeWeightFetch(canQueryHealthKit: healthKitAvailable)
let sharedSnapshot = await sharedSnapshotTask
async let hrvTask = safeHRVFetch(snapshot: sharedSnapshot, canQueryHealthKit: healthKitAvailable)
```

## Prevention

### Checklist Addition

- [ ] launch 시점 fetch 함수는 "값 반환"과 "부수 효과 persist/sync"를 같은 await 체인에 묶지 않는다.
- [ ] shared snapshot/cache 결과에 의존하지 않는 쿼리는 먼저 시작하고, 의존 쿼리 직전에만 snapshot을 await 한다.
- [ ] `@MainActor` 앱 시작 경로에서 SwiftData fetch + payload mapping 같은 대량 작업을 직접 수행하지 않는다.
- [ ] `withTaskGroup` 안에서 shared async 작업이 필요하면 `async let` capture 제약을 먼저 확인하고 `Task` handle 대안을 검토한다.
- [ ] startup performance fix는 "실제 fetch 시작 시점"을 검증하는 테스트로 회귀를 막는다.

### Rule Addition (if applicable)

현재는 신규 rule 파일 추가보다 performance solution과 테스트 패턴 축적으로 충분하다.

## Lessons Learned

launch 성능 문제는 "메인 스레드에 sync 코드가 있는가"만 보면 놓치기 쉽다. 비동기 코드라도 await 배치를 잘못 잡으면 cold-start critical path가 길어지므로, startup에서는 각 작업이 정말로 첫 화면 이전에 필요하다는 근거를 먼저 확인해야 한다.
