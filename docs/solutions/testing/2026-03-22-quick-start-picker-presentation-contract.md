---
tags: [ui-test, quick-start, picker, sheet, ondismiss, activity, regression]
category: testing
date: 2026-03-22
severity: important
related_files:
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Exercise/Components/ExercisePickerView.swift
  - DUNEUITests/Full/ActivityExercisePickerRegressionTests.swift
  - docs/plans/2026-03-22-nightly-ui-test-template-lane-fix.md
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase3-activity-exercise-regression-hardening.md
  - docs/solutions/testing/2026-03-09-e2e-exercise-picker-surface-contract.md
  - docs/solutions/testing/2026-03-09-ui-test-aut-launch-lifecycle-hardening.md
---

# Solution: Quick Start Picker Presentation Contract

## Problem

GitHub Actions run `23387043762`의 `nightly-ios-ui-tests` job에서 `ActivityExercisePickerRegressionTests`가 quick start picker 후속 화면 진입에서 연쇄 실패했다.
첫 실패는 quick start detail lane이었고, 이후 같은 class와 다음 class들이 launch/terminate timeout으로 오염됐다.

### Symptoms

- `testQuickStartPickerCanRevealAllExercisesAndOpenDetail`가 `exercise-detail-screen`을 기다리다 execution allowance를 초과했다.
- 같은 run에서 재시도된 `testQuickStartPickerShowsHubSectionsAndStartsTemplateLane`도 `exercise-start-screen` 진입에 실패했다.
- 첫 실패 뒤에는 `Failed to terminate ...` 와 `Failed to launch ...`가 이어져 다음 UI test class까지 launch timeout이 전염됐다.

### Root Cause

quick start picker 후속 presentation contract가 두 군데에서 불안정했다.

1. Activity tab은 picker dismissal completion보다 이른 시점에 후속 action을 스케줄링하고 있었다.
   `showingExercisePicker == false` 와 `Task.yield()`만으로는 실제 sheet dismissal completion을 보장하지 못해,
   CI에서 start/template handoff가 드롭될 수 있었다.
2. picker 내부 detail sheet는 list-row tap 직후 같은 run loop turn에서 nested sheet를 올리려 했다.
   이 경로도 CI에서 간헐적으로 presentation을 놓칠 수 있었다.

## Solution

quick start follow-up action의 owner를 Activity sheet의 `onDismiss`로 옮겨 dismissal 완료 이후에만 start/template handoff가 실행되게 바꿨다.
동시에 picker detail sheet도 다음 main-queue turn으로 defer해 nested sheet presentation을 안정화했다.
UI regression test는 toolbar tap과 hub 복귀/상세 버튼 탐색을 기존 helper로 보강해 locale/runtime 차이에도 덜 흔들리게 맞췄다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/ActivityView.swift` | pending quick-start action state + `.sheet(..., onDismiss:)` 도입 | picker dismissal 완료 이후에만 start/template presentation을 실행하기 위해 |
| `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift` | detail button action을 `presentDetailSheet(for:)` helper로 defer | picker list row에서 nested detail sheet가 드롭되는 CI race를 줄이기 위해 |
| `DUNEUITests/Full/ActivityExercisePickerRegressionTests.swift` | toolbar tap을 `waitAndTap`으로 교체하고 hub/detail button 탐색에 scroll helper 추가 | quick start regression 자체의 selector flake를 줄이고 local/CI 재검증을 쉽게 하기 위해 |

### Key Code

```swift
private func startExerciseFromPicker(_ exercise: ExerciseDefinition) {
    pendingQuickStartAction = .exercise(exercise)
    showingExercisePicker = false
}

private func runPendingQuickStartAction() {
    guard let pendingQuickStartAction else { return }
    self.pendingQuickStartAction = nil

    switch pendingQuickStartAction {
    case .exercise(let exercise):
        selectedExercise = exercise
    case .template(let template):
        startFromTemplate(template)
    }
}
```

```swift
.sheet(isPresented: $showingExercisePicker, onDismiss: runPendingQuickStartAction) {
    ExercisePickerView(...)
}
```

```swift
private func presentDetailSheet(for exercise: ExerciseDefinition) {
    DispatchQueue.main.async {
        Task { @MainActor in
            detailExercise = exercise
        }
    }
}
```

## Prevention

quick start처럼 "sheet 안 list tap -> 다른 sheet/full-screen route"가 이어지는 경로는
`Task.yield()` 추측보다 dismissal lifecycle signal(`onDismiss`)을 우선 계약으로 써야 한다.

### Checklist Addition

- [ ] picker dismissal 이후 start/template handoff가 필요하면 `showing == false` polling보다 sheet `onDismiss`를 먼저 검토했는가?
- [ ] picker/list row 액션이 nested sheet를 띄울 때 같은 run loop turn에 state를 바꾸지 않고 defer contract를 사용했는가?
- [ ] UI regression helper는 toolbar CTA를 `Button` 우선 탐색하고, scrollable picker lane은 reachability helper를 재사용하는가?

### Rule Addition (if applicable)

새 rules 파일은 추가하지 않았다.
기존 quick start/picker regression 문서와 active correction의 "button-first tap" 원칙으로 충분히 관리 가능하다.

## Lessons Learned

이번 failure는 기능 코드 자체보다 "presentation timing contract"가 문제였다.
sheet dismiss 이후 follow-up action을 상태 polling으로 추정하면 CI처럼 느린 런타임에서 쉽게 드롭되고,
한 번 드롭된 뒤에는 launch/terminate failure가 연쇄적으로 퍼진다.

또한 quick start regression은 제품 버그와 selector flake가 섞이기 쉬우므로,
제품 코드의 presentation owner를 명확히 정리한 뒤 테스트 helper도 같은 surface에 맞춰 함께 안정화해야 한다.
