---
tags: [watch, reorder, exercise, template, context-menu, watchos, swapAt]
date: 2026-03-15
category: solution
status: implemented
---

# Solution: Watch 템플릿 운동 순서 변경

## Problem

Watch에서 템플릿 기반 운동의 순서를 변경할 수 없어, 당일 장비/컨디션 상황에 따른 유연한 운동이 불가능했다. iOS에서는 `ExerciseReorderSheet`로 세션 중 드래그앤드롭이 가능하지만, Watch에는 해당 기능이 없었다.

### 기술적 과제

- `WorkoutManager`의 `templateSnapshot.entries`가 immutable (`let`)
- `completedSetsData`, `extraSetsPerExercise`가 position index 기반
- watchOS에서 드래그앤드롭 불가 → context menu 기반 UI 필요
- watchOS `.contextMenu`는 빈 클로저에도 overlay 표시 → 완료된 운동에 attach 금지

## Solution

### 1. WorkoutSessionTemplate.entries를 var로 변경

```swift
struct WorkoutSessionTemplate: Codable, Sendable {
    let name: String
    var entries: [TemplateEntry]  // let → var
}
```

### 2. WorkoutManager.moveExercise — 배열 동기화 swap

```swift
func moveExercise(at index: Int, direction: MoveDirection) {
    // completedSetsData를 entries.count까지 패딩 후 swap
    while completedSetsData.count < entryCount { completedSetsData.append([]) }
    completedSetsData.swapAt(index, targetIndex)

    // extraSetsPerExercise 키 재매핑
    // currentExerciseIndex → entry ID로 추적
}
```

### 3. 프리뷰 재정렬 — @State init 패턴

```swift
@State private var reorderedEntries: [TemplateEntry]

init(snapshot: WorkoutSessionTemplate) {
    self.snapshot = snapshot
    _reorderedEntries = State(initialValue: snapshot.entries)
}
```

`.onAppear` + `isEmpty` guard 대신 init에서 직접 초기화. snapshot 변경 시 stale 방지.

### 4. 세션 중 재정렬 — contextMenu 분기

```swift
if isCompleted {
    row  // contextMenu 없음
} else {
    row.contextMenu { /* Move Up / Move Down */ }
}
```

watchOS에서 `.contextMenu` 내부가 비어있으면 빈 overlay가 표시되므로, 완료된 운동에는 modifier 자체를 attach하지 않음.

## Prevention

### watchOS contextMenu 규칙

- `.contextMenu` 클로저 내부에서 조건부로 항목을 비우지 말 것 → modifier 자체를 조건부 적용
- 빈 contextMenu는 watchOS에서 dismiss 불가 overlay 생성

### 배열 동기화 swap 시 패딩

- `completedSetsData`는 세션 시작 시 entries.count로 초기화되지만, swap 전에 항상 패딩 확인
- `extraSetsPerExercise`는 position key swap → 인접 swap에서는 안전하지만, 비인접 이동 추가 시 entry ID 기반으로 전환 필요

### @State 초기화

- 외부 프로퍼티에서 파생되는 `@State`는 `.onAppear` 대신 `init`에서 `_state = State(initialValue:)` 패턴 사용
- `.onAppear` + isEmpty guard는 view 재사용 시 stale 데이터 위험

## Lessons Learned

1. watchOS `.contextMenu`는 iOS와 다르게 빈 메뉴도 full-screen overlay로 표시됨
2. `withAnimation`은 watchOS contextMenu 액션에서 효과 없음 (overlay dismiss 후 동기 렌더링)
3. watchOS sheet에서 `.navigationTitle`은 NavigationStack 없이 무시됨
4. 인접 swap의 position key 재매핑은 atomic하게 양쪽을 교환하면 안전
