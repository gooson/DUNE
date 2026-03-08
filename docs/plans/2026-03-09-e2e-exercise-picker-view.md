---
topic: exercise picker e2e surface
date: 2026-03-09
status: draft
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase0-page-backlog-split.md
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
  - docs/solutions/testing/2026-03-08-e2e-phase3-activity-exercise-regression-hardening.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: ExercisePickerView E2E Surface

## Context

`todos/045-ready-p2-e2e-dune-exercise-picker-view.md`는 `ExercisePickerView`가 아직 smoke 수준(open/search)만 고정되어 있고, 실제 회귀에 필요한 deeper flow는 열려 있다고 정의한다.
이 picker는 `ActivityView`의 quick start entry와 `CreateTemplateView` / `CompoundWorkoutSetupView`의 full picker entry를 공유하므로, surface 자체를 안정 selector와 full regression으로 분리해 두지 않으면 후속 `046`~`050` 작업도 계속 간접 검증에 의존하게 된다.

## Requirements

### Functional

- `quickStart` 모드에서 hub/검색/detail 진입의 핵심 selector를 안정적으로 검증할 수 있어야 한다.
- `full` 모드에서 create custom CTA, category/user-category/muscle/equipment filter, row select 흐름을 실제 진입 경로로 검증할 수 있어야 한다.
- 새 E2E는 seeded scenario 기반으로 deterministic하게 실행되어야 한다.
- `todos/045`를 이번 구현 범위에 맞게 `done`으로 전환해야 한다.

### Non-functional

- PR gate는 기존 smoke open/search를 유지하고, deeper picker regression은 `DUNEUITests/Full` lane에 둔다.
- localized label 대신 AXID 위주로 selector를 구성한다.
- 추가 AXID는 host 화면에 불필요한 구조 변경 없이 `ExercisePickerView` 내부에 국한한다.

## Approach

`ExercisePickerView`를 하나의 공용 component surface로 보고, 모드별 lane을 나눠서 검증한다.

- `quickStart lane`: Activity toolbar add → picker open → recent/preferred/popular/all hub 노출 → search 결과/detail 진입
- `full lane`: Template form add exercise 또는 compound add exercise → full picker open → create custom CTA 노출 → filter chip 적용 → row select 후 host 화면 복귀

이를 위해 picker 내부에 section/chip/template/action용 AXID를 추가하고, 새 `ActivityExercisePickerRegressionTests` 파일에서 seeded scenario를 재사용한다.
기존 `ActivitySmokeTests`는 빠른 PR gate 역할만 유지하고, deep flow는 full regression으로 이동시킨다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 `ActivityExerciseRegressionTests`에 테스트 몇 개만 추가 | 파일 수 증가 없음 | picker 전용 surface contract가 다른 exercise flow와 뒤섞여 triage가 어려움 | Rejected |
| `ExercisePickerView`를 위한 전용 full regression 파일 추가 | surface ownership이 명확하고 TODO 045와 1:1 대응 | 파일 1개 증가 | Accepted |
| label/text 기반 selector만 사용 | 구현 변경이 적음 | locale/flaky risk가 큼 | Rejected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift` | Modify | section/filter/template selector inventory 추가 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | Modify | picker surface AXID 상수 확장 |
| `DUNEUITests/Full/ActivityExercisePickerRegressionTests.swift` | Create | quickStart/full lane regression 추가 |
| `todos/045-ready-p2-e2e-dune-exercise-picker-view.md` | Modify | status를 done으로 갱신 |

## Implementation Steps

### Step 1: Picker selector inventory 확장

- **Files**: `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift`, `DUNEUITests/Helpers/UITestHelpers.swift`
- **Changes**:
  - quick start section anchors(`recent`, `preferred`, `popular`, `templates`, `all`) 추가
  - template row / hide-all / clear-filters / category / user-category / muscle / equipment chip AXID 추가
  - 테스트 코드가 localized copy 대신 안정 selector를 쓰도록 registry 동기화
- **Verification**: `swiftc -typecheck` 또는 build에서 compile error 없음

### Step 2: Full regression 추가

- **Files**: `DUNEUITests/Full/ActivityExercisePickerRegressionTests.swift`
- **Changes**:
  - `ActivityExerciseSeededUITestBaseCase` 기반 테스트 클래스 추가
  - quick start lane:
    - picker hub sections 존재
    - all exercises reveal/hide 동작
    - template row 탭으로 template workout container 진입
    - search → detail sheet 진입
  - full lane:
    - template form entry에서 full picker open
    - create custom CTA 존재
    - user category/muscle/equipment filter 조합 후 custom/library row 노출 검증
    - row select 후 template form으로 복귀 및 save enable 검증
- **Verification**: targeted UI test 실행

### Step 3: TODO 상태 및 문서 정리

- **Files**: `todos/045-ready-p2-e2e-dune-exercise-picker-view.md`
- **Changes**:
  - frontmatter/status를 `done`으로 갱신
  - 필요 시 notes에 이번 lane 결정(PR smoke 유지, full regression 확장) 반영
- **Verification**: TODO 파일명/내용 status 일치

## Edge Cases

| Case | Handling |
|------|----------|
| quick start에서 template section이 scenario에 따라 비는 경우 | `activityExerciseSeeded`의 seeded template를 사용해 deterministic하게 보장 |
| full mode search field는 `.searchable` 구현이라 selector가 불안정할 수 있음 | full mode는 filter chip + row selection 중심으로 검증하고, 검색 핵심 검증은 quick start lane에서 유지 |
| picker dismiss 이후 host 화면 전환 타이밍 | 기존 `dismissPicker` handoff와 `waitForExistence` 기반 assertion 사용 |
| localized chip label 변경 | chip/button selector를 새 AXID로 직접 부여 |

## Testing Strategy

- Unit tests: 없음. 이번 변경은 UI surface와 XCUI regression 범위다.
- Integration tests:
  - `scripts/test-ui.sh --stream-log --only-testing DUNEUITests/ActivityExercisePickerRegressionTests`
  - 필요 시 기존 smoke 회귀 확인: `scripts/test-ui.sh --stream-log --only-testing DUNEUITests/ActivitySmokeTests/testExercisePickerOpens`
- Manual verification: 없음. seeded XCUI flow로 대체한다.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 새 AXID가 SwiftUI row hit-testing을 깨뜨릴 가능성 | Low | Medium | button/container hierarchy는 유지하고 identifier만 추가 |
| quick start/full lane를 한 파일에 담으면서 실행 시간이 길어질 가능성 | Medium | Low | picker surface 전용 테스트만 유지하고 session flow는 기존 파일에 남긴다 |
| seeded data가 바뀌어 template/custom category가 사라질 가능성 | Medium | Medium | 테스트에서 seeded fixture 이름을 한 곳의 enum으로 고정하고 실패 시 원인 파악이 쉽도록 메시지 명확화 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: existing seeded fixtures와 regression base case가 이미 준비되어 있고, 필요한 변경은 component-local AXID + new full regression file 수준으로 제한된다.
