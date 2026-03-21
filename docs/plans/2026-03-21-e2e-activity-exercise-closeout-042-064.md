---
topic: e2e activity exercise closeout 042 064
date: 2026-03-21
status: completed
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase0-page-backlog-split.md
  - docs/solutions/testing/2026-03-08-e2e-phase3-activity-exercise-regression-hardening.md
  - docs/solutions/testing/2026-03-09-e2e-done-todo-index-consolidation.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: E2E Activity / Exercise Closeout 042-064

## Context

`todos/active/e2e/042`~`064`는 현재 phase 0 open backlog의 마지막 Activity / Exercise surface들이다.
이미 저장소에는 `ActivityExerciseRegressionTests`와 `ActivityExercisePickerRegressionTests`가 존재하고, 다수 surface는 여기서 실제 사용자 경로로 이미 다뤄지고 있다.

이번 배치의 핵심은 새 test target을 만들거나 surface별 suite를 쪼개는 것이 아니다.
기존 full regression을 source of truth로 삼고, closeout 근거가 얕은 surface만 selector/assertion을 보강한 뒤 `042`~`064` 개별 TODO를 `done`으로 전환하는 것이다.

조사 결과:

- `042, 046, 047, 048, 049, 050, 051, 052, 053, 054, 057, 059, 060, 061, 063, 064`는 existing full regression으로 closeout 근거가 이미 있다.
- `055 TemplateWorkoutContainerView`, `058 CompoundWorkoutView`, `062 HealthKitWorkoutDetailView`는 dedicated assertion depth를 조금 더 올릴 필요가 있다.
- `056 TemplateWorkoutView`는 현재 실제 route에서 사용되지 않는 legacy surface로 보이며, closeout 시 현재 wiring 기준을 명시적으로 기록해야 한다.

## Requirements

### Functional

- `042`~`064` 각 surface가 어느 regression file / lane에서 닫히는지 현재 코드 기준으로 확정한다.
- closeout 근거가 약한 `055`, `058`, `062`는 selector 또는 regression assertion을 추가해 surface-level evidence를 보강한다.
- `056`은 현재 active route 부재를 검증하고, backlog 문서에 legacy/orphan status를 반영해 정리한다.
- `042`~`064` TODO를 `done`으로 rename/update 하고, `101` open index와 `107` completed index를 동기화한다.

### Non-functional

- 기존 `DUNEUITests` 인프라와 seeded activity scenario를 재사용한다.
- 테스트는 locale-safe selector를 우선 사용한다.
- project target/scheme 구조는 건드리지 않는다.
- 변경은 Activity / Exercise closeout 범위에 한정한다.

## Approach

기존 regression suite를 closeout evidence로 채택하고, 부족한 부분만 보강한다.

### Closeout Strategy

