---
tags: [deadlock, swiftui, userdefaults, notification-inbox, main-thread]
date: 2026-09-19
category: general
status: implemented
severity: critical
related_files: [DUNE/Data/Persistence/NotificationInboxStore.swift, DUNETests/NotificationInboxStoreTests.swift]
---

# 알림함 저장과 SwiftUI 간 교착으로 Today 멈춤

## Problem

HealthKit 권한 요청 완료 후 Today, 탭, 설정이 모두 반응하지 않았다. 사용자 LLDB 스택에서 다음 순환 대기를 확인했다.

- main thread: SwiftUI notification 수신 → `reloadUnreadCount` → `NotificationInboxStore.unreadCount` → 저장 큐의 `sync` 대기.
- inbox store queue: `append` → `saveItemsLocked` → `UserDefaults.set` → 동기 notification → SwiftUI `_MovableLockLock` 대기.
- HealthKit anchor 및 baseline 저장 스레드도 동일 SwiftUI 잠금 뒤에서 대기.

따라서 HealthKit 조회 지연이나 XPC 메시지 자체가 아니라, UI가 조회하는 큐 안에서 UserDefaults의 외부 observer를 호출한 것이 직접 원인이었다.

## Solution

알림함을 초기화할 때 기존 UserDefaults 기록을 메모리로 읽는다. 조회 및 변경은 기존 serial queue로 보호하되 UserDefaults 쓰기는 별도의 serial persistence queue에 비동기로 전달한다. 변경 순서대로 쓰기를 enqueue하며, 저장 큐 완료를 기다리지 않는다. 전체 삭제도 같은 persistence queue를 사용해 이전 저장이 삭제 이후 되살아나는 것을 막는다.

메모리 반영은 즉시 완료되고 영구 저장은 비동기로 뒤따른다. 저장 큐가 완료되기 전에 프로세스가 강제 종료되면 마지막 변경은 저장되지 않을 수 있다. 실행 중 같은 저장소의 별도 instance나 외부 writer와 실시간 동기화하는 계약은 제공하지 않으며 앱은 shared instance를 사용한다.

## Validation

- `scripts/build-ios.sh --no-regen`: 성공.
- 실제 store/model/test 소스를 임시 Swift package에 복사해 Swift Testing 실행: 8개 테스트 통과.
- persistence queue를 suspend한 상태에서도 MainActor의 unread 조회 및 읽음 처리가 완료됨을 검증.
- persistence 재개 후 새 store instance에서 읽음 상태 복원 확인.
- append → deleteAll → append 순서의 최종 저장 결과 확인.
- 실제 iPhone 재실행 확인은 사용자에게 요청.

## Prevention

UI에서 동기 조회하는 lock/serial queue 내부에서는 UserDefaults 변경 등 외부 observer를 동기 호출할 수 있는 작업을 실행하지 않는다. persistence를 분리할 때 변경 순서와 삭제 순서도 함께 검증한다.

## Lessons Learned

UserDefaults 자체의 thread safety는 SwiftUI와 사용자 코드의 lock 순서까지 보장하지 않는다. 전체 thread backtrace가 순환 대기를 확정하는 데 필요했다.
