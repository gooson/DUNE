---
tags: [swiftui, cloudkit, mainactor, remote-change, notification, app-lifecycle]
category: architecture
date: 2026-03-12
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNE/App/PersistentStoreRemoteChangeRefresh.swift
  - DUNETests/PersistentStoreRemoteChangeRefreshTests.swift
  - DUNETests/AppNotificationCenterDelegateTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-12-mac-cloudkit-remote-change-auto-refresh.md
  - docs/solutions/architecture/2026-03-12-mac-swiftdata-migration-refresh-stability.md
---

# Solution: CloudKit Remote Change MainActor Ingress

## Problem

CloudKit remote change 알림 이후에도 `Publishing changes from background threads is not allowed`
경고가 남아 있었다.

### Symptoms

- `AppRefreshCoordinator`가 `cloudKitRemoteChange`를 throttle 하거나 refresh를 트리거한 직후 background-thread publish 경고가 반복됨
- `ContentView` 쪽 `refreshSignal` 보호 코드가 이미 있어도 경고가 완전히 사라지지 않음

### Root Cause

`ContentView`의 refresh stream 소비는 main actor로 복귀했지만, 더 앞단인 `DUNEApp`의
`.NSPersistentStoreRemoteChange` handler는 일반 `Task`에서 `@State appRuntime`의
`refreshCoordinator`를 읽고 있었다.

`NSPersistentStoreRemoteChange`는 background queue에서 전달될 수 있으므로,
SwiftUI state ingress 자체를 main actor에 고정하지 않으면 downstream에서 warning이 남을 수 있다.

## Solution

remote change forwarding을 별도 `@MainActor` helper로 추출하고,
`DUNEApp` handler는 `Task { @MainActor in ... }` 내부에서만 coordinator를 읽도록 바꿨다.
동시에 helper에 대한 regression test를 추가했고, 기존 notification delegate test는
`MainActor.assumeIsolated`로 strict concurrency에 맞게 정리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/DUNEApp.swift` | remote change handler를 main actor helper 경유로 변경 | `@State appRuntime` 접근을 background task 밖으로 격리 |
| `DUNE/App/PersistentStoreRemoteChangeRefresh.swift` | `@MainActor` forwarding helper 추가 | ingress contract를 작고 테스트 가능한 단위로 분리 |
| `DUNETests/PersistentStoreRemoteChangeRefreshTests.swift` | `cloudKitRemoteChange` forwarding 회귀 테스트 추가 | source 전달과 throttle 무시 동작 고정 |
| `DUNETests/AppNotificationCenterDelegateTests.swift` | `MainActor.assumeIsolated` 적용 | 기존 test closure를 Swift 6 strict concurrency와 정합시킴 |

### Key Code

```swift
.onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
    Task { @MainActor in
        await PersistentStoreRemoteChangeRefresh.request(using: appRuntime.refreshCoordinator)
    }
}
```

```swift
enum PersistentStoreRemoteChangeRefresh {
    @MainActor
    static func request(using refreshCoordinator: AppRefreshCoordinating) async {
        _ = await refreshCoordinator.requestRefresh(source: .cloudKitRemoteChange)
    }
}
```

## Prevention

### Checklist Addition

- [ ] NotificationCenter 기반 app lifecycle ingress가 `@State`, `@Observable`, `ObservableObject`를 읽거나 쓰면 main actor 경계를 먼저 고정한다.
- [ ] downstream `MainActor.run` 보정이 있어도, upstream notification/task ingress가 background executor인지 함께 확인한다.
- [ ] `@Sendable` test closure에서 main-actor state를 만질 때는 `MainActor.assumeIsolated` 또는 actor mock을 사용한다.

### Rule Addition (if applicable)

새 규칙 파일까지는 필요 없고, SwiftUI app lifecycle에서 notification ingress를 볼 때 위 체크리스트를 review 항목으로 적용한다.

## Lessons Learned

- background publish 경고는 마지막 publish 지점만이 아니라 notification ingress 경계가 잘못돼도 남을 수 있다.
- 이런 종류의 수정은 작은 helper로 actor boundary를 드러내면 테스트와 코드 리뷰가 훨씬 쉬워진다.
