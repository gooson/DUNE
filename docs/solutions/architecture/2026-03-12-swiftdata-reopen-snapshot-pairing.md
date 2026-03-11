---
tags: [swiftdata, migration, checksum, relationship, snapshot, watch]
category: architecture
date: 2026-03-12
severity: important
related_files:
  - DUNE/Data/Persistence/Migration/AppSchemaVersions.swift
  - DUNETests/AppMigrationPlanTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-12-swiftdata-duplicate-version-checksums.md
  - docs/solutions/architecture/2026-03-07-non-distance-cardio-machine-level-model.md
---

# Solution: SwiftData Reopen Stability Requires Snapshotting Relationship Pairs

## Problem

watch simulator에서 `Duplicate version checksums across stages detected.` 예외로 앱이 부팅 직후 종료됐다.
기존 `AppMigrationPlanTests`는 통과했지만, persisted store를 다시 열 때만 staged migration이 깨졌다.

### Symptoms

- `ModelContainer` in-memory 생성 테스트는 통과
- 기존 SQLite store reopen 경로에서만 crash 또는 migration 실패
- `V11`/`V12`/`V13`로 만든 on-disk store를 현재 migration plan으로 다시 열 수 없었음

### Root Cause

`V12`/`V13` schema가 `WorkoutSet`만 snapshot으로 고정하고, 관계 반대편인 `ExerciseRecord`는 live model을 그대로 참조하고 있었다.
이 반쪽 snapshot 상태에서는 새 store 생성은 가능해도, persisted store checksum을 staged migration이 안정적으로 식별하지 못한다.
추가로 `V13`이 live `ExerciseDefaultRecord`를 계속 참조해, reopen 안정성이 미래 live model 변경에 다시 노출돼 있었다.

## Solution

`V12`/`V13`에서 `ExerciseRecord`와 `WorkoutSet`을 관계 쌍으로 함께 snapshot화하고,
`V13.ExerciseDefaultRecord`도 snapshot으로 고정했다.
그리고 테스트를 in-memory 생성 검증에서 멈추지 않고, 실제 SQLite store를 각 버전 schema로 만든 뒤
현재 migration plan으로 reopen하는 회귀 테스트까지 확장했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift` | `V12ExerciseRecord`, `V13ExerciseRecord`, `V13.ExerciseDefaultRecord` snapshot 추가 | 관계 모델과 shipped checksum을 self-contained하게 고정 |
| `DUNETests/AppMigrationPlanTests.swift` | V12/V13 snapshot invariants와 V11/V12/V13 on-disk reopen 테스트 추가 | persisted store reopen 회귀를 자동 검출 |

### Key Code

```swift
enum AppSchemaV12: VersionedSchema {
    static var models: [any PersistentModel.Type] {
        [
            V12ExerciseRecord.self,
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
    final class V12ExerciseRecord {
        @Relationship(deleteRule: .cascade, inverse: \V12WorkoutSet.exerciseRecord)
        var sets: [V12WorkoutSet]? = []
    }

    @Model
    final class V12WorkoutSet {
        var exerciseRecord: V12ExerciseRecord?
    }
}
```

```swift
@Test("Migration plan reopens a V12 on-disk store")
func migrationPlanReopensV12Store() throws {
    let storeURL = makeTemporaryStoreURL()
    defer { removeStoreFiles(at: storeURL) }

    try createStore(at: storeURL, schema: Schema(AppSchemaV12.models))
    _ = try reopenStoreWithMigrationPlan(at: storeURL)
}
```

## Prevention

### Checklist Addition

- [ ] `VersionedSchema`에서 관계 모델(`ExerciseRecord`/`WorkoutSet`처럼 서로 inverse를 가지는 타입)을 snapshot화할 때는 한쪽만 분리하지 않는다.
- [ ] migration 테스트에 `in-memory ModelContainer` 생성만 두지 말고, 최소 1개 이상 과거 schema로 만든 SQLite store reopen 테스트를 포함한다.
- [ ] shipped version이 된 schema는 live model 참조를 남기지 않았는지 다시 확인한다.

### Rule Addition (if applicable)

기존 `.claude/rules/swiftdata-cloudkit.md`와 2026-03-07 solution이 같은 방향을 이미 다루고 있어 새 rule 파일은 추가하지 않았다.

## Lessons Learned

- SwiftData migration 안정성은 “현재 schema가 열리는가”보다 “과거 checksum을 현재 plan이 다시 식별할 수 있는가”가 더 중요하다.
- 관계형 `@Model`은 snapshot을 부분적으로만 떼어내면 in-memory 테스트로는 안 잡히는 reopen 회귀가 생길 수 있다.
