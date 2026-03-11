---
tags: [mac, cloudkit, sync, remote-change, refresh, swiftdata]
date: 2026-03-12
category: solution
status: implemented
---

# Mac CloudKit Remote Change Auto-Refresh

## Problem

맥앱에서 아이클라우드 데이터 동기화가 자동으로 되지 않았다.
iPhone에서 HealthKit 데이터를 CloudKit으로 미러링해도, Mac의 `CloudMirroredSharedHealthDataService`가
원격 변경을 감지하지 못해 앱 재시작 없이는 데이터가 갱신되지 않았다.

### Root Cause

`NSPersistentStoreRemoteChange` notification을 관찰하지 않아
CloudKit 동기화 완료 이벤트를 수신할 수 없었다.

## Solution

`DUNEApp.swift`에 `.onReceive(.NSPersistentStoreRemoteChange)` 추가.
Notification 수신 시 `requestRefresh(source: .cloudKitRemoteChange)` 호출하여
기존 refresh coordinator의 캐시 무효화 + UI 갱신 파이프라인을 재사용.

### 변경 파일

| 파일 | 변경 |
|------|------|
| `DUNE/Domain/Services/AppRefreshCoordinator.swift` | `RefreshSource.cloudKitRemoteChange` case 추가 |
| `DUNE/App/DUNEApp.swift` | `.onReceive(.NSPersistentStoreRemoteChange)` handler 추가 |

### 핵심 설계 결정

- **기존 throttle 재사용**: `AppRefreshCoordinatorImpl`의 60초 throttle이 빈번한 remote change notification을 자연 제한
- **iOS 영향 없음**: iOS에서도 notification이 발행되나 HealthKit observer가 이미 처리하고 throttle이 이중 갱신 차단
- **ContentView 변경 불필요**: 이미 `refreshNeededStream`을 구독하므로 새 source도 자동 처리

## Prevention

Mac/non-HealthKit 경로에 새 데이터 소스를 추가할 때는 반드시 원격 변경 감지 메커니즘을 함께 구현한다.
SwiftData + CloudKit 사용 시 `NSPersistentStoreRemoteChange` 관찰이 표준 패턴.
