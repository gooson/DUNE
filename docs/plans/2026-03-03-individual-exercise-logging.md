---
tags: [exercise, template, sequential-flow, individual-logging]
date: 2026-03-03
category: plan
status: draft
---

# Plan: 템플릿 워크아웃 개별 운동 순차 기록

## Problem

`ExerciseView.startFromTemplate()`이 템플릿의 첫 번째 운동만 시작하고 나머지를 무시한다.
사용자가 템플릿의 모든 운동을 순차적으로 기록할 수 있어야 한다.

## Approach

기존 `WorkoutSessionView`(Watch-style 세트별 진행 UI)를 **그대로 재활용**하되, 상위에 orchestrator View/ViewModel을 추가하여 운동 간 전환을 관리한다.

`CompoundWorkoutView`/`CompoundWorkoutViewModel`의 패턴을 참고하되, 라운드 개념 없이 단일 패스 순차 진행으로 단순화한다.

### 기존 코드 재활용 전략

| 기존 컴포넌트 | 재활용 방식 |
|-------------|----------|
| `WorkoutSessionViewModel` | 운동별 인스턴스 생성, `createValidatedRecord()` 패턴 유지 |
| `WorkoutSessionView`의 UI 패턴 | 세트 입력 UI를 참고하되, orchestrator View 내에 인라인 |
| `TemplateEntry` | `defaultSets/Reps/WeightKg`로 초기 세트 프리필 |
| `WorkoutCompletionSheet` | 전체 완료 시 1회 표시 |

### 핵심 결정: WorkoutSessionView embed 불가

`WorkoutSessionView`는 내부에 `saveWorkout()` → `dismiss()` + share sheet 로직이 강결합되어 있어 직접 embed가 어렵다. 대신:
- `WorkoutSessionViewModel`을 재활용 (세트 관리, validation, record 생성)
- UI는 `WorkoutSessionView`의 패턴을 참고하여 orchestrator 내에 구현

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `Domain/Models/TemplateWorkoutConfig.swift` | **Create** | 템플릿 워크아웃 설정 struct |
| `Presentation/Exercise/TemplateWorkoutViewModel.swift` | **Create** | 순차 진행 orchestrator VM |
| `Presentation/Exercise/TemplateWorkoutView.swift` | **Create** | 순차 진행 orchestrator View |
| `Presentation/Exercise/ExerciseView.swift` | **Modify** | `startFromTemplate()` 수정: 템플릿 전체를 순차 플로우로 전달 |
| `DUNETests/TemplateWorkoutViewModelTests.swift` | **Create** | VM 유닛 테스트 |
| `DUNE/project.yml` | **Modify** | 새 파일 등록 (xcodegen) |

## Implementation Steps

### Step 1: TemplateWorkoutConfig 생성

`Domain/Models/TemplateWorkoutConfig.swift` — 템플릿 기반 워크아웃 설정.

```swift
struct TemplateWorkoutConfig: Sendable, Identifiable, Hashable {
    let id = UUID()
    let templateName: String
    let exercises: [ExerciseDefinition]
    let templateEntries: [TemplateEntry]  // 디폴트 값 참조용

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
```

### Step 2: TemplateWorkoutViewModel 생성

`Presentation/Exercise/TemplateWorkoutViewModel.swift` — 순차 진행 orchestrator.

핵심 구조:
```swift
@Observable @MainActor
final class TemplateWorkoutViewModel {
    let config: TemplateWorkoutConfig
    private(set) var exerciseViewModels: [WorkoutSessionViewModel]
    private(set) var currentExerciseIndex: Int = 0
    private(set) var exerciseStatuses: [ExerciseStatus]  // .pending, .inProgress, .completed, .skipped
    let sessionStartTime: Date = Date()
    var isSaving = false
    var validationError: String?
}
```

