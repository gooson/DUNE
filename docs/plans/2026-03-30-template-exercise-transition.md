---
tags: [template-workout, exercise-transition, watch, ux]
date: 2026-03-30
category: plan
status: draft
---

# Plan: Template Exercise Transition Selection

## Summary

템플릿 운동 전환 시 "다음 운동을 할지" 명시적으로 선택하는 UX 추가.
A 완료 → "B 할래?" Start/Skip → Skip 시 "C 할래?" → 모두 Skip 시 세션 종료.

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Presentation/Exercise/TemplateWorkoutView.swift` | 전환 오버레이에 Skip 버튼 추가 |
| `DUNE/Presentation/Exercise/TemplateWorkoutViewModel.swift` | `skipAndAdvance()` 메서드 추가, `advanceToNext()` 분리 |
| `DUNEWatch/Views/MetricsView.swift` | 3초 자동진행 → Start/Skip 버튼 2개로 교체 |
| `DUNEWatch/Managers/WorkoutManager.swift` | `skipExercise()` 상태 추적 추가 (skippedIndices) |
| `DUNETests/TemplateWorkoutViewModelTests.swift` | skipAndAdvance 테스트 추가 |

## Implementation Steps

### Step 1: iOS TemplateWorkoutViewModel — Skip+Advance 로직

**현재 문제**: `skipCurrentExercise()`는 skip 후 자동으로 다음으로 이동하고 전환 오버레이를 닫아버림. 전환 오버레이에서 Skip을 누르면 다음 운동을 다시 오버레이로 제안해야 함.

**변경**:
- `skipAndAdvance() -> Bool` 메서드 추가: 현재 운동 `.skipped`, 다음 pending 찾아서 `currentExerciseIndex` 업데이트. 남은 pending이 있으면 `true`, 없으면 `false` 반환
- 기존 `skipCurrent()` 은 탭 바에서의 스킵 용도로 유지

**검증**: `skipAndAdvance()` 호출 후 `currentExerciseIndex`가 다음 pending을 가리키는지 확인

### Step 2: iOS TemplateWorkoutView — 전환 오버레이 Skip 버튼

**현재**: 전환 오버레이에 "Start" 버튼만 있음
**변경**:
- "Skip" 버튼을 "Start" 옆에 추가 (HStack)
- Skip 탭 시 `viewModel.skipAndAdvance()` 호출
  - `true` → 오버레이 유지, 다음 운동 이름으로 갱신
  - `false` → 모든 운동 skipped → `finishWorkout()` 호출
- Start 버튼: 기존 동작 유지 (`showTransition = false`)
- 근육 정보 제거 (운동 이름만 표시로 결정)

**검증**: Start 탭 → 운동 시작, Skip 탭 → 다음 운동 제안, 모두 Skip → 세션 종료

### Step 3: Watch WorkoutManager — Skip 상태 추적

**현재**: `skipExercise()`는 단순히 `advanceToNextExercise()`를 호출 (index +1)
**변경**:
- `skippedExerciseIndices: Set<Int>` 프로퍼티 추가
- `skipExercise()` → `skippedExerciseIndices.insert(currentExerciseIndex)` + 다음 non-skipped pending 찾기
- `advanceToNextNonSkipped() -> Bool` 추가: 다음 pending(skipped가 아닌) exercise 찾기. 없으면 `false`
- `isAllSkippedOrDone` computed property: 남은 pending 없음 확인

**검증**: skipExercise 후 `currentExerciseIndex`가 올바른 다음 exercise를 가리키는지

### Step 4: Watch MetricsView — Start/Skip 버튼 UI

**현재**: 3초 자동진행 + ProgressView
**변경**:
- `transitionTask` (3초 자동진행) 제거
- "Next Exercise" 텍스트 + 운동 이름 유지
- Start 버튼 (초록, `.positive`) + Skip 버튼 (회색, `.secondary`) 추가
- Start: `workoutManager.advanceToNextExercise()` + `showNextExercise = false` + `prefillFromEntry()` + haptic
- Skip: `workoutManager.skipExercise()` 호출
  - 남은 pending 있으면 → 운동 이름 갱신 (오버레이 유지)
  - 남은 pending 없으면 → `workoutManager.end()` (세션 종료)

**검증**: Start → 다음 운동 시작, Skip → 다음 제안, 모두 Skip → 세션 종료

### Step 5: Unit Tests

- `TemplateWorkoutViewModelTests`에 추가:
  - `testSkipAndAdvance_movesToNextPending`: 3개 운동 중 첫째 skip → 둘째로 이동
  - `testSkipAndAdvance_allSkipped_returnsFalse`: 마지막 pending skip → false
  - `testSkipAndAdvance_middleSkipped_skipsToNext`: B skip → C 제안
  - `testSkipAndAdvance_preservesCompletedStatus`: A 완료 + B skip → C 제안, A는 .completed 유지

## Test Strategy

| Test | Type | Description |
|------|------|-------------|
| `testSkipAndAdvance_movesToNextPending` | Unit | Skip 후 다음 pending index로 이동 |
| `testSkipAndAdvance_allSkipped_returnsFalse` | Unit | 모든 운동 skip 시 false 반환 |
| `testSkipAndAdvance_middleSkipped_skipsToNext` | Unit | 중간 skip 후 다음 pending으로 |
| `testSkipAndAdvance_preservesCompletedStatus` | Unit | 완료된 운동 상태 보존 |

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| Watch 3초 자동진행 제거 시 기존 사용자 혼란 | Start 버튼에 초록 tint로 명확한 CTA |
| 모든 운동 skip 후 세션 종료 시 빈 세션 | `hasAnyCompleted` 확인 — 완료 운동 없으면 세션 폐기 |
| iOS 탭 바에서 skipped 운동 다시 선택 시 | 기존 로직 유지 — `.skipped`도 탭 가능 |
| Watch에서 마지막 운동 skip | `isAllSkippedOrDone` 체크 후 `end()` 호출 |

## Localization

"Skip", "Start", "Next Exercise", "Up Next" 모두 iOS/Watch xcstrings에 이미 등록됨.
새 문자열 추가 불필요.
