---
tags: [swiftui, dto, factory-method, task-id, hasher, atomic-state, keyword-table, dry, unified-row]
category: architecture
date: 2026-02-19
severity: important
related_files:
  - Dailve/Presentation/Shared/Models/ExerciseListItem.swift
  - Dailve/Presentation/Activity/Components/ExerciseListSection.swift
  - Dailve/Presentation/Exercise/ExerciseViewModel.swift
  - Dailve/Domain/Models/WorkoutActivityType.swift
  - Dailve/Presentation/Shared/Components/UnifiedWorkoutRow.swift
related_solutions:
  - 2026-02-19-dry-extraction-shared-components.md
  - 2026-02-18-review-fix-patterns.md
---

# Solution: Unified Workout Row — 6관점 리뷰 수정 패턴

## Problem

UnifiedWorkoutRow 통합 과정에서 3개 P1, 10개 P2, 7개 P3 이슈가 6관점 리뷰에서 발견됨.

### Symptoms

1. **DRY 위반**: `ExerciseRecord → ExerciseListItem` 매핑이 ExerciseViewModel과 ExerciseListSection에 중복
2. **Stale data**: `.task(id:)` 키가 count 기반이라 같은 count 다른 content 변경을 감지 못함
3. **State desync**: items와 recordsByID가 별도 할당되어 Task 취소 시 불일치 가능
4. **False-positive**: `infer(from:)` 의 bare "row" 키워드가 "Dumbbell Row"를 `.rowing`으로 매칭

### Root Cause

- DTO가 ViewModel에 정의되어 다른 View에서 재사용 시 매핑 로직을 복사해야 했음
- String interpolation 기반 task key는 content hash가 아닌 metadata 기반
- 두 `@State` 변수의 연속 할당 사이에 Task 취소가 발생하면 하나만 업데이트됨
- `switch case let n where n.contains("row")` 패턴은 부분 문자열 충돌에 취약

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `Shared/Models/ExerciseListItem.swift` | NEW — DTO + static factory methods | DRY: 단일 매핑 로직 |
| `ExerciseViewModel.swift` | struct 제거, factory 호출로 교체 | 중복 제거 |
| `ExerciseListSection.swift` | Hasher 기반 taskID + 원자적 업데이트 | Stale data + desync 방지 |
| `WorkoutActivityType.swift` | keyword table 패턴으로 전환 | False-positive 제거 + 유지보수성 |
| `UnifiedWorkoutRow.swift` | 칼로리 bounds, color hoist, pace guard | 방어 코딩 |
| `ExerciseSessionDetailView.swift` | isLoadingHR reset on cancellation | Correction #17 준수 |
| `ExerciseCategory.swift` | .cardio default → .mixedCardio | 의미 일치 |

### Key Code

**Static Factory Method (DRY)**:
```swift
// Shared/Models/ExerciseListItem.swift
static func fromManualRecord(
    _ record: ExerciseRecord,
    library: ExerciseLibraryQuerying
) -> ExerciseListItem { ... }

static func fromWorkoutSummary(_ workout: WorkoutSummary) -> ExerciseListItem { ... }
```

**Hasher-based content key**:
```swift
private var taskID: Int {
    var hasher = Hasher()
    for w in workouts { hasher.combine(w.id) }
    for r in exerciseRecords { hasher.combine(r.id) }
    return hasher.finalize()
}
```

**Atomic state update**:
```swift
private func buildItemsAndIndex() -> ([ExerciseListItem], [UUID: ExerciseRecord]) {
    // ... build both together ...
    return (items, index)
}

.task(id: taskID) {
    let (newItems, newIndex) = buildItemsAndIndex()
    guard !Task.isCancelled else { return }
    items = newItems          // 둘 다 한번에
    recordsByID = newIndex
}
```

**Keyword table pattern**:
```swift
static func infer(from exerciseName: String) -> WorkoutActivityType? {
    let name = exerciseName.lowercased()
    let table: [(keyword: String, type: WorkoutActivityType)] = [
        ("jump rope", .jumpRope), ("jumprope", .jumpRope),
        ("kickbox", .kickboxing),
        ("running", .running),
        // ... longer keywords first to avoid false-positives
        ("rowing", .rowing),  // NOT "row" — prevents "Dumbbell Row" match
    ]
    return table.first { name.contains($0.keyword) }?.type
}
```

## Prevention

### Checklist Addition

- [ ] 동일 데이터를 2곳 이상에서 DTO로 변환하면 static factory method 추출
- [ ] `.task(id:)` key가 count가 아닌 content hash 기반인지 확인
- [ ] 관련 `@State` 변수 2개 이상을 동시 업데이트 시 tuple return + isCancelled guard
- [ ] 문자열 매칭 키워드가 짧으면 (<4자) false-positive 시나리오 테스트 작성

### Rule Addition

**DTO 위치 규칙**: Presentation 레이어의 공유 DTO는 `Presentation/Shared/Models/`에 배치. ViewModel 내부에 정의하면 다른 View에서 재사용 불가.

## Lessons Learned

1. **DTO는 사용처가 2개 이상이면 즉시 분리**: ViewModel 내부 struct는 처음엔 편하지만 두 번째 사용처에서 DRY 위반 발생. 처음부터 `Shared/Models/`에 배치하는 것이 낫다.

2. **`.task(id:)` key는 content-aware여야 한다**: count 기반 key는 삭제+추가가 동시에 일어나면 감지 실패. `Hasher`로 ID를 combine하면 O(N) 비용으로 content 변경을 확실히 감지.

3. **Keyword matching에는 테스트가 필수**: "row" vs "rowing"처럼 짧은 키워드는 실제 운동명에서 false-positive를 일으킴. `noFalsePositive*` 테스트 케이스를 키워드 추가마다 작성.

4. **원자적 상태 업데이트 패턴**: 관련 `@State` 변수를 개별 할당하면 중간 상태가 렌더에 노출될 수 있음. tuple로 묶어 빌드 → isCancelled 확인 → 동시 할당 패턴 사용.
