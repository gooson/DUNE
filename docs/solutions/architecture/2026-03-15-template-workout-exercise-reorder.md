---
tags: [template-workout, reorder, parallel-arrays, draft-persistence, swiftui-list]
date: 2026-03-15
category: solution
status: implemented
---

# Solution: 운동 중 템플릿 운동 순서 변경

## Problem

템플릿 기반 운동 세션에서 사용자가 장비 점유, 컨디션 등의 이유로 운동 순서를 변경하고 싶지만, 기존에는 스킵/점프만 가능하고 순서 재배치는 불가능했다.

### 기술적 과제

- `TemplateWorkoutViewModel`이 4개 병렬 배열(`exercises`, `templateEntries`, `exerciseViewModels`, `exerciseStatuses`)로 운동 상태를 관리
- `TemplateWorkoutConfig`는 immutable (`let` 배열)
- Draft persistence가 `exerciseIDs` 배열 순서에 의존
- `currentExerciseIndex`가 이동 시 추적 필요

## Solution

### 1. ViewModel 배열 소유권 전환

`config.exercises`와 `config.templateEntries`를 ViewModel이 mutable copy로 소유:

```swift
var exercises: [ExerciseDefinition]  // config에서 복사
var templateEntries: [TemplateEntry]  // config에서 복사
```

`config`는 원본 참조용으로 유지 (templateName 등), 순서 관련 접근은 모두 mutable copy 경유.

### 2. moveExercise — 4배열 동시 이동

```swift
func moveExercise(from source: IndexSet, to destination: Int) {
    guard source.allSatisfy({ exerciseStatuses[$0] != .completed }) else { return }
    let currentExerciseID = exercises[currentExerciseIndex].id

    exercises.move(fromOffsets: source, toOffset: destination)
    templateEntries.move(fromOffsets: source, toOffset: destination)
    exerciseViewModels.move(fromOffsets: source, toOffset: destination)
    exerciseStatuses.move(fromOffsets: source, toOffset: destination)

    if let newIndex = exercises.firstIndex(where: { $0.id == currentExerciseID }) {
        currentExerciseIndex = newIndex
    }
}
```

### 3. Draft 복원 시 순서 재적용

Draft가 재정렬된 순서로 저장되었을 때, 복원 시 set 비교 후 배열 순서 재적용:

```swift
let currentIDs = Set(exercises.map(\.id))
let draftIDs = Set(draft.exerciseIDs)
guard currentIDs == draftIDs else { return false }

if exercises.map(\.id) != draft.exerciseIDs {
    // Reorder all 4 arrays to match draft order
}
```

### 4. UI — ExerciseReorderSheet

- `List` + `ForEach(exercises, id: \.id)` + `.onMove` + `.moveDisabled`
- `.environment(\.editMode, .constant(.active))` 로 항상 편집 모드
- 완료된 운동은 `.moveDisabled(true)` + 0.6 opacity
- Sheet로 표시 (`.presentationDetents([.medium, .large])`)

## Prevention

### 병렬 배열 패턴 주의사항

- 배열 추가/삭제 시 `moveExercise`의 동기화도 반드시 업데이트
- 테스트 `moveKeepsArraysInSync`가 이 불변조건을 검증
- 향후 배열이 5개 이상이 되면 `ExerciseSlot` struct로 통합 고려

### SwiftUI ForEach + .onMove

- `ForEach(indices, id: \.self)`는 재정렬 후 잘못된 셀 매칭 유발
- 반드시 `ForEach(items, id: \.stableID)` 사용
- `.onMove` 핸들러에 `withAnimation` 래핑 금지 — List가 자체 애니메이션 관리

### Draft 복원과 재정렬

- Draft의 `exerciseIDs` 순서가 init-time 순서와 다를 수 있음
- 복원 시 strict equality 대신 set equality + reorder 적용

## Lessons Learned

1. 병렬 배열은 동시 이동이 필수 — 하나라도 빠지면 silent corruption
2. SwiftUI의 `.moveDisabled`는 UI 전용 — ViewModel에도 guard 필요
3. Draft persistence는 순서 변경 기능 추가 시 반드시 검토 대상
4. `ForEach + id: \.self` on indices는 reorder와 양립 불가
