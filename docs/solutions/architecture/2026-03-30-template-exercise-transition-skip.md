---
tags: [template-workout, exercise-transition, skip, watch, ux]
date: 2026-03-30
category: solution
status: implemented
---

# Template Exercise Transition — Skip Selection UX

## Problem

템플릿 운동(A, B, C) 진행 시, A 완료 후 자동으로 B를 보여주고 "Start" 버튼만 제공했다. 사용자가 특정 운동을 건너뛰고 싶을 때 별도 경로(탭 바 → Skip Exercise 버튼)를 찾아야 했다.

Watch에서는 3초 자동진행으로 선택 기회 자체가 없었다.

## Solution

### iOS: 전환 오버레이에 Start/Skip 버튼 쌍

`TemplateWorkoutView.transitionOverlay`에 Skip 버튼 추가:
- Start → 운동 시작 (기존 동작)
- Skip → `viewModel.skipAndAdvance()` 호출 → 다음 pending 제안
- 모두 skip → `finishWorkout()` 또는 `dismiss()`

### Watch: 3초 자동진행 → 명시적 Start/Skip

`MetricsView.nextExerciseTransition`에서:
- `transitionTask` (3초 auto-advance) 제거
- Start 버튼 (초록) + Skip 버튼 (회색) 추가
- Skip → `workoutManager.skipExercise()` → 남은 pending 있으면 제안, 없으면 `end()`

### Skip-Aware 진행 (Watch)

`WorkoutManager`에 `skippedExerciseIndices: Set<Int>` 추가:
- `advanceToNextExercise()`: `nextPendingExerciseIndex()` helper로 skipped index를 건너뜀
- `skipExercise() -> Bool`: skip 등록 + 다음 pending 탐색
- `isAllExercisesDone`: skipped + completed 모두 체크
- `moveExercise()`: reorder 시 skippedIndices 재매핑

### DRY: skipCurrent → skipAndAdvance 위임

iOS `TemplateWorkoutViewModel`에서 `skipCurrent()`와 `skipAndAdvance()`의 중복 로직을 제거. `skipCurrent()`가 `skipAndAdvance()`에 위임.

## Prevention

- **Watch advance와 skip이 같은 "다음 pending" 로직을 공유해야 함**: `advanceToNextExercise()`가 skipped index를 무시하면 이미 skip한 운동이 전환 화면에 다시 등장하는 버그 발생. 공유 helper `nextPendingExerciseIndex()` 추출로 해결.
- **Index 기반 Set은 reorder 시 반드시 재매핑**: `skippedExerciseIndices`처럼 exercise index를 key로 쓰는 데이터는 `moveExercise()`에서 기존 `extraSetsPerExercise` 패턴과 동일하게 swap 처리.

## Lessons Learned

- Watch의 auto-advance(3초 타이머) 같은 "편의 기능"은 사용자 선택권을 빼앗음. 명시적 2-button UX가 더 적절.
- iOS `TemplateWorkoutViewModel`의 `findNextPendingIndex(after:)`는 pending만 탐색. Watch는 skipped+completed 모두 고려하는 별도 로직 필요 (플랫폼 간 상태 모델 차이).
