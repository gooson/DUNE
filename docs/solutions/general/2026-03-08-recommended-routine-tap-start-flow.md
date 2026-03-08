---
tags: [swiftui, activity, workout-recommendation, quick-start, ui-test]
category: general
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Activity/Components/SuggestedWorkoutSection.swift
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Exercise/TemplateExerciseResolver.swift
  - DUNE/Presentation/Activity/ActivityViewModel.swift
  - DUNEUITests/Full/ActivityExerciseRegressionTests.swift
related_solutions:
  - docs/solutions/general/2026-03-08-orphaned-feature-wiring-audit.md
  - docs/solutions/testing/2026-03-08-e2e-phase3-activity-exercise-regression-hardening.md
---

# Solution: Recommended Routine Tap Opens The Correct Start Flow

## Problem

Activity screen의 추천 루틴 카드는 화면에 보이지만 눌러도 아무 반응이 없었다.

### Symptoms

- `추천 루틴` 카드가 탭 가능해 보이지만 운동 시작 화면으로 이어지지 않았다.
- UI 테스트에서는 초기에는 카드 자체를 찾지 못했고, 시드 보강 후에는 탭은 되지만 시작 화면 기대값이 맞지 않아 실패했다.

### Root Cause

- 추천 루틴 카드는 `SuggestedWorkoutSection`에서 단순 뷰로만 렌더링되고 있었고 탭 액션이 전혀 연결되지 않았다.
- 추천 루틴은 `WorkoutTemplateRecommendation`만 가지고 있어 실제 시작 플로우에 필요한 `ExerciseDefinition` 또는 `TemplateWorkoutConfig`로 해석하는 브리지 로직이 없었다.
- UI 테스트는 단일 추천 루틴이 `Walking`일 때 열리는 유산소 시작 시트 대신 근력 시작 시트만 기대하고 있었다.

## Solution

추천 루틴 카드에 명시적 탭 액션을 연결하고, 추천 데이터를 실제 시작 플로우 입력으로 해석하는 resolver를 추가했다. UI 테스트는 결정론적 추천 카드 시드를 사용하도록 만들고, 단일 추천 루틴이 유산소/근력 어느 쪽이든 올바른 시작 플로우를 성공으로 판단하도록 정리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/Components/SuggestedWorkoutSection.swift` | 추천 루틴 카드를 `Button`으로 감싸고 접근성 ID 추가 | 카드 탭이 실제 액션으로 이어지도록 연결 |
| `DUNE/Presentation/Activity/ActivityView.swift` | `startRecommendation(_:)` 추가 | 단일 운동은 `selectedExercise`, 복합 루틴은 `templateConfig`로 분기 |
| `DUNE/Presentation/Exercise/TemplateExerciseResolver.swift` | 추천 라벨/활동 타입을 `ExerciseDefinition` 배열로 해석하는 로직 추가 | 추천 데이터를 시작 플로우에서 사용할 실제 운동 정의로 변환 |
| `DUNE/Presentation/Activity/ActivityViewModel.swift` | UI 테스트용 추천 루틴 mock 주입 | 추천 카드 노출을 테스트에서 결정론적으로 보장 |
| `DUNE/App/TestDataSeeder.swift` | 최근 운동/추천 루틴 mock 추가 | UI 테스트에서 카드 렌더링과 탭 검증을 안정화 |
| `DUNETests/TemplateExerciseResolverTests.swift` | canonical label 기반 resolver 단위 테스트 추가 | 라벨 기반 해석 회귀 방지 |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | 추천 루틴 탭 후 시작 플로우 확인 테스트 추가 | 사용자 이슈를 UI 레벨에서 재현/검증 |

### Key Code

```swift
private func startRecommendation(_ recommendation: WorkoutTemplateRecommendation) {
    let exercises = TemplateExerciseResolver.resolveExercises(
        from: recommendation,
        library: library
    )
    guard !exercises.isEmpty else { return }

    if exercises.count == 1 {
        selectedExercise = exercises[0]
        return
    }

    templateConfig = TemplateWorkoutConfig(
        templateName: recommendation.title,
        exercises: exercises,
        templateEntries: exercises.map { TemplateExerciseResolver.defaultEntry(for: $0) }
    )
}
```

## Prevention

추천 전용 모델이 UI에 보일 때는 반드시 실제 navigation/presentation 입력 타입으로 변환되는 브리지 로직이 있어야 한다. 카드가 보이는 것만으로 기능 완료로 간주하지 말고, 탭 후 도착 화면까지 UI 테스트로 확인해야 한다.

### Checklist Addition

- [ ] 카드형 추천 UI를 추가할 때 표시만 연결된 orphan state가 아닌지 확인한다.
- [ ] 추천 결과가 단일 근력, 단일 유산소, 복합 루틴 각각 어떤 시작 플로우로 이어지는지 테스트로 고정한다.

### Rule Addition (if applicable)

현재는 별도 규칙 추가보다 Activity/Exercise 회귀 테스트 유지로 충분하다.

## Lessons Learned

- 추천/요약 모델은 화면에 표시되는 시점과 실행되는 시점의 데이터 형태가 다르므로 중간 해석 계층이 필요하다.
- UI 테스트는 카드 존재 여부만 확인하면 부족하고, 도착 화면이 도메인에 따라 달라질 수 있음을 기대값에 반영해야 한다.
