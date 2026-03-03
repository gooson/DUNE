---
tags: [macos, healthkit, swiftdata, cloudkit, sharedhealthsnapshot, mirror, architecture]
category: architecture
date: 2026-03-03
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNE/Data/Persistence/Models/HealthSnapshotMirrorRecord.swift
  - DUNE/Data/Persistence/Migration/AppSchemaVersions.swift
  - DUNE/Data/Services/HealthSnapshotMirrorMapper.swift
  - DUNE/Data/Services/HealthSnapshotMirrorStore.swift
  - DUNE/Data/Services/MirroringSharedHealthDataService.swift
  - DUNEWatch/DUNEWatchApp.swift
related_solutions:
  - docs/solutions/healthkit/background-notification-system.md
  - docs/solutions/general/2026-02-28-cloudkit-remote-notification-background-mode.md
---

# Solution: macOS 대응을 위한 Health Snapshot Cloud Mirror Foundation

## Problem

macOS는 HealthKit 직접 접근이 불가하지만, 현재 앱 구조는 `SharedHealthDataServiceImpl`이 HealthKit 조회 결과를 메모리 캐시에만 유지한다.  
이 상태에서는 iOS/watchOS에서 계산한 건강 스냅샷을 macOS가 재사용할 수 없다.

### Symptoms

- HealthKit 파생 데이터의 CloudKit 미러 모델이 없어 디바이스 간 재사용 불가
- `SharedHealthSnapshot`이 fetch 시점에만 존재하고 영속화되지 않음
- macOS 조회 전용 앱 확장을 위한 데이터 계층 선행조건 부재

### Root Cause

1. `SharedHealthSnapshot` 전용 persistence 모델이 정의되지 않았다.
2. fetch 경로에 "persist side-effect"가 연결되어 있지 않았다.
3. 스키마 버전(`VersionedSchema`)에 mirror 모델이 반영되지 않았다.

## Solution

`SharedHealthDataService`를 데코레이터로 감싸 fetch 결과를 SwiftData(CloudKit) mirror store에 저장하는 기반을 추가했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Persistence/Models/HealthSnapshotMirrorRecord.swift` | 신규 @Model 추가 | Health snapshot payload 영속화 |
| `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift` | `AppSchemaV8` + `V7->V8` migration 추가 | CloudKit 스키마 정합성 유지 |
| `DUNE/Domain/Services/HealthSnapshotMirroring.swift` | mirror persistence protocol 추가 | 서비스 결합도 감소, 테스트 용이성 확보 |
| `DUNE/Data/Services/HealthSnapshotMirrorMapper.swift` | snapshot -> payload 변환/JSON encode-decode 추가 | 플랫폼 독립 payload 생성 |
| `DUNE/Data/Services/HealthSnapshotMirrorStore.swift` | upsert + retention store 구현 | CloudKit 미러 저장/정리 |
| `DUNE/Data/Services/MirroringSharedHealthDataService.swift` | Shared service decorator 추가 | 기존 호출자 변경 없이 자동 미러링 |
| `DUNE/App/DUNEApp.swift` | mirrored shared service 주입 | 앱 전체 fetch 경로에 persist 연결 |
| `DUNEWatch/DUNEWatchApp.swift` | model container 모델 목록에 mirror 모델 추가 | shared schema 호환성 보강 |
| `DUNETests/HealthSnapshotMirrorMapperTests.swift` | mapper 테스트 추가 | 매핑/정렬/직렬화 검증 |
| `DUNETests/MirroringSharedHealthDataServiceTests.swift` | decorator 테스트 추가 | persist delegation 검증 |

### Key Code

```swift
actor MirroringSharedHealthDataService: SharedHealthDataService {
    private let baseService: SharedHealthDataService
    private let mirrorStore: HealthSnapshotMirroring

    func fetchSnapshot() async -> SharedHealthSnapshot {
        let snapshot = await baseService.fetchSnapshot()
        await mirrorStore.persist(snapshot: snapshot)
        return snapshot
    }
}
```

```swift
enum AppSchemaV8: VersionedSchema {
    static let versionIdentifier = Schema.Version(8, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ExerciseRecord.self, ..., HealthSnapshotMirrorRecord.self]
    }
}
```

## Prevention

### Checklist Addition

- [ ] `SharedHealthSnapshot` 구조 변경 시 mirror mapper payload도 함께 갱신
- [ ] 새 @Model 추가 시 `ModelContainer(for:)` + 최신 `VersionedSchema` 동시 반영
- [ ] retention 로직은 `fetchLimit`으로 부분 조회하지 않고 전체 카운트 기준으로 정리
- [ ] fetch 경로에 persistence side-effect 추가 시 기존 반환값/실패 전파 정책 유지

### Rule Addition (if applicable)

신규 룰 파일 추가는 생략. 기존 `swiftdata-cloudkit.md`, `documentation-standards.md` 범위 내에서 해결 가능.

## Lessons Learned

- macOS 확장은 UI보다 데이터 계층(미러 모델/동기화 파이프라인) 선행이 핵심이다.
- 기존 서비스 계약을 바꾸지 않고 데코레이터를 도입하면 회귀 리스크를 낮출 수 있다.
- CloudKit 스키마 변경은 모델 추가 자체보다 migration 경로 누락이 더 큰 장애 요인이므로, schema와 container를 한 번에 갱신해야 안전하다.
