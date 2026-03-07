---
tags: [template, cardio, exercise, watch, localization, preview]
category: general
date: 2026-03-07
severity: important
related_files:
  - DUNE/Data/Persistence/Models/WorkoutTemplate.swift
  - DUNE/Presentation/Exercise/TemplateExerciseResolver.swift
  - DUNE/Presentation/Exercise/Components/CreateTemplateView.swift
  - DUNE/Presentation/Exercise/ExerciseView.swift
  - DUNE/Presentation/Exercise/ExerciseStartView.swift
  - DUNE/Presentation/Exercise/WorkoutSessionView.swift
  - DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift
  - DUNEWatch/Helpers/WatchExerciseHelpers.swift
  - DUNEWatch/WatchConnectivityManager.swift
  - DUNEWatch/Views/Components/CarouselRoutineCardView.swift
  - DUNEWatch/Views/Components/ExerciseCardView.swift
  - DUNEWatch/Views/Components/TemplateCardView.swift
  - DUNEWatch/Views/QuickStartAllExercisesView.swift
  - DUNEWatch/Views/WorkoutPreviewView.swift
  - DUNE/Data/WatchConnectivity/WatchSessionManager.swift
  - DUNE/Domain/Models/WorkoutActivityType.swift
  - DUNETests/CardioWorkoutModeTests.swift
  - DUNETests/DomainModelCoverageTests.swift
  - DUNETests/TemplateExerciseResolverTests.swift
  - DUNETests/TemplateWorkoutViewModelTests.swift
  - DUNETests/WorkoutSessionViewModelTests.swift
  - DUNEWatchTests/WatchExerciseHelpersTests.swift
  - Shared/Resources/Localizable.xcstrings
  - DUNEWatch/Resources/Localizable.xcstrings
related_solutions: []
---

# Solution: Cardio Template Profile Resolution

## Problem

유산소 운동 템플릿이 저장, 시작, 워치 프리뷰 경로에서 근력 운동처럼 표시되거나 기본값이 새는 문제가 있었다.

### Symptoms

- 템플릿 생성 시 `Stair Climber` 같은 유산소 운동이 `세트/횟수/체중/휴식` 편집 UI로 노출됐다.
- 단일 운동 템플릿 시작 시 템플릿 entry 정보가 세션 진입 화면까지 전달되지 않아 기본값이 일관되게 적용되지 않았다.
- 워치 quick start, exercise card, routine card, template preview 일부가 `sets × reps` 기반 요약을 그대로 노출했다.
- 커스텀 유산소 운동을 템플릿에서 다시 해석할 때 `setsRepsWeight` fallback으로 복원돼 카드/세션이 잘못 분기됐다.

### Root Cause

- `TemplateEntry` 자체에는 운동 타입 정보가 없는데, 여러 화면이 entry 숫자 필드만 보고 근력 UI를 직접 렌더링했다.
- 템플릿 entry를 `ExerciseDefinition`으로 되돌릴 때 커스텀 운동 메타데이터(`inputType`, `cardioSecondaryUnit`)를 보존하지 못했다.
- 워치 쪽 요약 헬퍼와 iOS 템플릿 화면이 서로 다른 분기 기준을 사용해 cardio/strength 판정이 drift 됐다.
- watch preview/cardio start는 `exerciseLibrary` lookup에만 의존해 커스텀 템플릿 운동의 타입 정보를 끝까지 복원하지 못했다.
- cardio summary copy가 secondary unit과 무관하게 `"Duration + Distance"`로 고정돼 stair/jump-rope/time-only cardio에서도 의미가 틀어졌다.

## Solution

