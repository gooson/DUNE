---
tags: [foundation-models, workout-template, cardio, tool-calling, input-type, template-normalization]
category: architecture
date: 2026-03-09
severity: important
related_files:
  - DUNE/Data/Services/AIWorkoutTemplateGenerator.swift
  - DUNE/Presentation/Exercise/Components/CreateTemplateView.swift
  - DUNE/Presentation/Exercise/TemplateExerciseResolver.swift
  - DUNETests/AIWorkoutTemplateGeneratorTests.swift
  - DUNETests/TemplateExerciseResolverTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-09-foundation-models-integration-pattern.md
---

# Solution: Natural-language workout template generation

## Problem

`main`에 합쳐진 자연어 운동 템플릿 플로우는 기존 `CreateTemplateView` 구조 안에서 strength/bodyweight 템플릿을 안정적으로 생성하는 방향으로 정리돼 있었다. 여기에 cardio 요청까지 받아야 했는데, 단순히 "템플릿처럼 보이는 운동" 범위를 넓히면 실제 저장 계약이 없는 flexibility/HIIT input type까지 같이 열릴 위험이 있었다.

### Symptoms

- "30분 러닝 템플릿 만들어줘" 같은 cardio 요청이 기존 생성 규칙에서는 제외되거나 strength 기본값으로 저장될 수 있었다.
- `TemplateExerciseProfile`를 그대로 "template-capable" 의미로 사용하면 `.durationIntensity`, `.roundsBased` 운동도 생성 후보에 들어와 malformed template가 만들어질 수 있었다.
- cardio 엔트리가 생성기, 폼 매핑, 저장 단계마다 다른 기본값을 쓰면 `sets/reps`, weight, rest가 서로 어긋날 수 있었다.
- HealthKit workout context를 화면에서 ad-hoc으로 다시 가공하면 shared snapshot 규칙과 drift가 생길 수 있었다.

### Root Cause

근본 원인은 네 가지였다.

1. 템플릿 저장 가능 여부는 UI용 `TemplateExerciseProfile`이 아니라 persisted `ExerciseInputType` 계약으로 판단해야 했다.
2. cardio는 지원하되 현재 템플릿 스키마에 없는 `.durationIntensity`, `.roundsBased`는 계속 막아야 했다.
3. cardio normalization(`1 set / 1 rep`, no weight/rest)이 생성기와 UI 저장 경로 전체에 일관되게 반영되지 않으면 값이 쉽게 틀어진다.
4. HealthKit recent context를 shared snapshot helper 대신 화면에서 직접 조립하면 추천/생성 입력 정책이 분산된다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Services/AIWorkoutTemplateGenerator.swift` | prompt/tool 설명에 cardio 허용을 추가하고, explicit `ExerciseInputType` allowlist + cardio `1/1` normalization을 도입 | cardio 지원을 추가하면서 unsupported template type 유입을 막기 위해 |
| `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift` | generated slot -> `TemplateEntry` 변환과 save clamp에서 cardio를 `1/1`, `weight/rest nil`로 통일하고, HealthKit context를 `SpatialTrainingAnalyzer.snapshot(from:)`로 통합 | 생성 결과와 저장 결과가 같은 계약을 따르도록 하기 위해 |
| `DUNE/Presentation/Exercise/TemplateExerciseResolver.swift` | cardio default entry를 `1 set / 1 rep`로 변경 | 수동 추가/AI 생성 모두 같은 템플릿 기본값을 쓰게 하기 위해 |
| `DUNETests/AIWorkoutTemplateGeneratorTests.swift` | cardio 유지/정규화 테스트와 unsupported non-template type rejection 회귀 테스트 추가 | future change가 다시 HIIT/flexibility를 열어 버리는 회귀를 막기 위해 |
| `DUNETests/TemplateExerciseResolverTests.swift` | cardio default entry가 `1/1`인지 고정 | UI default drift를 방지하기 위해 |
| `DUNETests/AICoachingMessageServiceTests.swift` | 현재 `ConditionScore` API에 맞게 사전 컴파일 blocker 제거 | 테스트 타깃 검증을 막는 unrelated compile blocker를 함께 정리하기 위해 |

### Key Code

```swift
guard Self.isTemplateSupported(exercise) else {
    return nil
}

switch exercise.inputType {
case .durationDistance:
    return GeneratedWorkoutExerciseSlot(
        exerciseDefinitionID: exercise.id,
        exerciseName: exercise.localizedName,
        sets: 1,
        reps: 1
    )
case .setsRepsWeight, .setsReps:
    return GeneratedWorkoutExerciseSlot(
        exerciseDefinitionID: exercise.id,
        exerciseName: exercise.localizedName,
        sets: slot.sets,
        reps: slot.reps
    )
case .durationIntensity, .roundsBased:
    return nil
}
```

```swift
static func isTemplateSupported(_ exercise: ExerciseDefinition) -> Bool {
    switch exercise.inputType {
    case .setsRepsWeight, .setsReps, .durationDistance:
        true
    case .durationIntensity, .roundsBased:
        false
    }
}
```

```swift
switch TemplateExerciseProfile(exercise: definition) {
case .cardio:
    entry.defaultSets = 1
    entry.defaultReps = 1
    entry.defaultWeightKg = nil
    entry.restDuration = nil
case .strengthLike, .unresolved:
    entry.defaultSets = slot.sets
    entry.defaultReps = slot.reps
}
```

핵심은 "cardio support"를 prompt 문구 하나로 끝내지 않고, generator filter, generated slot normalization, default entry, save clamp, regression tests까지 같은 계약으로 묶은 점이다.

## Prevention

### Checklist Addition

- [ ] template-capable 판정에 `TemplateExerciseProfile`를 재사용하지 말고 저장 스키마 기준 `ExerciseInputType` allowlist를 먼저 정의한다.
- [ ] 새 input type을 자연어 템플릿 플로우에 추가할 때는 generator filter, entry default, save clamp, tests를 같은 배치에서 함께 수정한다.
- [ ] HealthKit workout context는 화면별 ad-hoc mapping 대신 shared snapshot helper를 우선 사용한다.
- [ ] cardio/time-based 엔트리는 sets/reps normalization과 weight/rest nil 정책이 저장 경로 끝까지 유지되는지 확인한다.

### Rule Addition (if applicable)

새 rule 파일은 추가하지 않았다. 대신 `docs/corrections-active.md`에 "template-capable 판정은 `TemplateExerciseProfile` 대용 금지" 교정을 추가해 같은 실수를 다시 막는다.

## Lessons Learned

- 자연어 생성에서 "지원 운동 종류를 넓힌다"는 작업은 prompt 품질 문제가 아니라 persistence contract 문제다.
- presentation profile과 저장 가능 input type은 비슷해 보여도 다른 축이므로, 둘을 같은 의미로 재사용하면 회귀가 생긴다.
- mainline 구조에 capability gap을 붙일 때는 generator만 수정하지 말고 UI default와 save path까지 같은 규칙으로 맞춰야 drift가 없다.
