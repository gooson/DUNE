---
tags: [macos, cloud-sync, cloudkit, swiftui, runtime-refresh, ubiquitous-kvs]
category: architecture
date: 2026-03-08
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNE/Data/Persistence/HealthSnapshotMirrorContainerFactory.swift
  - DUNETests/HealthSnapshotMirrorContainerFactoryTests.swift
related_solutions:
  - docs/solutions/general/2026-03-08-batch-fixes-summary.md
  - docs/solutions/general/2026-03-08-review-followup-state-and-migration-fixes.md
  - docs/solutions/architecture/2026-03-07-visionos-mirror-sync-gating-and-spatial-fallback.md
---

# Solution: Mac Cloud Sync Runtime Refresh

## Problem

맥(HealthKit unavailable consumer)에서 cloud sync opt-in 상태를 앱 시작 시 한 번만 해석하고 있었다.
이 상태에서 iPhone이 나중에 `isCloudSyncEnabled`를 iCloud KVS로 전파하면, Mac 앱은 현재 세션 동안
기존 local-only runtime을 유지해 mirrored data를 읽지 못할 수 있었다.

### Symptoms

- Mac 앱이 빈 상태를 유지하고 iPhone에서 켠 cloud sync 상태를 같은 세션에 반영하지 못함
- `CloudMirroredSharedHealthDataService` fallback이 있어도, 그 service를 감싼 app runtime 자체가 stale 상태로 고정됨
- foreground 복귀나 KVS 외부 변경이 와도 container/service wiring은 그대로 남음

### Root Cause

`DUNEApp.init()`이 `CloudSyncPreferenceStore.resolvedValue()`를 1회 평가한 뒤 `ModelContainer`,
`SharedHealthDataService`, `AppRefreshCoordinator`, `HealthKitObserverManager`를 고정 생성했다.
이후 `NSUbiquitousKeyValueStore.didChangeExternallyNotification`이나 foreground 재진입 때도
resolved cloud sync 상태를 다시 해석하거나 runtime을 재구성하지 않았다.

## Solution

App-level dependency bundle을 `AppRuntime`으로 추출하고, iCloud KVS 외부 변경 및 app active 전환 시
resolved cloud sync preference를 다시 평가하도록 바꿨다. 값이 바뀐 경우에만 runtime을 재생성하고,
`ContentView` subtree identity를 교체해 새 container/service를 실제 화면이 다시 쓰게 했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/DUNEApp.swift` | `AppRuntime` 추출 + KVS external-change / scene active refresh 처리 추가 | stale cloud sync runtime을 현재 세션에서 교체하기 위해 |
| `DUNE/App/DUNEApp.swift` | `ContentView`에 runtime revision 기반 `.id(...)` 적용 | cached `@State` view model이 새 service를 다시 주입받도록 하기 위해 |
| `DUNE/Data/Persistence/HealthSnapshotMirrorContainerFactory.swift` | `RuntimeRefreshAction` helper 추가 | resolved preference 변경 시 rebuild/no-op 판단을 pure helper로 고정하기 위해 |
| `DUNETests/HealthSnapshotMirrorContainerFactoryTests.swift` | runtime refresh action 테스트 추가 | cloud sync preference refresh policy 회귀 방지 |

### Key Code

```swift
@MainActor
private func refreshAppRuntimeIfNeeded() async {
    let resolvedValue = CloudSyncPreferenceStore.resolvedValue()
    let action = CloudSyncPreferenceStore.runtimeRefreshAction(
        currentValue: appRuntime.cloudSyncEnabled,
        resolvedValue: resolvedValue
    )

    guard case let .rebuild(resolvedValue: nextValue) = action else { return }

    if let previousObserverManager = appRuntime.observerManager {
        await previousObserverManager.stopObserving()
    }

    appRuntime = Self.makeAppRuntime(
        notificationService: notificationService,
        cloudSyncEnabled: nextValue
    )
}
```

## Prevention

secondary CloudKit consumer(Mac/visionOS 등)는 "reader라서 안전하다"는 이유로 startup 시점 상태를 고정하면 안 된다.
opt-in을 iCloud KVS로 해석하는 앱이라면, 최소한 외부 변경과 foreground 복귀 시 resolved state를 다시 평가하고,
state가 바뀌면 runtime wiring까지 갱신해야 한다.

### Checklist Addition

- [ ] App init에서 CloudKit/Cloud Sync를 1회만 결정하는 구조인지 확인했는가?
- [ ] `NSUbiquitousKeyValueStore.didChangeExternallyNotification` 수신 시 resolved opt-in을 다시 평가하는가?
- [ ] 새 cloud sync runtime이 실제 화면에 재주입되도록 subtree identity 또는 동등한 재구성 경로가 있는가?
- [ ] observer/service 교체 시 이전 runtime의 background observer를 정리하는가?

### Rule Addition (if applicable)

새 rule 파일 추가는 생략한다. 기존 cloud sync / secondary consumer 문서들로 충분히 커버된다.

## Lessons Learned

- Cloud sync 버그는 저장소 레이어만 봐서는 놓치기 쉽고, App init의 dependency lifetime까지 같이 봐야 한다.
- `UserDefaults`/iCloud KVS 값이 맞아도, 그 값을 읽어 만든 runtime이 고정되어 있으면 사용자 입장에서는 여전히 "sync가 안 된다".
- secondary consumer에서 opt-in parity를 맞추려면 "policy sync"와 "runtime refresh"를 세트로 다뤄야 한다.
