---
tags: [cloudkit, swiftdata, coredata, mac, background, dead10cc]
date: 2026-10-07
category: solution
status: implemented
---

# CloudKit 설정 중 백그라운드 SQLite 잠금 보호

## Problem

DUNE 0.8.0 (1)의 iPad 앱을 Mac에서 실행한 기록에 `RUNNINGBOARD 0xdead10cc` 종료가 나타났다. 메인 스레드는 이벤트를 기다리고 있었고, 다른 스레드는 `PFCloudKitMetadataModelMigrator`가 CloudKit 메타데이터를 SQLite에서 읽고 있었다. Apple은 이 종료 코드를 앱이 일시 중단될 때 파일 또는 SQLite 잠금을 잡고 있던 경우로 설명한다.

현재 앱은 CloudKit을 켠 SwiftData `ModelContainer`를 만들지만, Core Data의 비동기 CloudKit 설정 작업이 끝나기 전에 앱이 백그라운드로 넘어가는 경우를 보호하지 않았다. 보고서와 현재 소스의 앱 버전은 모두 0.8.0 (1)이다. 제공된 보고서만으로 재현 빈도나 데이터 손상은 판단할 수 없다.

## Solution

앱 런타임의 `ModelContainer`를 만들기 전에 `NSPersistentCloudKitContainer.eventChangedNotification` 관찰을 시작한다. `.setup` 이벤트가 시작되면 UIKit 백그라운드 작업을 등록하고, 같은 이벤트가 끝나면 해제한다. 설정 이벤트가 겹치면 하나의 작업을 공유하고, 시스템 만료 핸들러에서도 작업을 해제한다. CloudKit 설정 외의 import/export 이벤트에는 적용하지 않는다.

이 조치는 설정 중 일시 중단될 확률을 낮춘다. Core Data 내부 작업을 중단하거나 완료 시점을 제어할 수 없으므로 시스템이 허용한 백그라운드 시간이 먼저 끝나면 동일 종료가 완전히 사라진다고 보장할 수는 없다.

## Verification

- iOS 앱 빌드 성공 (`scripts/build-ios.sh`).
- `CloudKitSetupBackgroundTaskTests`의 완료, 중첩, 만료 수명 테스트 통과.
- 실제 Mac에서 CloudKit 메타데이터 마이그레이션과 앱 일시 중단이 겹치는 상황은 자동 재현하지 못했다. 출시 후 동일 종료 코드의 재발 여부를 확인해야 한다.

## Prevention

- CloudKit 설정/저장처럼 잠금을 잡을 수 있는 비동기 작업은 시작 전에 백그라운드 실행 시간을 확보하고 종료 또는 만료 때 반드시 해제한다.
- `0xdead10cc` 보고서는 크래시 스레드만 보지 말고 SQLite 잠금을 사용 중인 다른 스레드를 함께 확인한다.
