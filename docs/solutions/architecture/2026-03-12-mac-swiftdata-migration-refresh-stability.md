---
tags: [swiftdata, cloudkit, migration, mac, schema, mainactor, refresh]
category: architecture
date: 2026-03-12
severity: important
related_files:
  - DUNE/Data/Persistence/Migration/AppSchemaVersions.swift
  - DUNE/App/ContentView.swift
  - DUNEVision/App/VisionContentView.swift
  - DUNETests/AppMigrationPlanTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-01-swiftdata-schema-model-mismatch.md
  - docs/solutions/architecture/2026-03-12-mac-cloudkit-remote-change-auto-refresh.md
---

# Solution: Mac SwiftData Migration and Refresh Stability

## Problem

macOS에서 CloudKit-backed SwiftData store가 열리지 않거나, remote change 이후 SwiftUI가
background-thread publish 경고를 반복했다.

### Symptoms

- `Cannot use staged migration with an unknown model version` / `NSCocoaErrorDomain 134504`
- `ModelContainer failed` 후 in-memory fallback으로 강등
- `Publishing changes from background threads is not allowed` 경고 반복

### Root Cause

원인은 두 갈래였다.

1. `ExerciseDefaultRecord.isPreferred` 필드가 추가됐지만 migration plan은 여전히 `AppSchemaV12`를 최신 버전으로 유지했다.
   결과적으로 배포 당시 V12 checksum과 현재 live model checksum이 갈라져 기존 macOS store가 어떤 declared schema에도 매칭되지 않았다.
2. `refreshNeededStream` 소비 루프가 main actor 보장 없이 `refreshSignal`을 갱신해, CloudKit remote change 이후 SwiftUI state publish가 background executor에서 발생할 수 있었다.

## Solution

배포된 V12를 snapshot schema로 고정하고, 현재 live model을 `AppSchemaV13`으로 승격했다.
동시에 refresh stream 소비 후 UI state 갱신을 `MainActor.run`으로 고정했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift` | `AppSchemaV12` snapshot 추가, `AppSchemaV13` 및 `V12 -> V13` migration 추가 | 배포된 checksum 보존 + 기존 store를 최신 schema로 진화 |
| `DUNETests/AppMigrationPlanTests.swift` | 최신 버전이 V13인지, V12가 live `ExerciseDefaultRecord`를 참조하지 않는지 검증 | schema drift 회귀 방지 |
| `DUNE/App/ContentView.swift` | refresh signal 증가를 `MainActor.run`으로 이동 | background-thread publish 경고 제거 |
| `DUNEVision/App/VisionContentView.swift` | 동일 수정 적용 | 공용 refresh 패턴 일관성 유지 |
| `.claude/rules/swiftdata-cloudkit.md` | field 변경 시 새 schema version 필요 규칙 추가 | 재발 방지 |

### Key Code

```swift
enum AppSchemaV13: VersionedSchema {
    static let versionIdentifier = Schema.Version(13, 0, 0)
    static var models: [any PersistentModel.Type] {
        [
            ExerciseRecord.self,
            BodyCompositionRecord.self,
            WorkoutSet.self,
            CustomExercise.self,
            WorkoutTemplate.self,
            InjuryRecord.self,
            HabitDefinition.self,
            HabitLog.self,
            UserCategory.self,
            ExerciseDefaultRecord.self,
            HealthSnapshotMirrorRecord.self,
        ]
    }
}

static let migrateV12toV13 = MigrationStage.lightweight(
    fromVersion: AppSchemaV12.self,
    toVersion: AppSchemaV13.self
)
```

```swift
for await _ in coordinator.refreshNeededStream {
    await MainActor.run {
        refreshSignal += 1
    }
}
```

## Prevention

### Checklist Addition

- [ ] 최신 `VersionedSchema`가 live model을 참조한 상태에서 `@Model` 필드를 바꿨다면 새 schema version을 추가했는지 확인한다.
- [ ] macOS/iPad-on-Mac CloudKit 경로에서는 `NSPersistentStoreRemoteChange` 이후 UI state 갱신이 main actor로 복귀하는지 확인한다.
- [ ] schema 수정 후 build뿐 아니라 기존 store reopen 경로까지 검토한다.

### Rule Addition (if applicable)

`.claude/rules/swiftdata-cloudkit.md`에 "기존 @Model 필드 변경도 새 Schema 버전 필요" 규칙을 추가했다.

## Lessons Learned

- SwiftData staged migration은 "새 모델 추가"뿐 아니라 "기존 최신 schema가 참조하던 live model 변경"에도 매우 민감하다.
- macOS CloudKit refresh에서는 data layer가 actor-safe여도, 마지막 UI state publish 지점이 main actor인지 별도로 확인해야 한다.
