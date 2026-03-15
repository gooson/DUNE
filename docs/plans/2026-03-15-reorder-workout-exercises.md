---
tags: [workout, template, reorder, drag-and-drop]
date: 2026-03-15
category: plan
status: draft
---

# Plan: 운동 중 템플릿 운동 순서 변경

## Summary

템플릿 기반 운동 세션에서 미완료 운동의 순서를 실시간으로 변경할 수 있는 기능 구현.
완료된 운동은 고정, 원본 템플릿 불변, iOS만 대상.

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `DUNE/Presentation/Exercise/TemplateWorkoutViewModel.swift` | 수정 | `moveExercise(from:to:)` 추가, 병렬 배열 동시 재정렬 |
| `DUNE/Presentation/Exercise/TemplateWorkoutView.swift` | 수정 | 재정렬 시트 UI, toolbar 버튼 추가 |
| `Shared/Resources/Localizable.xcstrings` | 수정 | "Reorder Exercises" 등 새 문자열 추가 |
| `DUNETests/TemplateWorkoutTests.swift` | 수정 | moveExercise 유닛 테스트 추가 |

## Design Decisions

### 병렬 배열 직접 재정렬 vs displayOrder 인덱스 매핑

**선택: 병렬 배열 직접 재정렬**

- ViewModel이 자체적으로 `exercises`, `templateEntries`, `exerciseViewModels`, `exerciseStatuses` 4개 배열을 관리
- `config`의 원본 배열은 불변으로 유지하되, ViewModel이 init 시 config에서 복사한 mutable 배열을 사용
- 현재 이미 `exerciseViewModels`와 `exerciseStatuses`는 ViewModel 소유 배열
- `config.exercises`와 `config.templateEntries`만 ViewModel로 복사하면 됨

**근거**: displayOrder 인덱스 매핑은 모든 접근 시 indirection이 필요하고, 기존 코드의 `config.exercises[index]` 패턴을 전부 변경해야 함. 배열 복사 후 직접 재정렬이 더 단순.

### UI: 재정렬 시트

**선택: toolbar 버튼 → List + .onMove 시트**

- 수평 탭 바 직접 drag는 구현 복잡도 높고 SwiftUI 네이티브 지원 부족
- 시트 방식이 안정적이고 발견성도 좋음
- 완료된 운동은 `.moveDisabled(true)`로 고정

## Implementation Steps

### Step 1: ViewModel 배열 소유권 변경

`TemplateWorkoutViewModel`에서 `config.exercises`와 `config.templateEntries` 대신
자체 mutable 배열 사용:

```swift
// 기존: config.exercises[index] 로 접근
// 변경: exercises[index] 로 접근 (ViewModel 소유)
var exercises: [ExerciseDefinition]
var templateEntries: [TemplateEntry]
```

init에서 config로부터 복사. 기존 `config.exercises` 참조를 모두 `exercises`로 교체.

**Verification**: 기존 동작이 변경 없이 유지되는지 확인 (빌드 통과)

### Step 2: moveExercise 메서드 추가

```swift
func moveExercise(from source: IndexSet, to destination: Int) {
    exercises.move(fromOffsets: source, toOffset: destination)
    templateEntries.move(fromOffsets: source, toOffset: destination)
    exerciseViewModels.move(fromOffsets: source, toOffset: destination)
    exerciseStatuses.move(fromOffsets: source, toOffset: destination)

    // currentExerciseIndex 추적 업데이트
    // (현재 운동의 새 위치를 찾아 갱신)
}
```

**Edge cases**:
- currentExerciseIndex가 이동한 운동을 가리키면 → 새 위치로 갱신
- 완료된 운동은 호출 전에 필터링 (View에서 `.moveDisabled`)

**Verification**: 유닛 테스트 통과

### Step 3: View에 재정렬 시트 추가

TemplateWorkoutView에:
1. `@State private var showingReorderSheet = false`
2. toolbar에 list.bullet 아이콘 버튼 (2개 이상 미완료 운동 있을 때만 활성화)
3. `.sheet` modifier로 재정렬 시트 표시
4. 시트 내용: `List` + `ForEach` + `.onMove` + `.moveDisabled(status == .completed)`

**Verification**: 시트가 정상 표시되고 drag 재정렬이 동작

### Step 4: Localization

`Localizable.xcstrings`에 추가:
- "Reorder Exercises" → ko: "운동 순서 변경", ja: "エクササイズの並べ替え"

### Step 5: Draft persistence 호환

`saveDraft()`/`restoreFromDraft()`는 이미 exerciseIDs 기반으로 동작.
재정렬 후에도 현재 순서가 draft에 반영되도록 `exercises` 배열 기준으로 ID 저장.
기존 로직이 이미 올바르게 동작하므로 추가 변경 불필요.

### Step 6: 유닛 테스트

`DUNETests/TemplateWorkoutTests.swift`에 추가:
- `moveExercise` 기본 동작 (2개 운동 순서 교환)
- 완료된 운동은 이동 후에도 상태 유지
- currentExerciseIndex 추적 정확성
- 3개 이상 운동에서 중간 운동 이동

## Test Strategy

| 테스트 유형 | 범위 |
|-----------|------|
| 유닛 테스트 | moveExercise 배열 동기화, currentIndex 추적 |
| 수동 검증 | 시트 UI, drag 동작, 완료 운동 고정 |

## Risks & Edge Cases

| 리스크 | 대응 |
|-------|------|
| 현재 진행 중 운동 이동 시 혼란 | 진행 중 운동도 이동 허용, currentExerciseIndex 자동 추적 |
| draft 복원 시 순서 불일치 | exerciseIDs 배열이 현재 순서 반영하므로 자연스럽게 호환 |
| 운동 1개일 때 재정렬 | 버튼 비활성화 |
