---
tags: [mac, cloudkit, sync, remote-change, refresh]
date: 2026-03-12
category: plan
status: draft
---

# Mac CloudKit Remote Change Auto-Refresh

## Problem Statement

맥앱(`CloudMirroredSharedHealthDataService`)은 iPhone에서 HealthKit 데이터를 CloudKit으로 미러링해 읽는다.
그러나 CloudKit이 새 데이터를 전달해도 이를 감지하는 메커니즘이 없어, 앱을 재시작하거나
iPhone을 열어야만 데이터가 갱신된다.

### Root Cause

1. `NSPersistentStoreRemoteChange` 미관찰 — CloudKit 동기화 완료 이벤트를 수신하지 않음
2. Scene phase 전환이 Mac에서 불안정 — 창이 항상 active 상태
3. 주기적 갱신 타이머 없음 — 캐시 TTL(60s)만 존재하나 능동적 invalidation 없음

## Solution

`NSPersistentStoreRemoteChange` notification을 관찰하여 CloudKit 원격 변경 감지 시
캐시 무효화 + UI 새로고침을 트리거한다.

## Affected Files

| 파일 | 변경 |
|------|------|
| `DUNE/Domain/Services/AppRefreshCoordinator.swift` | `RefreshSource.cloudKitRemoteChange` case 추가 |
| `DUNE/App/DUNEApp.swift` | remote change observer 등록 + 핸들러 |

## Implementation Steps

### Step 1: RefreshSource에 cloudKitRemoteChange 추가

`DUNE/Domain/Services/AppRefreshCoordinator.swift`의 `RefreshSource` enum에 새 case 추가.

```swift
case cloudKitRemoteChange
```

### Step 2: DUNEApp에 remote change observer 등록

`DUNEApp.swift`에서 `!healthKitAvailable` (Mac 경로)일 때
`NSPersistentStoreRemoteChange` notification을 관찰하여
`refreshCoordinator.requestRefresh(source: .cloudKitRemoteChange)`를 호출한다.

관찰 위치: `body` 내 `.onReceive()` modifier 사용.
notification의 object는 `NSPersistentStoreCoordinator`이므로
`modelContainer.configurations`에서 coordinator를 얻어 필터링.

### Step 3: ModelContainer에 remote change notification 활성화

SwiftData `ModelContainer`가 `NSPersistentStoreRemoteChange`를 발행하려면
persistent store description의 `NSPersistentStoreRemoteChangeNotificationPostOptionKey`가
`true`여야 한다. SwiftData + CloudKit 사용 시 기본 활성화되지만 명시적 확인 필요.

## Design Decisions

- **throttle 재사용**: `AppRefreshCoordinatorImpl`의 기존 60초 throttle이 빈번한 remote change를 자연스럽게 제한
- **forceRefresh 미사용**: 일반 `requestRefresh`로 충분 — throttle이 중복 갱신 방지
- **iOS 영향 없음**: iOS에서도 notification이 발행되나 `requestRefresh`의 throttle이 불필요한 이중 갱신 차단
- **ContentView 변경 불필요**: 이미 `refreshNeededStream`을 구독하므로 새 source도 자동 처리

## Risks

- `NSPersistentStoreRemoteChange`가 SwiftData ModelContainer에서 기본 활성화 여부 확인 필요
- Mac에서 앱이 background로 가지 않아 notification이 항상 처리됨 — throttle로 충분히 방어
