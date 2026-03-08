---
topic: watch workout e2e surface inventory
date: 2026-03-09
status: draft
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase0-page-backlog-split.md
  - docs/solutions/testing/2026-03-09-vision-train-surface-inventory.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: Watch Workout E2E Surface Inventory

## Context

`todos/075`~`todos/083`는 각각 분리돼 있지만 실제 사용자 흐름으로는 `CarouselHomeView`에서 시작해 `SessionSummaryView`까지 이어지는 하나의 watch workout journey다. 현재 일부 화면에는 selector가 있지만 naming policy가 분산돼 있고, `ControlsView`, `RestTimerView`, `SetInputSheet`, `SessionSummaryView`는 surface inventory를 닫기 위한 stable anchor가 부족하다. 기존 smoke는 home render와 quick start workout start까지만 확인하므로, watch workout flow 전체 vocabulary를 공용 helper와 smoke 기준으로 고정할 필요가 있다.

## Requirements

### Functional

- `075`~`083`에 해당하는 watch workout flow의 entry route와 target lane을 코드 기준 selector로 고정해야 한다.
- 각 surface에 stable AXID inventory를 부여하고, view 구현과 TODO 문서가 같은 vocabulary를 사용해야 한다.
- 최소 smoke 검증으로 home 진입, all exercises 진입, workout preview/start, active session interaction, summary 진입을 확인할 수 있어야 한다.
- `todos/075`~`todos/083`을 이번 범위에 맞게 `done`으로 갱신하고 backlog index 링크를 동기화해야 한다.

### Non-functional

- 기존 workout 로직은 바꾸지 않고 accessibility wiring과 test helper 확장에 집중한다.
- selector naming은 watch 전용 shared helper 하나에서 관리한다.
- UI smoke는 seeded watch fixture(`ui-test-squat`)를 사용해 deterministic하게 유지한다.
- 다른 브랜치에서 진행 중인 `087`, `089`, `090` visionOS surface와 파일 충돌이 없어야 한다.

## Approach

visionOS surface inventory와 같은 패턴으로 watch 전용 selector helper를 추가하고, `075`~`083` 대상 view에 root/action/state anchor를 wiring한다. 이후 `DUNEWatchTests`에서 helper stability/uniqueness를 검증하고, `DUNEWatchUITests` smoke helper를 확장해 seeded single-exercise flow로 controls/rest/input/summary까지 실제 진입 근거를 남긴다. 마지막으로 각 TODO 문서를 `done`으로 바꾸고 entry route, inventory, assertion scope, PR gate/nightly lane을 현재 코드 기준으로 적는다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `075`~`079`만 먼저 닫고 나머지는 후속으로 미룬다 | diff가 작고 smoke 변경이 적다 | 같은 session flow vocabulary가 다시 갈라지고 `080`~`083`이 곧 동일 helper를 다시 건드리게 된다 | Rejected |
| TODO 문서만 채우고 코드/테스트는 유지한다 | 구현량이 가장 적다 | 실제 selector drift를 감지할 source of truth가 없어 backlog를 닫는 근거가 약하다 | Rejected |
| watch selector helper + view wiring + unit/smoke + TODO sync를 한 배치로 처리한다 | flow 전체 vocabulary를 한 번에 고정하고 후속 watch regression 기반을 만든다 | 수정 파일 수가 늘어난다 | Accepted |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEWatch/Helpers/WatchWorkoutSurfaceAccessibility.swift` | Create | watch workout flow selector helper 추가 |
| `DUNEWatch/Views/CarouselHomeView.swift` | Modify | home root/card anchor를 helper 기반으로 정리 |
| `DUNEWatch/Views/QuickStartAllExercisesView.swift` | Modify | quick start root/section/row anchor 보강 |
| `DUNEWatch/Views/WorkoutPreviewView.swift` | Modify | preview root, strength/cardio action anchor 고정 |
| `DUNEWatch/Views/SessionPagingView.swift` | Modify | paging root 및 page-level anchor 고정 |
| `DUNEWatch/Views/MetricsView.swift` | Modify | metrics root, input card, transition/state anchor 고정 |
| `DUNEWatch/Views/ControlsView.swift` | Modify | controls root와 action button anchor 추가 |
| `DUNEWatch/Views/RestTimerView.swift` | Modify | rest timer root/countdown/action anchor 추가 |
| `DUNEWatch/Views/SetInputSheet.swift` | Modify | input sheet root/history/done/button anchor 추가 |
| `DUNEWatch/Views/SessionSummaryView.swift` | Modify | summary root/stats/done/effort sheet anchor 추가 |
| `DUNEWatchTests/WatchWorkoutSurfaceAccessibilityTests.swift` | Create | helper stability/uniqueness 테스트 추가 |
| `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift` | Modify | shared watch smoke helper를 새 selector 기준으로 확장 |
| `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift` | Modify | home/all-exercises surface assertion 보강 가능성 반영 |
| `DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.swift` | Modify | preview/start/session root smoke 보강 |
| `DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.swift` | Create | controls/rest/summary smoke 추가 |
| `todos/075-*.md` ~ `todos/083-*.md` | Move + Modify | `ready` → `done`, inventory/scope/PR gate 기록 |
| `todos/021-ready-p2-e2e-phase0-page-backlog-index.md` | Modify | 075~083 링크를 done 파일명으로 동기화 |

## Implementation Steps

### Step 1: Watch workout selector helper와 view wiring 추가

- **Files**: `DUNEWatch/Helpers/WatchWorkoutSurfaceAccessibility.swift`, `DUNEWatch/Views/CarouselHomeView.swift`, `DUNEWatch/Views/QuickStartAllExercisesView.swift`, `DUNEWatch/Views/WorkoutPreviewView.swift`, `DUNEWatch/Views/SessionPagingView.swift`, `DUNEWatch/Views/MetricsView.swift`, `DUNEWatch/Views/ControlsView.swift`, `DUNEWatch/Views/RestTimerView.swift`, `DUNEWatch/Views/SetInputSheet.swift`, `DUNEWatch/Views/SessionSummaryView.swift`
- **Changes**:
  - home / quick start / preview / session / summary flow 전체 selector vocabulary를 helper에 모은다.
  - 기존 raw string identifier는 helper 참조로 치환하고, 빠진 root/action/state anchor를 추가한다.
  - dynamic selectors는 exercise id, card id, previous set index 같은 식으로 helper 함수로 정의한다.
- **Verification**: `scripts/build-ios.sh`

### Step 2: Watch unit/smoke 검증 추가

- **Files**: `DUNEWatchTests/WatchWorkoutSurfaceAccessibilityTests.swift`, `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift`, `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift`, `DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.swift`, `DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.swift`
- **Changes**:
  - helper constant uniqueness/stability를 Swift Testing으로 고정한다.
  - watch UI base helper에 set input dismiss, controls page 이동, set completion, rest skip, summary wait 같은 reusable flow를 추가한다.
  - smoke에서 seeded single-exercise flow로 home/all exercises, preview/start, controls page, rest timer, summary surface를 검증한다.
- **Verification**:
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNEWatchTests -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm),OS=26.0' -only-testing DUNEWatchTests/WatchWorkoutSurfaceAccessibilityTests`
  - `scripts/test-watch-ui.sh --only-testing DUNEWatchUITests/WatchHomeSmokeTests --only-testing DUNEWatchUITests/WatchWorkoutStartSmokeTests --only-testing DUNEWatchUITests/WatchWorkoutFlowSmokeTests`

