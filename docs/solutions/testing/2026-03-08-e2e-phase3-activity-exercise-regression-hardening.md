---
tags: [ui-test, e2e, activity, exercise, accessibility-identifier, swiftui, localization-safe, seeded-fixture]
category: testing
date: 2026-03-08
severity: important
related_files:
  - DUNE/App/TestDataSeeder.swift
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Activity/Components/ExerciseListSection.swift
  - DUNE/Presentation/Exercise/Components/ExercisePickerView.swift
  - DUNE/Presentation/Exercise/Components/WorkoutCompletionSheet.swift
  - DUNE/Presentation/Exercise/CardioSession/CardioStartSheet.swift
  - DUNE/Presentation/Exercise/CardioSession/CardioSessionView.swift
  - DUNE/Presentation/Exercise/ExerciseStartView.swift
  - DUNE/Presentation/Exercise/ExerciseView.swift
  - DUNE/Presentation/Exercise/WorkoutSessionView.swift
  - DUNEUITests/Full/ActivityExerciseRegressionTests.swift
  - DUNEUITests/Helpers/UITestBaseCase.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
  - Shared/Resources/Localizable.xcstrings
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
  - docs/solutions/testing/2026-03-08-e2e-phase2-today-settings-regression.md
  - docs/solutions/testing/2026-03-03-watch-workout-start-axid-selector-hardening.md
  - docs/solutions/testing/ui-test-infrastructure-design.md
---

# Solution: E2E Phase 3 Activity/Exercise 회귀 하드닝

## Problem

Activity/Exercise full regression을 실제 사용자 경로로 확장하는 과정에서, 새 회귀 테스트가 red 상태였고 일부 플로우는 debug direct-entry 우회에 다시 기대고 있었다.
특히 Quick Start -> Exercise Start -> Workout/Cardio session 흐름은 SwiftUI 접근성 식별자 배치와 sheet dismissal 타이밍 때문에 결정적으로 재현되지 않았다.

### Symptoms

- `testManualWorkoutSessionSavesAndDismissesCompletionSheet`가 `workout-session-complete-set`을 찾지 못하고 red였다.
- `Recent Workouts -> See All`, `Exercise Start`, `Workout Completion`, `Cardio Start`, `Cardio Session` 화면에서 child CTA identifier가 사라지거나 root screen identifier로 덮였다.
- picker 후속 진입이 fixed sleep에 기대고 있어 flaky 가능성이 남아 있었다.
- cardio 종료 확인 버튼이 localized label에 묶여 locale-safe하지 않았다.
- seeded notification/cardio subtitle 문자열 일부가 String Catalog에 없어 ko/ja에서 English fallback이 노출됐다.

### Root Cause

이번 phase의 핵심 문제는 두 가지였다.

1. SwiftUI root container에 screen-level `accessibilityIdentifier`를 부여하면 자식 button identifier/hit-testing이 함께 먹히는 surface가 여러 곳에 존재했다.
2. picker/sheet dismiss 이후 후속 navigation을 임의 delay로 연결하거나 localized label로만 찾는 테스트는 full regression에서 쉽게 불안정해졌다.

## Solution

debug direct-entry를 제거하고 real user path를 다시 기준으로 삼았다.
동시에 screen AXID는 상호작용 버튼을 덮지 않는 최소 비인터랙티브 anchor로 옮기고, picker/cardio confirmation 같은 locale-sensitive action에는 stable AXID를 추가했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/ActivityView.swift` | debug direct-entry 제거, picker dismiss 완료를 `Task.yield()` 기반 handoff로 변경 | Quick Start 후속 화면 진입을 sleep 없이 안정화하기 위해 |
| `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift` | `dismissPicker(_:)` 추가, quick-start/detail/template action을 dismiss 이후 실행하도록 조정 | picker dismiss race를 줄이고 실제 사용자 경로를 유지하기 위해 |
| `DUNE/Presentation/Exercise/ExerciseView.swift` | exercise row stable AXID 추가, picker -> start handoff 정리 | `Recent Workouts -> See All -> History` 경로를 label 대신 deterministic selector로 검증하기 위해 |
| `DUNE/Presentation/Exercise/ExerciseStartView.swift` | root screen AXID 범위 축소 | start button identifier가 root container에 가려지지 않게 하기 위해 |
| `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | `workout-session-screen`을 root 밖 안정 anchor로 이동 | `workout-session-complete-set` CTA를 XCUI가 직접 찾게 하기 위해 |
| `DUNE/Presentation/Exercise/Components/WorkoutCompletionSheet.swift` | `workout-completion-sheet` 범위를 헤더로 이동 | completion dismiss CTA identifier 충돌을 막기 위해 |
| `DUNE/Presentation/Exercise/CardioSession/CardioStartSheet.swift` | `cardio-start-screen` 범위를 헤더로 이동 | `cardio-start-indoor/outdoor` 버튼 id가 노출되게 하기 위해 |
| `DUNE/Presentation/Exercise/CardioSession/CardioSessionView.swift` | `cardio-session-screen` 범위 조정 + `cardio-session-confirm-end` 추가 | cardio 종료/요약 경로를 locale-safe selector로 검증하기 위해 |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | manual/cardio/recent routes를 real flow 기반으로 재작성, secondary route를 짧은 테스트로 분리 | direct-entry 제거 후에도 regression runtime과 안정성을 같이 관리하기 위해 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | phase 3 AXID constants 확장 | 문자열 literal 의존을 줄이고 새 selector를 중앙 관리하기 위해 |
| `DUNE/App/TestDataSeeder.swift` | Activity/Exercise seeded fixture와 notification copy를 `String(localized:)`로 정리 | seeded scenario와 locale contract를 맞추기 위해 |
| `Shared/Resources/Localizable.xcstrings` | cardio subtitle / notification route / seeded insight copy 번역 추가 | ko/ja fallback leak를 제거하기 위해 |
| `DUNEUITests/*` | `@preconcurrency import XCTest` 적용 | XCTest import 경계의 actor warning 노이즈를 줄이기 위해 |

