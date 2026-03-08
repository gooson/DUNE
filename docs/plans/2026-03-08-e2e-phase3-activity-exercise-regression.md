---
topic: E2E Phase 3 Activity Exercise Regression
date: 2026-03-08
status: draft
confidence: medium
related_solutions:
  - docs/solutions/testing/ui-test-infrastructure-design.md
  - docs/solutions/testing/2026-03-03-ipad-activity-tab-ui-test-navigation-stability.md
  - docs/solutions/testing/2026-03-04-ui-test-max-hardening-and-axid-stability.md
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
  - docs/solutions/testing/2026-03-08-e2e-phase2-today-settings-regression.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: E2E Phase 3 Activity Exercise Regression

## Context

`docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md`의 다음 구현 단계는 `DUNE Activity / Exercise` 회귀 세트다.
현재 저장소에는 `ActivitySmokeTests`와 chart interaction 회귀 테스트가 일부 존재하지만, Activity detail routes, Exercise sub-flow, template/cardio/notification route, category/custom exercise 흐름은 full regression lane에서 아직 닫히지 않았다.

Phase 1/2에서 launch/reset/seed 기반과 Today/Settings selector contract는 정리됐다.
이번 단계는 그 기반을 Activity/Exercise 영역으로 확장해, seeded 상태에서 detail navigation과 주요 workout flow를 결정적으로 재현하는 것이 목적이다.

## Requirements

### Functional

- Activity tab에서 다음 주요 진입 경로를 full regression으로 검증할 수 있어야 한다.
  - training readiness hero -> detail
  - muscle map -> detail
  - weekly stats -> detail
  - training volume -> overview -> exercise type detail
  - personal records / consistency / exercise mix detail
  - recent workouts -> ExerciseView
- Exercise flow에서 다음 핵심 경로를 검증할 수 있어야 한다.
  - picker quick-start open / search / all-exercises / detail sheet
  - create custom exercise
  - ExerciseStartView -> WorkoutSessionView
  - WorkoutSessionView complete / finish / completion sheet dismiss
  - templates list open / create validation / create / edit / start
  - compound workout setup -> compound workout
  - cardio start -> cardio session -> cardio summary
  - user category management open / create
- Notification-based route에서 다음 경로를 재현할 수 있어야 한다.
  - notification item -> mock HealthKit workout detail
  - missing notification target -> fallback screen

### Non-functional

- 기존 Phase 1/2 seeded 시나리오와 smoke suite를 깨뜨리지 않아야 한다.
- iPhone/iPad 공통으로 AXID 우선 selector를 유지해야 한다.
- HealthKit 실데이터가 없는 시뮬레이터에서도 deterministic하게 실행되어야 한다.
- full regression 확장은 하되 PR smoke는 현재 속도 특성을 유지해야 한다.

## Approach

Phase 3는 `새 seeded scenario + source/destination selector 보강 + ActivityExerciseRegressionTests 추가` 조합으로 구현한다.

1. 기존 `defaultSeeded`는 유지하고, Activity/Exercise 전용 seeded scenario를 별도로 추가한다.
   - templates, custom category, custom exercise, notification route fixture, mock workout detail payload를 이 시나리오에 한정한다.
2. Activity/Exercise 주요 source surface와 destination/action surface에 AXID를 보강한다.
   - 섹션/행/버튼/폼/sheet/action을 테스트 가능한 최소 단위로 식별한다.
3. full regression 테스트는 `DUNEUITests/Full/ActivityExerciseRegressionTests.swift`에 모으고, smoke suite는 유지한다.
4. HealthKit 실경로 의존이 큰 화면은 UI-test-only mock route를 제공해 regression entrypoint를 고정한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 `defaultSeeded`만 계속 확장 | 구현이 단순함 | Today/Settings 회귀와 Activity/Exercise fixture가 강하게 결합됨 | 기각 |
| UI 테스트에서 전부 빈 상태부터 직접 생성 | 앱 코드 변경이 적음 | 생성 비용이 크고 swipe/modal/seed 순서에 따라 flaky 가능성이 높음 | 기각 |
| Activity/Exercise 전용 scenario + 필요한 surface만 AXID 보강 | Phase 2 격리 유지, 테스트 결정성 확보 | scenario/fixture 관리 코드가 늘어남 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-08-e2e-phase3-activity-exercise-regression.md` | add | 이번 작업의 구현 계획서 |
| `DUNEUITests/Helpers/UITestBaseCase.swift` | update | Activity/Exercise seeded scenario 지원 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | update | Phase 3 AXID constants / helper 추가 |
| `DUNE/App/TestDataSeeder.swift` | update | activity-exercise scenario, template/custom/notification/mock workout fixture 추가 |
| `DUNE/App/DUNEApp.swift` | update | 새 scenario 해석 및 mock workout route support 연결 필요 시 반영 |
| `DUNE/Presentation/Activity/ActivityView.swift` | update | Activity source section AXID와 notification mock route fallback 보강 |
| `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift` | update | picker row/detail/all/custom selector 보강 |
| `DUNE/Presentation/Exercise/ExerciseStartView.swift` | update | start screen / action selector 보강 |
| `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | update | session root, input, complete/finish selector 보강 |
| `DUNE/Presentation/Exercise/Components/WorkoutCompletionSheet.swift` | update | completion sheet selector 보강 |
| `DUNE/Presentation/Exercise/Components/WorkoutTemplateListView.swift` | update | template list/add/row selector 보강 |
| `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift` | update | template form selector 보강 |
| `DUNE/Presentation/Exercise/Components/CompoundWorkoutSetupView.swift` | update | setup/add/start selector 보강 |
| `DUNE/Presentation/Exercise/CardioSession/CardioStartSheet.swift` | update | cardio start selector 보강 |
| `DUNE/Presentation/Exercise/CardioSession/CardioSessionView.swift` | update | cardio session selector 보강 |
| `DUNE/Presentation/Exercise/CardioSession/CardioSessionSummaryView.swift` | update | cardio summary selector 보강 |
| `DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift` | update | detail root selector 보강 |
| `DUNE/Presentation/Shared/NotificationTargetNotFoundView.swift` | update | fallback root selector 보강 |
| `DUNE/Presentation/Exercise/Components/UserCategoryManagementView.swift` | update | category list/edit/create selector 보강 |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | add | Activity/Exercise full regression suite |

