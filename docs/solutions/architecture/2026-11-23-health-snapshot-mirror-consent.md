---
tags: [swiftdata, cloudkit, healthkit, privacy, migration]
category: architecture
date: 2026-11-23
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNE/Data/Services/MirroringSharedHealthDataService.swift
  - DUNE/Data/Services/HealthSnapshotMirrorStore.swift
  - DUNETests/MirroringSharedHealthDataServiceTests.swift
related_solutions:
  - 2026-03-03-macos-healthkit-cloud-mirror-foundation.md
---

# iCloud 동기화가 꺼진 동안 건강 스냅샷 미러 쓰기 중단

## 기존 동작

iOS는 동기화가 꺼지면 SwiftData를 로컬 전용으로 열지만, HealthKit 새로고침은 여전히 조회 결과를 미러 저장소에 보냈다. OFF 동안 생긴 행은 나중에 동기화를 켰을 때 클라우드 저장소가 다시 열리면 내보내기 대상이 될 수 있다. 특정 행이 실제로 Mac에 도착했는지는 두 기기의 관측이 필요하다.

## 변경

HealthKit 조회 서비스는 매번 기기에 반영된 최신 동기화 설정을 읽는다. OFF에서 시작한 조회는 사용자에게 실시간 결과를 반환하고 미러 쓰기를 예약하지 않는다. ON에서 시작한 쓰기는 저장 작업을 시작할 때와 SwiftData에 저장하기 직전에 설정을 확인한다. 마지막 확인에서 OFF이면 이 작업의 삽입·수정·오래된 행 정리를 함께 되돌린다.

설정 화면에서 스위치를 바꿔도 앱의 서비스는 다음 전경 복귀까지 유지될 수 있다. 앱 시작 때 OFF 전용 서비스를 고정하는 구현은 같은 화면에서 다시 ON으로 바꾼 뒤에도 미러 쓰기를 재개하지 못한다. 조회할 때 선택을 읽으면 화면이나 내비게이션을 다시 만들지 않고 다음 조회부터 재개할 수 있다. CloudKit 컨테이너가 실제로 다시 열리는 시점은 기존 런타임의 전경·KVS 갱신을 따른다.

## 마이그레이션과 배포 판단

이 변경은 기존 행의 형식이나 저장소 URL을 바꾸지 않아 PR 1에서 데이터 변환을 실행할 필요가 없다. 이미 저장된 행과 원격 사본은 이후 단계에서 복원 경로를 검증한 뒤 다룬다. OFF 기간의 새 스냅샷이 없어도 기존 Mac 이력 기능을 보존할 수 있는지가 이 PR의 병합 조건이다. [단계별 검증 계획](../../plans/2026-11-23-icloud-health-data-rollout.md)

## 실물 iPad에서 관측한 값

2026-11-23, iPad Pro 13형(M4), iPadOS 27.2.1, Xcode 27.2. 기존 앱과 식별자가 다른 QA 앱에 합성 데이터만 넣었다. HealthKit, iCloud, App Group 권한을 제거하고 파일 기반 SwiftData 저장소를 사용했다. 기준과 후보에는 각각 `f1c48fcd8`과 `6bc2c9e03`의 미러 코드를 포함했다.

| 검사 | 기존 버전 | 수정 버전 |
|---|---|---|
| 합성 미러 1건에서 시작해 OFF → ON → OFF마다 서로 다른 스냅샷 조회 | 총 2 → 3 → 4건 | 총 1 → 2 → 2건 |
| 같은 저장소를 새 컨테이너로 다시 열기 | 4건 | 기존 행과 ON 갱신 행 2건 |
| 구버전 위에 덮어 설치 | 합성 행 1건의 UUID를 별도 파일에 보관 | OFF에서 조회하고 저장소를 다시 열어 UUID 16바이트, 기존 날짜와 payload 보존 확인 |
| 같은 기본 시드로 앱을 종료·실행하며 두 차례 화면 확인 | Today 진입 → Wellness 수면 7시간 10분 → 체성분 이력 진입 | 두 차례 모두 같은 경로와 수면값 확인 |

두 버전에서 세 번의 조회가 각각 요청한 합성 스냅샷을 반환했다. 저장 직전 동의 철회와 재시도를 포함해 후보의 단위 테스트 16개가 실기기에서 통과했다. 실제 iCloud에 이미 대기 중인 내보내기와 저장 호출이 시작된 뒤의 설정 변경은 이 검사로 판정할 수 없다.

화면 비교에는 기본 미러 시드의 최신 수면 표본 430분을 사용했다. 체성분은 이력 화면 진입을 검사했다. 실제 건강 권한을 통한 조회, 홈 화면 위젯 표시, 외부 KVS 알림, iCloud 서버의 레코드 변화, Mac 도착 여부는 이 실측 범위 밖이다.