### Step 3: TODO 문서와 backlog index 동기화

- **Files**: `todos/075-*.md` ~ `todos/083-*.md`, `todos/021-ready-p2-e2e-phase0-page-backlog-index.md`
- **Changes**:
  - `075`~`083`을 `done`으로 rename/update 한다.
  - 각 문서에 entry route, selector inventory, state/assertion scope, PR gate/nightly lane, deferred lane을 현재 코드/테스트 기준으로 기록한다.
  - backlog index의 watch 링크를 새 done 파일명으로 바꾼다.
- **Verification**: `rg -n "075-|076-|077-|078-|079-|080-|081-|082-|083-" todos/021-ready-p2-e2e-phase0-page-backlog-index.md todos`

## Edge Cases

| Case | Handling |
|------|----------|
| watch home이 empty state로 뜨는 경우 | smoke helper는 carousel/empty 중 하나를 허용하고, seeded scenario에서는 quick start list 진입까지 함께 확인한다 |
| initial `SetInputSheet`가 metrics page 위에 자동 표시되는 타이밍 | sheet root/done selector를 추가하고 base helper에서 명시적으로 dismiss 한다 |
| single exercise fixture라 controls `Skip` 버튼이 노출되지 않을 수 있음 | docs와 smoke에서 `Skip`은 optional/deferred lane로 기록하고 core assertion은 end/pause 중심으로 둔다 |
| rest timer countdown은 실시간 값이라 flaky 할 수 있음 | countdown 숫자 대신 rest root와 skip/end button 존재를 assert 한다 |
| summary 저장/종료 타이밍이 HealthKit finalize에 영향받을 수 있음 | seeded smoke는 summary root와 effort/done surface 존재까지만 확인하고 최종 dismiss는 optional로 둔다 |

## Testing Strategy

- Unit tests:
  - `DUNEWatchTests/WatchWorkoutSurfaceAccessibilityTests.swift`
- Integration tests:
  - `scripts/build-ios.sh`
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNEWatchTests -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm),OS=26.0' -only-testing DUNEWatchTests/WatchWorkoutSurfaceAccessibilityTests`
  - `scripts/test-watch-ui.sh --only-testing DUNEWatchUITests/WatchHomeSmokeTests --only-testing DUNEWatchUITests/WatchWorkoutStartSmokeTests --only-testing DUNEWatchUITests/WatchWorkoutFlowSmokeTests`
- Manual verification: 없음. seeded watch smoke로 대체한다.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 새 accessibility identifier가 watch navigation hit testing을 바꿀 수 있음 | Low | Medium | 구조는 유지하고 container/button에만 identifier를 추가한다 |
| watch UI smoke가 simulator 타이밍에 민감할 수 있음 | Medium | Medium | reusable wait helper를 base case에 넣고 dynamic text assert를 피한다 |
| summary 진입 직전 state transition이 느리면 flaky 할 수 있음 | Medium | Medium | smoke 범위를 summary root/effort button 존재까지로 제한하고 long post-save assertion은 제외한다 |
| TODO를 과도하게 닫아 deeper interaction 범위를 숨길 수 있음 | Low | Medium | 각 TODO의 deferred lane에 optional/deep interaction 범위를 명시한다 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: existing seeded watch fixture와 smoke infrastructure가 이미 있고, 이번 변경은 workout flow selector inventory를 공용 helper로 정리하는 성격이라 기능 로직보다 surface contract 안정화에 가깝다.
