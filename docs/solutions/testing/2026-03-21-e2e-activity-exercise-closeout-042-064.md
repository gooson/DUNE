---
tags: [testing, ui-tests, e2e, activity, exercise, closeout, xcodebuild]
category: testing
date: 2026-03-21
severity: important
related_files:
  - DUNEUITests/Full/ActivityExerciseRegressionTests.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
  - DUNE/Presentation/Exercise/TemplateWorkoutContainerView.swift
  - DUNE/Presentation/Exercise/CompoundWorkoutView.swift
  - DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift
  - todos/done/101-done-p2-e2e-phase0-page-backlog-index.md
  - todos/done/107-done-p2-e2e-phase0-completed-surface-index.md
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase3-activity-exercise-regression-hardening.md
  - docs/solutions/testing/2026-03-09-e2e-done-todo-index-consolidation.md
---

# Solution: E2E Activity Exercise Closeout 042-064

## Problem

Activity / Exercise phase 0 backlog `042`~`064`가 오래 남아 있었지만, 실제 앱에는 이미 대부분의 사용자 경로가 regression으로 존재했다.
문제는 surface별 closeout 근거가 문서에 연결되지 않았고, template container / compound live flow / HealthKit detail title edit 같은 일부 경로는 selector와 assertion depth가 부족했다는 점이다.

추가로 targeted UI test 실행 시 `--only-testing DUNEUITests/Full/...` 형식은 Xcode에서 실제 test case 0건으로 끝날 수 있어, false green을 만들 위험이 있었다.

### Symptoms

- phase 0 open backlog가 `DUNE Activity / Exercise` 20건에 고정되어 있었다.
- `055`, `058`, `062`는 dedicated assertion 없이 “대충 커버되는 것 같다” 수준의 근거만 남아 있었다.
- `056 TemplateWorkoutView`는 실제 current route에서 직접 열리지 않는데도 open surface로 남아 있었다.
- UI runner가 `TEST SUCCEEDED`를 출력해도 실제로는 `Executed 0 tests`일 수 있었다.

### Root Cause

surface inventory와 regression implementation 사이의 연결 문서가 약했고, live/session/deep-link 경로에 필요한 AXID contract가 일부 빠져 있었다.
또한 UI test target의 `only-testing` 값은 파일 경로가 아니라 `DUNEUITests/<ClassName>` 형식이어야 하는데, closeout 검증 과정에서 한 번 잘못 지정되었다.

## Solution

existing full regression을 source of truth로 채택하고, 약한 경로만 selector와 assertion을 보강한 뒤 open TODO를 모두 `done`으로 이동했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEUITests/Helpers/UITestHelpers.swift` | template/compound/HealthKit/set-row 관련 AXID 추가 | live/session/deep-link 경로를 locale-safe selector로 고정하기 위해 |
| `DUNE/Presentation/Exercise/Components/ExerciseTransitionView.swift` | transition screen/start AXID 추가 | template handoff branch를 안정적으로 관찰하기 위해 |
| `DUNE/Presentation/Exercise/TemplateWorkoutContainerView.swift` | end-confirmation AXID 추가 | full-screen template dismissal을 안정적으로 검증하기 위해 |
| `DUNE/Presentation/Exercise/Components/SetRowView.swift` | set field/complete AXID 추가 | compound/template live input을 안정적으로 제어하기 위해 |
| `DUNE/Presentation/Exercise/CompoundWorkoutView.swift` | finish button AXID 추가 | compound finish closeout을 dedicated assertion으로 묶기 위해 |
| `DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift` | title edit sheet AXID 추가 | notification deep-link detail 편집을 regression-safe하게 만들기 위해 |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | template direct-session handoff, template container dismissal, compound finish, HealthKit title edit assertion 추가 | `055`, `058`, `062`의 closeout 근거를 강화하고 template handoff branch를 실제 앱 동작에 맞추기 위해 |
| `todos/done/042-064*.md` | open TODO를 done 문서로 전환 | surface별 implementation/lane 근거를 source of truth로 남기기 위해 |
| `todos/done/101-done-p2-e2e-phase0-page-backlog-index.md` | open backlog index 아카이브화 | phase 0 open backlog 0건 상태를 기록하기 위해 |
| `todos/done/107-done-p2-e2e-phase0-completed-surface-index.md` | completed index에 `042`~`064` 추가 | phase 0 74개 surface 완료 상태를 한 문서에 모으기 위해 |

### Key Code

```swift
let transitionStart = app.buttons[AXID.templateWorkoutTransitionStart].firstMatch
let workoutSessionDone = app.buttons[AXID.workoutSessionDone].firstMatch
XCTAssertTrue(
    waitForEither(transitionStart, workoutSessionDone, timeout: 8)
)
if transitionStart.exists {
    transitionStart.tap()
}

XCTAssertTrue(workoutSessionDone.waitForExistence(timeout: 10))

let finishButton = app.buttons[AXID.compoundWorkoutFinish].firstMatch
XCTAssertTrue(waitForEnabled(finishButton, timeout: 5))

let editTitleButton = app.buttons[AXID.healthkitWorkoutEditTitle].firstMatch
editTitleButton.tap()
XCTAssertTrue(app.fillTextInput(AXID.healthkitWorkoutTitleField, with: "Codex Route Title"))
```

## Validation

- `scripts/build-ios.sh`가 통과했고 iOS build가 깨지지 않음을 확인했다.
- 16-test targeted subset을 실행했고 초기 결과는 15/16 pass였다.
- 남은 template failure는 screenshot과 exported UI hierarchy에서 transition screen 없이 `Barbell Squat` workout session으로 직접 진입하는 handoff branch임을 확인했다.
- template assertion을 direct-session landing 허용 형태로 수정한 뒤 `testTemplateListSupportsCreateEditAndTemplateStart` 단일 rerun이 통과했다.
- `testNotificationWorkoutRouteOpensHealthKitDetailAndTitleEditor` targeted rerun도 통과했다.

## Prevention

surface TODO를 닫을 때는 “테스트가 어딘가에 있겠지”가 아니라, 구현 파일과 lane을 개별 문서에 바로 적어야 한다.
특히 current route에서 직접 열리지 않는 legacy surface는 open으로 방치하지 말고, actual wiring 기준으로 orphan status를 명시해야 한다.

### Checklist Addition

- [ ] UI closeout 전에 `grep -a -n "Executed .*tests"` 로 targeted run이 실제 test case를 실행했는지 확인한다.
- [ ] `--only-testing` 값은 파일 경로가 아니라 `DUNEUITests/<ClassName>` 또는 `DUNEUITests/<ClassName>/<method>` 형식으로 준다.
- [ ] template/compound/cardio/deep-link flow는 visible text 대신 AXID contract를 먼저 고정한다.

### Rule Addition (if applicable)

기존 규칙 추가까지는 필요 없지만, future closeout에서도 “0 tests false green” 확인은 반복 체크리스트로 유지하는 편이 좋다.

## Lessons Learned

backlog closeout은 새 test file을 늘리는 작업이 아니라, existing regression을 surface inventory와 다시 연결하는 작업일 때가 많다.
또한 문서 정리보다 먼저 “실제로 테스트가 몇 건 실행됐는지”를 확인하지 않으면, 성공 로그만 보고 잘못 닫을 수 있다.
