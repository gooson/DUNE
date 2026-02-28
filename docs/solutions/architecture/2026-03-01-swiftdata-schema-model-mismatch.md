---
tags: [swiftdata, migration, schema, modelcontainer, coredata, cloudkit, crash]
date: 2026-03-01
category: solution
status: implemented
---

# SwiftData Staged Migration: ModelContainer와 VersionedSchema 모델 불일치

## Problem

### 증상
앱 실행 시 CoreData 에러 134504 발생, ModelContainer 생성 실패:
```
Cannot use staged migration with an unknown coordinator model version.
```
store 삭제 fallback도 동일하게 실패하여 앱이 완전히 사용 불가.

### 근본 원인
`ModelContainer`에 전달하는 모델 목록과 `SchemaMigrationPlan`의 최신 `VersionedSchema`에 등록된 모델이 불일치:

- **ModelContainer**: 10개 모델 (UserCategory, ExerciseDefaultRecord 포함)
- **AppSchemaV6 (최신)**: 8개 모델 (UserCategory, ExerciseDefaultRecord 누락)

CoreData의 staged migration은 실제 모델 해시를 migration plan의 모든 스키마 버전과 비교한다.
어떤 버전에도 매칭되지 않으면 "unknown coordinator model version" 에러 발생.
**새 store 생성 시에도** 최신 스키마와 실제 모델이 일치해야 하므로 fallback도 실패.

## Solution

### 변경 파일
| 파일 | 변경 |
|------|------|
| `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift` | AppSchemaV7 추가, migration plan 업데이트 |

### 핵심 변경
1. 누락된 모델을 포함한 `AppSchemaV7` 스키마 버전 추가
2. `AppMigrationPlan.schemas`에 V7 등록
3. `migrateV6toV7` lightweight migration stage 추가

```swift
enum AppSchemaV7: VersionedSchema {
    static let versionIdentifier = Schema.Version(7, 0, 0)
    static var models: [any PersistentModel.Type] {
        [ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self,
         CustomExercise.self, WorkoutTemplate.self, InjuryRecord.self,
         HabitDefinition.self, HabitLog.self,
         UserCategory.self, ExerciseDefaultRecord.self]  // 새로 추가된 모델
    }
}
```

## Prevention

### 체크리스트: 새 @Model 추가 시
1. `ModelContainer(for:)` 파라미터에 모델 추가
2. **최신 VersionedSchema의 `models` 배열에 모델 추가** ← 이번에 누락된 단계
3. 필요 시 새 스키마 버전 + migration stage 생성
4. CloudKit 2-run 검증: 삭제 → 설치 → 실행 → 재실행

### 자동 검증 방안
CI에서 ModelContainer의 모델 목록과 최신 VersionedSchema의 모델 목록을 비교하는 테스트 추가 고려.

## Lessons Learned

- SwiftData의 staged migration은 store가 없어도(새 생성) 최신 스키마 일치를 요구한다
- store 삭제 fallback이 있더라도 스키마 불일치 에러는 회복 불가
- 새 모델 추가 시 `ModelContainer`와 `VersionedSchema` 양쪽 모두 업데이트 필수