템플릿 entry를 직접 해석하는 공통 profile/resolver를 만들고, 저장/시작/세션/워치 프리뷰가 모두 그 profile을 기준으로 분기하도록 통일했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Persistence/Models/WorkoutTemplate.swift` | `TemplateEntry`에 `inputTypeRaw`/`cardioSecondaryUnitRaw` 저장, `TemplateExerciseProfile` summary를 unit-aware로 정리 | custom cardio도 library 없이 cardio로 복원하고, summary copy가 실제 metric과 맞도록 통일 |
| `DUNE/Presentation/Exercise/TemplateExerciseResolver.swift` | built-in/custom 운동 복원, persisted metadata fallback, cardio-safe default entry 생성 | 커스텀 유산소 운동 메타데이터 손실 방지 |
| `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift` | cardio entry는 strength editor를 숨기고 요약만 표시, 저장 시 strength-only 필드 정규화 | 템플릿 생성 화면에서 잘못된 편집 UI 제거 |
| `DUNE/Presentation/Exercise/ExerciseView.swift` | 템플릿 시작 시 resolved definition + template entry를 함께 전달 | 단일 운동 템플릿에서도 entry 컨텍스트 유지 |
| `DUNE/Presentation/Exercise/ExerciseStartView.swift` | 시작 시트 detail row도 profile 기반으로 분기 | 시작 화면에서 cardio가 다시 sets UI로 보이는 누락 제거 |
| `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | template entry를 세션으로 전달 | 템플릿 기본값을 세션 레벨에서 적용하기 위함 |
| `DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift` | cardio 템플릿에는 reps/weight/rest prefill을 적용하지 않음 | strength default leakage 차단 |
| `DUNE/Presentation/Exercise/TemplateWorkoutContainerView.swift` | 각 운동 세션에 current template entry 전달 | 다중 운동 템플릿에서도 동일 규칙 적용 |
| `DUNE/Presentation/Exercise/TemplateWorkoutViewModel.swift` | legacy sequential view model도 cardio prefill skip | 오래된 경로에서도 동일 회귀 방지 |
| `DUNEWatch/Helpers/WatchExerciseHelpers.swift` | cardio-aware subtitle/meta helper가 entry metadata fallback을 사용하도록 변경 | watch library에 없는 custom cardio도 summary/meta가 strength로 바뀌지 않도록 고정 |
| `DUNEWatch/WatchConnectivityManager.swift` | exercise library ID/canonical cache 추가 | watch 카드/프리뷰가 매 렌더마다 library 검색용 dictionary를 다시 만들지 않도록 정리 |
| `DUNEWatch/Views/Components/ExerciseCardView.swift` | cardio-aware subtitle 사용 | 단일 운동 카드 오표기 제거 |
| `DUNEWatch/Views/QuickStartAllExercisesView.swift` | cardio-aware subtitle 사용 | quick start 리스트 오표기 제거 |
| `DUNEWatch/Views/Components/CarouselRoutineCardView.swift` | connectivity cache를 써서 cardio-aware meta 계산 | cardio 템플릿에 잘못된 `sets/~min` 추정 제거 + per-render 비용 감소 |
| `DUNEWatch/Views/Components/TemplateCardView.swift` | 동일 cache/meta helper 사용 | 미사용/향후 재사용 카드도 동일 규칙 유지 |
| `DUNEWatch/Views/WorkoutPreviewView.swift` | watch library lookup 후 entry metadata fallback으로 cardio start/type resolution 수행 | custom cardio template이 strength preview나 `traditionalStrengthTraining`으로 시작되는 회귀 제거 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | watch sync payload 생성 시 built-in/custom exercise metadata를 template entry에 보강 | 기존 저장 템플릿도 재저장 없이 watch에서 cardio로 복원되도록 보완 |
| `DUNE/Domain/Models/WorkoutActivityType.swift` | legacy `"duration"` raw alias를 cardio input guard에 허용 | 이전 rawValue를 가진 persisted metadata도 cardio 분기로 수용 |
| `Shared/Resources/Localizable.xcstrings` / `DUNEWatch/Resources/Localizable.xcstrings` | cardio secondary unit 라벨 번역 추가 | `Duration`, `Distance`, `Floors`, `Count`, `Time only` 조합이 locale leak 없이 출력되도록 유지 |
| `DUNETests/TemplateExerciseResolverTests.swift` | custom cardio resolution/default entry/persisted metadata fallback 테스트 추가 | resolver 회귀 방지 |
| `DUNETests/WorkoutSessionViewModelTests.swift` | cardio template default leakage 차단 테스트 추가 | 세션 prefill 회귀 방지 |
| `DUNETests/TemplateWorkoutViewModelTests.swift` | legacy template view model cardio skip 테스트 추가 | 오래된 경로 회귀 방지 |
| `DUNETests/CardioWorkoutModeTests.swift` | legacy cardio raw alias guard 테스트 추가 | cardio mode resolver 회귀 방지 |
| `DUNETests/DomainModelCoverageTests.swift` | template entry metadata round-trip 보강 | watch payload/shared model Codable regressions 방지 |
| `DUNEWatchTests/WatchExerciseHelpersTests.swift` | cardio subtitle/meta helper와 entry metadata fallback 테스트 추가 | 워치 요약 regressions 방지 |

### Key Code

```swift
var hydratedEntry = entry

if let customExercise = customExercisesByID[entry.exerciseDefinitionID] {
    hydratedEntry.applyExerciseMetadata(from: customExercise.toDefinition())
}

let profile = TemplateExerciseProfile(
    inputTypeRaw: connectivity.exerciseInfo(for: entry.exerciseDefinitionID)?.inputType ?? hydratedEntry.inputTypeRaw,
    cardioSecondaryUnitRaw: connectivity.exerciseInfo(for: entry.exerciseDefinitionID)?.cardioSecondaryUnit ?? hydratedEntry.cardioSecondaryUnitRaw
)

guard profile.showsStrengthDefaultsEditor else {
    return "Duration · Floors"
}
```

## Prevention

템플릿 UI는 `TemplateEntry` 숫자 필드만 보고 strength/cardio를 추론하지 말고, 항상 실제 운동 메타데이터에서 profile을 먼저 복원해야 한다.

### Checklist Addition

- [ ] 템플릿/프리뷰/카드가 `defaultSets/defaultReps/defaultWeightKg`만으로 UI 타입을 결정하지 않는지 확인
- [ ] 커스텀 운동을 템플릿에서 다시 해석할 때 `inputType`과 `cardioSecondaryUnit`이 보존되는지 확인
- [ ] shared summary copy가 새 localization key를 추가하면 iOS/watch string catalog를 함께 갱신했는지 확인
- [ ] 워치 routine meta가 strength-only 추정(`sets`, `~min`)을 cardio entry에 재사용하지 않는지 확인
- [ ] watch가 template entry를 cardio로 시작해야 하는 경로에서 `exerciseLibrary`만으로 타입 복원을 끝내지 않는지 확인
- [ ] cardio summary copy가 실제 metric 조합(`Duration`, `Duration · Floors`, `Duration · Count`)과 맞는지 확인

### Rule Addition (if applicable)

현재는 solution doc으로 충분하다. 같은 패턴이 반복되면 `watch-ios-parity` 또는 템플릿 관련 rule로 승격한다.

## Lessons Learned

템플릿 버그의 핵심은 저장 데이터 자체보다 "entry를 어떻게 다시 해석하느냐"에 있었다.
운동 타입 메타데이터를 공통 resolver/profile로 한 번만 판단하게 만들면, 생성 화면과 세션 화면뿐 아니라 watch preview/card 같은 파생 UI까지 함께 안정화된다.
watch에서 커스텀 템플릿을 정확히 시작하려면 `exerciseLibrary`만 바라보지 말고, 템플릿 자체나 sync payload에 타입 메타데이터를 함께 실어야 한다.
