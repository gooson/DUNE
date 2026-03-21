---
topic: nightly-ui-test-template-lane-fix
date: 2026-03-22
status: implemented
confidence: medium
related_solutions:
  - docs/solutions/testing/2026-03-09-e2e-exercise-picker-surface-contract.md
  - docs/solutions/testing/2026-03-09-ui-test-aut-launch-lifecycle-hardening.md
  - docs/solutions/testing/2026-03-08-ui-smoke-toolbar-tap-stability.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: Nightly UI Test Template Lane Fix

## Context

GitHub Actions run `23387043762`의 `nightly-ios-ui-tests` job이 `ActivityExercisePickerRegressionTests`의 quick start detail/template lane에서 처음 실패한 뒤,
같은 세션의 이후 테스트들이 `Failed to terminate ...` 및 launch timeout으로 연쇄 실패하고 있다.
로그상 첫 근본 실패는 quick start picker 후속 화면(`exercise-detail-screen`, `exercise-start-screen`)이 나타나지 않는 점이다.

## Requirements

### Functional

- quick start picker에서 single-exercise template을 탭하면 `ExerciseStartView`가 안정적으로 열린다.
- quick start picker에서 exercise detail 버튼을 탭하면 `ExerciseDetailSheet`가 안정적으로 열린다.
- 첫 실패가 사라져 이후 UI test launch/terminate cycle이 연쇄 오염되지 않는다.
- multi-exercise template start flow와 일반 single-exercise picker flow는 기존 동작을 유지한다.

### Non-functional

- nested sheet dismiss 이후 후속 presentation이 main-thread turn/race에 의존하지 않도록 계약을 단일화한다.
- 기존 UI test selector/fixture contract는 유지한다.
- 검증은 최소한 failing regression test와 관련 smoke/build를 실제로 실행한다.

## Approach

quick start picker의 후속 presentation owner는 Activity tab 부모 뷰에 있어야 하는데, 기존 구현은 child action과 상태 polling에 의존해 실제 sheet dismissal completion 이전에 start/detail handoff가 실행될 수 있었다.
특히 template start는 picker dismissal과 `ExerciseStartView` presentation이 겹쳤고, detail sheet는 picker list row tap 직후 같은 turn에서 nested sheet를 올려 CI에서 드롭될 가능성이 컸다.

따라서 quick start action의 최종 owner를 Activity picker sheet의 `onDismiss`로 통일하고,
detail sheet는 다음 main-queue turn으로 defer해 nested presentation contract를 안정화한다.
이후 failing regression class 전체를 다시 돌려 `exercise-start-screen`/`exercise-detail-screen` 진입과 후속 launch 안정성을 함께 확인한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `ExercisePickerView.dismissPicker`에서 template/detail 전용 지연 추가 | child에서 바로 해결 가능 | selection/template/detail 경로 계약이 다시 갈라지고 owner가 모호해짐 | 기각 |
| `ActivityView`에서 quick start action을 sheet `onDismiss`로 통일 | dismissal completion 이후만 후속 presentation 실행, owner 일원화 | 부모에 pending action state 추가 필요 | 채택 |
| UI test timeout/terminate helper만 완화 | 증상 완화 가능 | 최초 기능 회귀를 숨기고 실제 start 화면 미전환 문제를 남김 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Activity/ActivityView.swift` | code | quick start follow-up action을 sheet `onDismiss` 기반 pending-action contract로 통일 |
| `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift` | code | detail button nested sheet presentation을 다음 main-queue turn으로 defer |
| `DUNEUITests/Full/ActivityExercisePickerRegressionTests.swift` | test | toolbar tap/hub 복귀/detail button reachability를 helper 기반으로 안정화 |
| `docs/solutions/testing/...` | docs | 해결 원인과 재발 방지 규칙 기록 |

## Implementation Steps

### Step 1: Quick start dismissal contract 정렬

- **Files**: `DUNE/Presentation/Activity/ActivityView.swift`, `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift`
- **Changes**: quick start exercise/template callback를 sheet `onDismiss` completion 이후 실행되도록 pending action contract로 통일하고, detail sheet는 defer helper로 presentation turn을 분리
- **Verification**: single template 탭 후 `ExerciseStartView`, detail 버튼 탭 후 `ExerciseDetailSheet`가 열리는지 targeted UI test로 확인

### Step 2: Regression verification

- **Files**: `DUNEUITests/Full/ActivityExercisePickerRegressionTests.swift`, 필요 시 `DUNEUITests/Helpers/UITestBaseCase.swift`
- **Changes**: toolbar tap/hub 복귀/detail button reachability가 CI에서도 안정적으로 동작하도록 existing helper 재사용 범위만 최소 보강
- **Verification**: failing test class와 연관된 launch path를 반복 실행

### Step 3: Documentation and review trail

- **Files**: `docs/solutions/testing/...`
- **Changes**: 증상, 근본 원인, 수정 위치, 재발 방지 포인트 문서화
- **Verification**: 문서가 최종 구현과 일치하는지 diff 기준 확인

## Edge Cases

| Case | Handling |
|------|----------|
| multi-exercise template 선택 | 기존 `TemplateWorkoutConfig` full-screen flow가 그대로 유지되는지 확인 |
| quick start 일반 exercise selection | `onDismiss` 기반 handoff로 바뀐 뒤에도 바로 start flow가 유지되는지 함께 확인 |
| detail sheet / create custom sheet 등 nested presentation | picker dismiss owner를 부모 contract로 유지해 sheet race를 늘리지 않음 |
| CI에서 첫 실패 후 terminate/launch 연쇄 오류 | 최초 start-screen failure 제거 후 후속 failure가 사라지는지 로그로 확인 |

## Testing Strategy

- Unit tests: 없음. 이번 수정은 sheet presentation timing 계약이라 기존 UI regression으로 직접 검증
- Integration tests: `scripts/test-ui.sh --only-testing DUNEUITests/ActivityExercisePickerRegressionTests --test-plan DUNEUITests-Full`
- Manual verification: 필요 시 same command 재실행으로 flake 재발 여부 확인
- Build verification: `scripts/build-ios.sh`

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 부모/자식이 모두 dismiss를 만져 double-transition warning 발생 | medium | medium | parent는 scheduling owner만 담당하고 child dismiss contract와 중복되지 않게 최소 수정 |
| template quick start만 고쳐도 다른 launch flake가 남아 있을 수 있음 | medium | medium | 최초 failing lane 해결 후 targeted UI suite로 후속 launch behavior 확인 |
| local simulator와 GitHub runner timing 차이 | medium | high | existing nightly regression test 자체를 재사용하고 필요한 경우 2회 이상 반복 검증 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: CI 첫 실패 지점과 현재 코드의 dismiss/present 계약 불일치가 정확히 맞물리지만, UI runtime race 특성상 targeted test로 실제 재현·검증이 필요하다.