### Key Code

```swift
private func scheduleQuickStartAction(_ action: @escaping @MainActor () -> Void) {
    Task { @MainActor in
        while showingExercisePicker {
            await Task.yield()
        }
        await Task.yield()
        action()
    }
}

private func dismissPicker(_ action: @escaping @MainActor () -> Void) {
    dismiss()
    Task { @MainActor in
        await Task.yield()
        action()
    }
}
```

```swift
private var activityHeader: some View {
    VStack(spacing: DS.Spacing.sm) {
        Image(systemName: activityType.iconName)
        Text(exercise.localizedName)
    }
    .accessibilityIdentifier("cardio-start-screen")
}

Button(String(localized: "End Workout"), role: .destructive) {
    Task {
        await viewModel.end()
        showSummary = true
    }
}
.accessibilityIdentifier("cardio-session-confirm-end")
```

## Prevention

Activity/Exercise처럼 sheet, picker, full-screen session이 연달아 이어지는 흐름은 "dismiss contract", "screen AX contract", "locale-safe action contract"를 함께 설계해야 한다.
특히 SwiftUI root container에 screen AXID를 붙였을 때 child CTA가 가려지는 문제는 이번 phase에서 여러 번 반복됐으므로, 앞으로는 screen marker를 비인터랙티브 anchor에만 둔다.

### Checklist Addition

- [ ] picker/sheet dismiss 뒤 후속 navigation은 fixed sleep 대신 dismissal-driven `Task.yield()` 또는 상태 기반 handoff를 쓰는가?
- [ ] screen-level AXID가 root `VStack`/sheet container에 붙어 child button identifier를 가리지 않는가?
- [ ] locale-dependent confirmation/action은 테스트에서 label 대신 AXID로 접근 가능한가?
- [ ] `Recent Workouts -> See All` 같은 cross-screen regression은 real user path를 타면서도 deterministic selector를 제공하는가?
- [ ] seeded fixture에 추가한 새 copy가 `Localizable.xcstrings`에 ko/ja 번역까지 함께 들어갔는가?

### Rule Addition (if applicable)

새 rules 파일 추가는 보류한다.
다만 `docs/corrections-active.md`에 "screen-level AXID는 상호작용 root가 아닌 안정 anchor에만 부여" 항목을 추가해 재발을 막는다.

## Lessons Learned

이번 phase에서 flake의 핵심은 테스트 코드보다 SwiftUI surface 설계였다.
root container AXID 하나가 여러 child selector를 동시에 무효화할 수 있었고, localized action label은 회귀 테스트에서 곧바로 취약점이 됐다.
또한 긴 secondary route regression은 한 테스트에 과도하게 묶기보다, 사용자 경로 단위로 잘게 분리하는 편이 실행 시간과 triage 모두에서 유리했다.

기능 경로 자체는 targeted rerun으로 manual session, recent workouts history, secondary details, exercise mix, cardio summary까지 확인했다.
다만 마지막 import-only warning 정리 후 full class 재실행은 `xcodebuild`가 `signal kill`로 끝났으므로, merge 직전에는 full `ActivityExerciseRegressionTests` class를 한 번 더 묶어 확인하는 것이 안전하다.
