---
tags: [swiftdata, migration, checksum, cloudkit, snapshot, workoutset]
category: architecture
date: 2026-03-12
severity: important
related_files:
  - DUNE/Data/Persistence/Migration/AppSchemaVersions.swift
  - DUNETests/AppMigrationPlanTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-12-mac-swiftdata-migration-refresh-stability.md
  - docs/solutions/architecture/2026-03-12-set-rpe-integration.md
  - docs/solutions/general/2026-03-04-habit-recurring-start-point.md
---

# Solution: SwiftData Duplicate Version Checksums Across Migration Stages

## Problem

`ModelContainer` 생성 시 `Duplicate version checksums across stages detected.` 예외로 앱이 부팅 직후 종료됐다.

### Symptoms

- `makeModelContainer(configuration:)` 호출 시 `NSInvalidArgumentException`
- `AppMigrationPlan`이 선언된 상태에서도 `ModelContainer` 초기화가 실패
- `V12`/`V13`/`V14` schema를 도입한 뒤 기존 store reopen 경로가 깨짐

### Root Cause

`ExerciseDefaultRecord.isPreferred` 대응용 schema 분기와 `WorkoutSet.rpe` 대응용 schema 분기가 merge 과정에서 서로 덮어씌워졌다.
그 결과:

1. `AppSchemaV12`가 pre-`isPreferred` snapshot을 잃고 live `ExerciseDefaultRecord`를 참조했다.
2. `AppSchemaV13`와 `AppSchemaV12`가 모두 pre-`rpe` `WorkoutSet` snapshot만 가리키게 됐다.
3. 인접 migration stage가 버전 번호는 다르지만 실질적으로 동일 checksum을 만들어 SwiftData staged migration이 즉시 중단됐다.

## Solution

`V12 -> V13`은 preferred flag 도입, `V13 -> V14`는 set-level RPE 도입으로 다시 분리했다.
`AppSchemaV12`에는 pre-`isPreferred` `ExerciseDefaultRecord` snapshot을 복구하고,
`AppSchemaV13`은 live `ExerciseDefaultRecord` + pre-`rpe` `WorkoutSet` snapshot을 유지했다.
그리고 테스트에 in-memory `ModelContainer` 생성 검증을 추가해 duplicate checksum을 런타임 수준에서 다시 잡도록 했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift` | `AppSchemaV12.ExerciseDefaultRecord` snapshot 복구, V12/V13/V14 역할 정렬 | 인접 schema checksum을 feature 단계별로 분리 |
| `DUNETests/AppMigrationPlanTests.swift` | latest schema expectation을 V14로 갱신, snapshot invariant + in-memory container init 테스트 추가 | checksum 회귀를 자동 검출 |

### Key Code

```swift
enum AppSchemaV12: VersionedSchema {
    static var models: [any PersistentModel.Type] {
        [
            ExerciseRecord.self,
            BodyCompositionRecord.self,
            V12WorkoutSet.self,
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

    @Model
    final class ExerciseDefaultRecord {
        var id: UUID = UUID()
        var exerciseDefinitionID: String = ""
        var defaultWeight: Double?
        var defaultReps: Int?
        var isManualOverride: Bool = false
        var lastUsedDate: Date = Date()
    }
}
```

```swift
@Test("Migration plan builds an in-memory model container without duplicate checksums")
func migrationPlanBuildsContainer() throws {
    _ = try ModelContainer(
        for: AppMigrationPlan.currentSchema,
        migrationPlan: AppMigrationPlan.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}
```

## Prevention

### Checklist Addition

- [ ] merge conflict 후 `VersionedSchema` 최신 2~3개 버전이 각각 어떤 feature delta를 담당하는지 다시 확인한다.
- [ ] snapshot model을 추가/이동한 뒤에는 `ModelContainer` in-memory init 테스트로 duplicate checksum을 직접 검증한다.
- [ ] 기존 live `@Model`을 과거 schema에서 다시 참조하지 않았는지 `ObjectIdentifier` 기반 테스트로 확인한다.

### Rule Addition (if applicable)

기존 `.claude/rules/swiftdata-cloudkit.md`가 이미 schema drift와 snapshot 필요성을 다루고 있어 새 rule 추가는 하지 않았다.

## Lessons Learned

- SwiftData migration 충돌은 "필드가 같은 snapshot이 두 번 이어지는 상황"에서도 즉시 터지므로, 버전 번호보다 feature delta 분리가 더 중요하다.
- checksum 회귀는 타입 비교만으로는 놓칠 수 있어서, 실제 `ModelContainer` 생성 테스트가 가장 강한 안전장치다.