## Implementation Steps

### Step 1: Activity/Exercise seeded scenario와 mock route 고정

- **Files**: `DUNEUITests/Helpers/UITestBaseCase.swift`, `DUNE/App/TestDataSeeder.swift`, `DUNE/App/DUNEApp.swift`, `DUNE/Presentation/Activity/ActivityView.swift`
- **Changes**:
  - `UITestSeedScenario`와 `LaunchScenario`에 Activity/Exercise 전용 case를 추가한다.
  - scenario 전용 fixture로 template/custom/category/notification inbox/mock workout detail payload를 seed한다.
  - Activity notification route가 실 HealthKit workout 부재 시에도 UI-test fixture workout으로 detail을 열 수 있게 한다.
- **Verification**:
  - 새 scenario launch에서 Activity root / template list / custom category / notification route가 재현된다.
  - 기존 `defaultSeeded` 기반 Today/Settings 테스트 가정은 유지된다.

### Step 2: Activity/Exercise selector contract 보강

- **Files**: `DUNEUITests/Helpers/UITestHelpers.swift`, `DUNE/Presentation/Activity/ActivityView.swift`, `DUNE/Presentation/Exercise/*`, `DUNE/Presentation/Shared/NotificationTargetNotFoundView.swift`
- **Changes**:
  - Activity source section, picker row/detail button, start/session/template/cardio/category 화면에 AXID를 추가한다.
  - destination screen은 navigation title 또는 root AXID 중 하나로 안정적으로 판별되도록 맞춘다.
  - confirmation sheet / modal dismiss / action CTA는 문자열 의존 없이 접근 가능하게 한다.
- **Verification**:
  - full regression 테스트가 label 대신 AXID 또는 English navigation title로 탐색한다.
  - iPhone/iPad 공통 helper에서 동일 selector가 resolve된다.

### Step 3: Activity/Exercise full regression suite 작성

- **Files**: `DUNEUITests/Full/ActivityExerciseRegressionTests.swift`, 필요 시 `DUNEUITests/Smoke/ActivitySmokeTests.swift`
- **Changes**:
  - Activity detail routes, picker/detail/create, workout session, templates, compound/cardio, notification route를 full regression test로 추가한다.
  - smoke lane는 유지하고, Phase 3 검증은 full plan only로 둔다.
- **Verification**:
  - `scripts/test-ui.sh --test-plan DUNEUITests-Full --only-testing DUNEUITests/Full/ActivityExerciseRegressionTests`
  - 필요 시 `scripts/test-ui.sh --smoke --only-testing DUNEUITests/Smoke/ActivitySmokeTests`

## Edge Cases

| Case | Handling |
|------|----------|
| HealthKit workout이 시뮬레이터에 없어 detail route가 비어 있음 | UI-test-only mock workout summary fallback을 제공 |
| template/cardio/category flow가 launch 상태에 따라 비결정적 | Activity/Exercise 전용 scenario에서 필요한 fixture를 선반영 |
| swipe action 기반 edit/delete가 flaky | 행 selector를 고정하고 필요 시 direct button/identifier를 추가 |
| iPad에서 sheet/list 구조가 달라져 tap target이 바뀜 | AXID 기반 탐색 + existing sidebar/tab helper 재사용 |
| seeded fixture가 기존 Phase 2 UI 상태를 오염 | 기존 scenario를 건드리지 않고 별도 scenario에만 추가 fixture 적용 |

## Testing Strategy

- Unit tests: 없음. 이번 범위는 UI regression + UI-test fixture/support code 중심이다.
- Integration tests:
  - `scripts/test-ui.sh --test-plan DUNEUITests-Full --only-testing DUNEUITests/Full/ActivityExerciseRegressionTests`
  - `scripts/test-ui.sh --smoke --only-testing DUNEUITests/Smoke/ActivitySmokeTests`
- Manual verification:
  - `git diff --stat`
  - seeded scenario에서 Activity tab / notification route / template list 화면 확인
  - selector는 AXID 또는 English navigation title 기준으로 재점검

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| seeded scenario 추가로 fixture 관리가 복잡해짐 | Medium | Medium | Activity/Exercise 전용 data만 별도 helper로 분리 |
| mock workout route가 production 로직에 스며듦 | Low | High | `--uitesting` / DEBUG guard 아래에서만 활성화 |
| full regression 테스트 수가 많아져 실행 시간이 급증 | Medium | Medium | smoke lane는 유지하고 deep flow는 full lane로 한정 |
| template/cardio flow가 시뮬레이터 상태에 따라 flaky | Medium | Medium | deterministic seed + AXID + direct route assertion으로 단계 축소 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 Activity smoke, picker, seeded exercise records, notification infrastructure가 있어 기반은 충분하다. 다만 HealthKit workout detail과 template/cardio flow는 아직 deterministic route contract가 부족해, fixture/support 코드 보강이 함께 필요하다.
