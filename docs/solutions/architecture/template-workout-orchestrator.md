---
tags: [exercise, template, orchestrator, sequential-flow, workout, individual-logging]
date: 2026-03-03
category: solution
status: implemented
---

# 템플릿 워크아웃 개별 운동 순차 기록

## Problem

템플릿에서 워크아웃을 시작하면 첫 번째 운동만 `WorkoutSessionView`로 열리고 나머지 운동은 무시됨.
사용자는 템플릿의 모든 운동을 순차적으로 기록하고 싶지만 불가능했음.

## Solution

### 핵심 패턴: Orchestrator ViewModel

기존 `WorkoutSessionViewModel`을 개별 운동 단위로 재활용하되, 상위에 `TemplateWorkoutViewModel` orchestrator를 추가하여 운동 간 전환을 관리.

```
TemplateWorkoutViewModel (orchestrator)
  ├── exerciseViewModels: [WorkoutSessionViewModel]  // 개별 운동 VM
  ├── exerciseStatuses: [TemplateExerciseStatus]      // 상태 추적
  ├── currentExerciseIndex                             // 현재 운동
  └── savingExerciseIndex                              // 저장 중인 운동 (deferred .completed)
```

### 핵심 파일

| 파일 | 역할 |
|------|------|
| `Domain/Models/TemplateWorkoutConfig.swift` | Config struct + Status enum |
| `Presentation/Exercise/TemplateWorkoutViewModel.swift` | Orchestrator VM |
| `Presentation/Exercise/TemplateWorkoutView.swift` | Orchestrator View |
| `Presentation/Shared/WorkoutHealthKitWriter.swift` | 공유 HealthKit write 유틸 |
| `Presentation/Shared/Components/ExerciseSetColumnHeaders.swift` | 공유 column headers |
| `Domain/Protocols/ExerciseLibraryQuerying.swift` | `resolveExercises(from:)` extension |

### 저장 시점: Deferred Completion 패턴

`createRecordForCurrent()` → 레코드 생성 (`.completed` 미설정)
→ `modelContext.insert()` (실제 persistence)
→ `didFinishSaving()` (`.completed` 설정 + `isSaving` 리셋)

이 순서로 `.completed` 상태가 persistence 확인 후에만 설정됨.

### 프리필 2단계 분리

- `adjustSetCounts()` — init에서 호출 (weight unit 불필요)
- `prefillFromTemplateDefaults(weightUnit:)` — View의 `.onAppear`에서 호출 (weight unit 변환 필요)

### 코드 재활용 전략

| 재활용 컴포넌트 | 방식 |
|---------------|------|
| `WorkoutSessionViewModel` | 운동별 인스턴스 (sets, validation, record 생성) |
| `SetRowView` | 세트 입력 UI 그대로 사용 |
| `RestTimerView` | 세트 간 휴식 타이머 |
| `WorkoutCompletionSheet` | 전체 완료 시 요약 |
| `ExerciseSetColumnHeaders` | 신규 공유 컴포넌트 (CompoundWorkoutView와 공유) |
| `WorkoutHealthKitWriter` | 신규 공유 유틸 (3개 View에서 공유) |

## Prevention

- 동일 로직 3곳+ 발견 시 즉시 추출 (Correction #37)
- ViewModel에서 `.completed` 등 상태 변경은 persistence 확인 후
- weight unit 변환은 Display 계층에서 수행, VM은 unit 파라미터 수신
- `ExerciseLibraryQuerying` 확장으로 Domain 계층 내 로직 배치

## Related

- `docs/brainstorms/2026-03-03-individual-exercise-logging.md`
- `docs/plans/2026-03-03-individual-exercise-logging.md`
- Correction #37: 동일 로직 3곳+ 즉시 추출
- Correction #43: `isSaving` 리셋은 View에서 insert 완료 후