1. open TODO 20건을 existing regression/test helper에 매핑한다.
2. 매핑이 약한 surface만 app selector와 regression assertion을 추가한다.
3. targeted UI verification으로 closeout 증빙을 만든다.
4. 개별 TODO를 `done`으로 옮기고 implementation/lane/notes를 현재 기준으로 기록한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| surface별 신규 regression file 대량 추가 | 분리도 높음 | pbxproj/scheme 수정 비용이 커지고 현재 batch 범위를 넘음 | Rejected |
| 문서만 `done` 처리 | 가장 빠름 | `055`, `058`, `062`, `056` 같은 약한 근거가 남음 | Rejected |
| existing full regression 재사용 + 약한 surface만 보강 | 변경 최소화, closeout 속도 높음, 실제 lane과 문서 정합성 확보 | 일부 root/legacy surface는 추가 판단이 필요 | Accepted |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Exercise/TemplateWorkoutContainerView.swift` | verify / possible modify | full-screen template lifecycle selector 점검 및 필요 시 보강 |
| `DUNE/Presentation/Exercise/CompoundWorkoutView.swift` | verify / possible modify | compound core action/surface selector 보강 |
| `DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift` | verify / possible modify | detail edit route / stats selector 보강 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | modify | 새 selector 상수 추가 시 중앙 정의 |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | modify | `055`, `058`, `062` 중심 assertion depth 보강 |
| `todos/active/e2e/042-064*.md` | rename + modify | `ready` -> `done`, implementation/lane/notes 반영 |
| `todos/active/e2e/101-ready-p2-e2e-phase0-page-backlog-index.md` | modify | open surface 제거, empty backlog 상태 반영 |
| `todos/done/107-done-p2-e2e-phase0-completed-surface-index.md` | modify | completed index에 `042`~`064` 추가 |
| `docs/solutions/testing/2026-03-21-e2e-activity-exercise-closeout-042-064.md` | add | 이번 closeout 패턴과 legacy handling 문서화 |

## Implementation Steps

### Step 1: Build the coverage-to-surface map

- **Files**: `DUNEUITests/Full/ActivityExerciseRegressionTests.swift`, `DUNEUITests/Full/ActivityExercisePickerRegressionTests.swift`, `todos/active/e2e/042-064*.md`
- **Changes**:
  - 각 surface가 어느 test method / lane으로 닫히는지 정리한다.
  - direct implementation evidence가 약한 surface를 식별한다.
- **Verification**:
  - `042`~`064` 각각에 대응하는 implementation/lane 메모를 작성할 수 있어야 한다.

### Step 2: Strengthen weak surface evidence

- **Files**: `TemplateWorkoutContainerView.swift`, `CompoundWorkoutView.swift`, `HealthKitWorkoutDetailView.swift`, `UITestHelpers.swift`, `ActivityExerciseRegressionTests.swift`
- **Changes**:
  - template container lifecycle / close path
  - compound save/share or active-session path
  - HealthKit detail notification-route/title-edit anchor
  - 필요 시 legacy `TemplateWorkoutView`의 non-routed status를 문서화할 근거 수집
- **Verification**:
  - targeted regression이 `055`, `058`, `062`를 실제로 잡는다.

### Step 3: Run targeted verification

- **Files**: 없음
- **Changes**:
  - build + targeted UI test 실행
  - failing selector/flaky path가 있으면 최소 수정
- **Verification**:
  - build 성공
  - activity exercise regression targeted run 성공

### Step 4: Close TODOs and sync backlog indexes

- **Files**: `todos/active/e2e/042-064*.md`, `todos/active/e2e/101-*.md`, `todos/done/107-*.md`
- **Changes**:
  - `042`~`064` 파일 rename/update
  - `101`에서 제거
  - `107`에 추가
- **Verification**:
  - `todos/active/e2e`에는 개별 open surface가 더 이상 남지 않는다.
  - `107` completed index에 `042`~`064`가 모두 반영된다.

## Edge Cases

| Case | Handling |
|------|----------|
| `TemplateWorkoutView.swift`가 실제 route에서 사용되지 않음 | surface closeout note에 legacy/unwired status를 명시하고 current user path는 container + session route로 연결함 |
| screen-level AXID 추가가 child CTA를 가릴 수 있음 | root가 아닌 안정 anchor에만 screen marker를 둔다 |
| HealthKit seeded row가 locale/text에 따라 흔들림 | row selector와 edit CTA AXID를 기준으로 검증한다 |
| compound/template session 흐름이 길어 flake가 생김 | 최소한의 state transition만 검증하고 deeper state는 notes로 분리한다 |

## Testing Strategy

- Unit tests: 없음. 이번 배치는 UI regression closeout 중심이다.
- Integration tests:
  - `scripts/build-ios.sh`
  - `scripts/test-ui.sh --only-testing DUNEUITests/Full/ActivityExercisePickerRegressionTests`
  - `scripts/test-ui.sh --only-testing DUNEUITests/Full/ActivityExerciseRegressionTests`
- Manual verification:
  - `rg -n "042-|046-|047-|048-|049-|050-|051-|052-|053-|054-|055-|056-|057-|058-|059-|060-|061-|062-|063-|064-" todos`

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| existing regression이 일부 환경에서 flaky | medium | medium | targeted rerun으로 surface별 최소 scope만 고정하고, template handoff는 transition screen 강제가 아니라 direct session landing까지 허용하는 assertion으로 수렴한다 |
| orphaned `TemplateWorkoutView` closeout 해석이 모호함 | medium | high | current wiring evidence를 문서에 명확히 남기고 route 부재를 notes에 기록 |
| 한 surface를 닫기 위해 과도한 UX/assertion 범위를 끌어안음 | medium | medium | surface contract만 닫고 deeper workflow는 notes로 남긴다 |
| detached HEAD에서 바로 커밋을 시작함 | medium | high | Work setup 초기에 `codex/` 브랜치로 전환 후 진행 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: existing seeded regression 재사용 전략이 유효했고, build 통과 후 16-test subset에서 template handoff 1건만 남았다. 실패 screenshot/UI hierarchy로 `Barbell Squat` direct-session landing을 확인한 뒤 assertion을 수정했고, 최종 targeted rerun으로 template closeout까지 확인했다.
