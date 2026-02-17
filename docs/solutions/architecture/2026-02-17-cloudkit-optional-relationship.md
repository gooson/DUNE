---
tags: [cloudkit, swiftdata, relationship, optional, crash, modelcontainer, schema]
category: architecture
date: 2026-02-17
severity: critical
related_files:
  - Dailve/Data/Persistence/Models/ExerciseRecord.swift
  - Dailve/App/DailveApp.swift
related_solutions: []
---

# Solution: CloudKit requires all @Relationship properties to be Optional

## Problem

### Symptoms

- 앱 삭제 후 재설치 시 첫 실행은 정상
- 두 번째 실행부터 `ModelContainer` 생성에서 fatal crash 발생
- 에러 메시지: `"CloudKit integration requires that all relationships be optional, the following are not: ExerciseRecord: sets"`

### Root Cause

SwiftData + CloudKit 통합 시, CloudKit은 **모든 `@Relationship` 프로퍼티가 Optional**이어야 한다.
`ExerciseRecord.sets`가 `[WorkoutSet]` (non-optional)으로 선언되어 있었기 때문에, CloudKit 스키마 검증 시 crash 발생.

첫 실행에서는 로컬 스토어가 새로 생성되어 문제가 없지만, 두 번째 실행부터 CloudKit 스키마 동기화가 시도되면서 검증 실패.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| ExerciseRecord.swift | `var sets: [WorkoutSet] = []` → `var sets: [WorkoutSet]? = []` | CloudKit Optional 요구사항 충족 |
| ExerciseRecord.swift | `hasSetData` / `completedSets`에 `(sets ?? [])` 적용 | Optional 접근 안전하게 처리 |
| WorkoutSessionViewModel.swift | `record.sets.append()` → 배열 구성 후 `record.sets = workoutSets` | Optional 배열에 append 대신 할당 |
| DailveApp.swift | Store 파일 삭제 fallback 추가 (`.sqlite`, `-wal`, `-shm`) | 스키마 변경 시 복구 경로 확보 |

### Key Code

```swift
// BEFORE (crash)
@Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exerciseRecord)
var sets: [WorkoutSet] = []

// AFTER (fixed)
@Relationship(deleteRule: .cascade, inverse: \WorkoutSet.exerciseRecord)
var sets: [WorkoutSet]? = []

// Computed properties must handle nil
var completedSets: [WorkoutSet] {
    (sets ?? []).filter(\.isCompleted).sorted { $0.setNumber < $1.setNumber }
}
```

## Prevention

### Checklist Addition

- [ ] SwiftData `@Relationship` 프로퍼티 추가 시 **반드시 Optional (`?`)** 으로 선언
- [ ] CloudKit 활성화된 프로젝트에서 `@Model` 변경 시 디바이스에서 삭제→재설치→재실행 2회 테스트

### Rule Addition

`.claude/rules/swiftdata-cloudkit.md`에 추가 권장:

```
## CloudKit + SwiftData Rules
- 모든 @Relationship 프로퍼티는 Optional이어야 함
- to-many relationship: `[Type]?` (not `[Type]`)
- to-one relationship: `Type?` (already optional by convention)
- @Model 스키마 변경 후 반드시 2회 실행 테스트 (첫 실행 OK → 두 번째 실행에서 crash 가능)
```

## Lessons Learned

1. CloudKit은 **두 번째 실행**부터 스키마를 검증한다 — 첫 실행에서 통과해도 안심할 수 없다
2. SwiftData의 `[Type]`은 내부적으로 non-optional이다. `[Type]? = []`로 선언하면 기본값은 있지만 타입은 Optional
3. Optional 배열에 `.append()`는 가능하지만, 배열을 구성한 후 한 번에 할당하는 것이 더 명확하다
4. `ModelContainer` 생성 실패 시 store 파일 삭제 fallback이 MVP 단계에서 유용하다 (데이터 보존보다 앱 실행 보장)