주요 기능:
- `advanceToNext()`: 다음 운동으로 전환
- `skipCurrent()`: 현재 운동 스킵
- `goToExercise(at:)`: 특정 운동으로 점프
- `createRecordForCurrent(weightUnit:) -> ExerciseRecord?`: 현재 운동 레코드 생성
- `loadPreviousSets(from:)`: 이전 세션 데이터 로드
- TemplateEntry 디폴트로 초기 세트 프리필

### Step 3: TemplateWorkoutView 생성

`Presentation/Exercise/TemplateWorkoutView.swift` — orchestrator View.

레이아웃:
```
┌─────────────────────────────────┐
│ [Exercise Progress Header]      │  ← 탭으로 점프/스킵
│  ● Bench Press  ○ OHP  ○ Raise  │
├─────────────────────────────────┤
│                                 │
│  [Current Exercise Session]     │  ← WorkoutSessionView 패턴 재활용
│  - Set input (weight/reps)      │
│  - Complete Set → Rest Timer    │
│  - Add Set / Remove Set         │
│                                 │
├─────────────────────────────────┤
│ [Complete Exercise] button      │  ← 저장 → 다음 운동으로
└─────────────────────────────────┘
```

주요 특징:
- 각 운동 완료 시 즉시 `modelContext.insert(record)` — 크래시 방어
- 운동 간 전환: 다음 운동 정보 + "Start" 버튼
- 전체 완료 시 `WorkoutCompletionSheet` 표시 (전체 요약)
- 세트 간 휴식 타이머는 기존 패턴 유지
- 운동 헤더에서 탭으로 점프 가능

### Step 4: ExerciseView 수정

`startFromTemplate()` 수정:
- 운동 1개: 기존 단일 운동 플로우 (selectedExercise)
- 운동 2개+: `TemplateWorkoutConfig` 생성 → `templateWorkoutConfig` @State 설정 → `.navigationDestination(item:)` 으로 push

```swift
@State private var templateWorkoutConfig: TemplateWorkoutConfig?

private func startFromTemplate(_ template: WorkoutTemplate) {
    let definitions = resolveExercises(from: template)
    guard !definitions.isEmpty else { return }

    if definitions.count == 1 {
        selectedExercise = definitions[0]  // 기존 단일 플로우
    } else {
        templateWorkoutConfig = TemplateWorkoutConfig(
            templateName: template.name,
            exercises: definitions,
            templateEntries: template.exerciseEntries
        )
    }
}
```

### Step 5: 유닛 테스트

`DUNETests/TemplateWorkoutViewModelTests.swift`:
- 초기화 테스트 (exerciseVMs 개수, 상태)
- 순차 진행 테스트 (advance, skip, goTo)
- 레코드 생성 테스트 (validation, 빈 세트)
- TemplateEntry 디폴트 프리필 테스트
- 엣지 케이스 (전부 스킵, 단일 운동)

### Step 6: 빌드 검증

`scripts/build-ios.sh` 실행

## Localization

새 UI 문자열:
- `"Complete Exercise"` — 운동 완료 버튼
- `"Skip Exercise"` — 스킵 버튼
- `"Next Exercise"` — 전환 화면
- `"All Exercises Complete"` — 전체 완료
- `"Complete at least one exercise"` — validation 에러
- `"Exercise %lld of %lld"` — 진행 표시

모든 문자열은 `String(localized:)` 또는 SwiftUI `Text()` 자동 LocalizedStringKey로 처리.
iOS `Localizable.xcstrings`에 en/ko/ja 3개 언어 등록.

## Risks

1. **WorkoutSessionView 코드 중복**: 세트 입력 UI를 새 View에 재구현해야 함. `SetRowView`, stepper field 등 기존 컴포넌트는 재활용.
2. **Draft 복구**: 템플릿 워크아웃 진행 중 앱 종료 시 복구 — MVP에서는 각 운동 즉시 저장으로 대부분 커버. 진행 중인 운동의 draft는 기존 `WorkoutSessionDraft` 패턴 확장.
