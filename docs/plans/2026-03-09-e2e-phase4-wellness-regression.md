---
topic: E2E Phase 4 Wellness Regression
date: 2026-03-09
status: draft
confidence: medium
related_solutions:
  - docs/solutions/testing/ui-test-infrastructure-design.md
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
  - docs/solutions/testing/2026-03-08-e2e-phase2-today-settings-regression.md
  - docs/solutions/testing/2026-03-08-e2e-phase3-activity-exercise-regression-hardening.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: E2E Phase 4 Wellness Regression

## Context

`docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md`의 다음 구현 단계는 `DUNE Wellness` 회귀 세트다.
현재 저장소에는 `WellnessSmokeTests`와 metric detail chart regression 일부가 존재하지만, wellness hero detail, body/injury history route, statistics route, add/edit save 흐름은 full regression lane에 아직 고정되지 않았다.

Phase 2/3에서 launch/reset/seed와 AXID-driven full regression 패턴은 이미 정리됐다.
이번 단계는 `defaultSeeded` fixture를 재사용해 Wellness의 navigable surface와 body/injury CRUD 핵심 happy path를 deterministic하게 묶는 것이 목적이다.

## Requirements

### Functional

- `defaultSeeded` launch에서 `WellnessView`의 핵심 surface가 안정적으로 렌더링돼야 한다.
  - wellness hero
  - physical / active indicator section
  - injury section
  - body history link
- `WellnessView`에서 다음 주요 route를 full regression으로 검증할 수 있어야 한다.
  - hero -> `WellnessScoreDetailView`
  - physical/active indicator card -> `MetricDetailView`
  - `MetricDetailView` -> `AllDataView`
  - body history link -> `BodyHistoryDetailView`
  - injury history link -> `InjuryHistoryView`
  - injury history toolbar -> `InjuryStatisticsView`
- body flow에서 다음 핵심 경로를 검증할 수 있어야 한다.
  - add menu -> body form
  - body form required/invalid-state gating
  - body add save
  - body history row -> edit form -> save
- injury flow에서 다음 핵심 경로를 검증할 수 있어야 한다.
  - add menu -> injury form
  - recovered toggle -> end date visibility
  - injury add save
  - injury history/detail -> edit form -> save
- Phase 4 backlog surface TODO(`065`~`071`)가 이번 구현 범위와 맞게 갱신돼야 한다.

### Non-functional

- 기존 `defaultSeeded` 기반 Today/Activity/Life smoke 및 regression을 깨뜨리지 않아야 한다.
- screen-level AXID는 상호작용 root가 아닌 안정 anchor에만 부여해야 한다.
- iPhone/iPad 공통으로 AXID 우선 selector를 유지해야 한다.
- HealthKit 비가용 시뮬레이터에서도 deterministic하게 실행돼야 한다.

## Approach

Phase 4는 `existing defaultSeeded reuse + Wellness surface AXID 활성화 + full regression suite 추가` 조합으로 구현한다.

1. 새로운 seeded scenario는 만들지 않고, 이미 있는 `defaultSeeded` body/injury fixture를 그대로 사용한다.
2. `UITestHelpers`에 planned 상태로 있던 Wellness selector를 실제 view/detail/form/action surface에 연결한다.
3. `DUNEUITests/Full/WellnessRegressionTests.swift`를 추가해 hero/detail/history/form/edit flow를 full lane으로 고정한다.
4. 삭제처럼 flaky 가능성이 높은 action은 이번 batch에서 route 계약만 준비하고, full destructive path는 후속 TODO로 남긴다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `defaultSeeded`를 그대로 두고 label 기반 테스트만 추가 | 앱 코드 변경이 적음 | locale/iPad 차이에 취약하고 planned AXID debt가 남음 | 기각 |
| Wellness 전용 seeded scenario 추가 | fixture를 더 세밀하게 제어 가능 | 현재 default seed로 충분한데 scenario 관리 복잡도만 증가 | 기각 |
| default seed 재사용 + missing AXID만 활성화 + full regression 추가 | 범위를 작게 유지하면서 deterministic route 확보 가능 | edit flow용 row/action selector를 일부 추가해야 함 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-09-e2e-phase4-wellness-regression.md` | add | 이번 작업의 구현 계획서 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | update | Wellness full regression용 AXID constants 추가 |
| `DUNE/Presentation/Wellness/WellnessView.swift` | update | planned Wellness section/link AXID 활성화 |
| `DUNE/Presentation/Wellness/WellnessScoreDetailView.swift` | update | detail screen anchor 추가 |
| `DUNE/Presentation/Wellness/BodyHistoryDetailView.swift` | update | history screen/row/action anchor 추가 |
| `DUNE/Presentation/BodyComposition/BodyCompositionFormSheet.swift` | update | form screen anchor 추가 |
| `DUNE/Presentation/Injury/InjuryHistoryView.swift` | update | history/statistics/detail/action anchor 추가 |
| `DUNE/Presentation/Injury/InjuryFormSheet.swift` | update | form screen anchor 추가 |
| `DUNE/Presentation/Injury/InjuryStatisticsView.swift` | update | statistics screen anchor 추가 |
| `DUNEUITests/Full/WellnessRegressionTests.swift` | add | Wellness full regression suite |
| `todos/065-ready-p2-e2e-dune-wellness-view.md` | update/rename | Wellness root backlog 상태 갱신 |
| `todos/066-ready-p2-e2e-dune-wellness-score-detail-view.md` | update/rename | hero detail backlog 상태 갱신 |
| `todos/067-ready-p2-e2e-dune-body-history-detail-view.md` | update/rename | body history backlog 상태 갱신 |
| `todos/068-ready-p2-e2e-dune-injury-history-view.md` | update/rename | injury history backlog 상태 갱신 |
| `todos/069-ready-p2-e2e-dune-injury-statistics-view.md` | update/rename | statistics backlog 상태 갱신 |
| `todos/070-ready-p2-e2e-dune-body-composition-form-sheet.md` | update/rename | body form backlog 상태 갱신 |
| `todos/071-ready-p2-e2e-dune-injury-form-sheet.md` | update/rename | injury form backlog 상태 갱신 |

## Implementation Steps

### Step 1: Wellness surface selector contract 보강

- **Files**: `DUNEUITests/Helpers/UITestHelpers.swift`, `DUNE/Presentation/Wellness/WellnessView.swift`, `DUNE/Presentation/Wellness/WellnessScoreDetailView.swift`, `DUNE/Presentation/Wellness/BodyHistoryDetailView.swift`, `DUNE/Presentation/Injury/InjuryHistoryView.swift`, `DUNE/Presentation/Injury/InjuryStatisticsView.swift`, `DUNE/Presentation/BodyComposition/BodyCompositionFormSheet.swift`, `DUNE/Presentation/Injury/InjuryFormSheet.swift`
- **Changes**:
  - wellness section/link identifiers를 planned에서 active 상태로 전환한다.
  - detail/history/statistics/form 화면에 screen anchor를 추가한다.
  - body/injury row 및 edit/stats action에 locale-safe selector를 추가한다.
- **Verification**:
  - full regression이 visible label 대신 AXID 중심으로 Wellness route를 탐색할 수 있다.
  - screen anchor가 child CTA를 가리지 않는다.

### Step 2: Wellness full regression suite 작성

- **Files**: `DUNEUITests/Full/WellnessRegressionTests.swift`
- **Changes**:
  - hero/detail/all-data/body history/injury history/statistics route를 seeded flow로 검증한다.
  - body add/edit, injury add/edit/recovered toggle 경로를 regression으로 고정한다.
  - destructive delete flow는 제외하고, route/edit/save 중심으로 범위를 제한한다.
- **Verification**:
  - `scripts/test-ui.sh --test-plan DUNEUITests-Full --only-testing DUNEUITests/Full/WellnessRegressionTests`

### Step 3: TODO/solution 상태 정리

- **Files**: `todos/065...071`, `docs/solutions/testing/YYYY-MM-DD-e2e-phase4-wellness-regression.md`
- **Changes**:
  - 이번 batch에서 닫힌 surface TODO를 `done`으로 전환하고 notes를 최신 범위로 맞춘다.
  - body/injury delete가 후속 범위라면 solution과 TODO notes에 명시한다.
- **Verification**:
  - TODO 파일명/status/frontmatter가 일치한다.
  - solution 문서가 실제 구현 범위를 반영한다.

## Edge Cases

| Case | Handling |
|------|----------|
| screen-level AXID가 form/save button을 가리는 문제 | root container가 아니라 header/anchor surface에만 screen id를 둔다 |
| BodyHistory에 HealthKit row가 섞여 첫 row가 manual이 아닐 수 있음 | manual row 전용 AXID를 추가해 edit 대상 row를 직접 찾는다 |
| Injury validation은 UI에서 invalid state를 직접 만들기 어려움 | recovered toggle/end-date visibility와 save/edit path를 UI lane으로 고정하고 date-range validation은 existing ViewModel tests에 맡긴다 |
| iPad에서 toolbar/menu/list 구조가 달라질 수 있음 | 기존 shared helper와 AXID를 재사용하고 tap target을 identifier로 고정한다 |
| delete flow가 confirmation/context menu 타이밍 때문에 flaky | 이번 batch에서는 edit/save 중심으로 닫고 delete는 후속 TODO note로 남긴다 |

## Testing Strategy

- Unit tests:
  - 추가 없음. injury/body validation은 existing `BodyCompositionViewModelTests`, `InjuryViewModelTests`가 이미 담당한다.
- Integration tests:
  - `scripts/test-ui.sh --test-plan DUNEUITests-Full --only-testing DUNEUITests/Full/WellnessRegressionTests`
  - `scripts/test-ui.sh --smoke --only-testing DUNEUITests/Smoke/WellnessSmokeTests`
- Manual verification:
  - seeded launch에서 Wellness tab hero/body history/injury history 렌더링 확인
  - body/injury edit sheet dismissal과 statistics route 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| body context menu edit path가 simulator에서 flaky | Medium | Medium | row/action AXID를 추가하고 long-press 단계를 helper 수준으로 최소화 |
| wellness screen anchor 추가가 기존 smoke selector와 충돌 | Low | Medium | hero/add menu 기존 id는 유지하고 새 id만 additive하게 넣는다 |
| default seeded data가 테스트 기대와 어긋남 | Low | Medium | existing seed contract를 바꾸지 않고 route assertion을 현재 fixture에 맞춘다 |
| TODO를 과도하게 닫아 delete 미구현 범위를 숨김 | Low | Medium | solution/TODO note에 delete follow-up을 명시한다 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: Wellness는 seeded data가 이미 있고 smoke도 존재해 기반은 충분하다. 다만 body edit가 context menu 기반이고 injury route가 history/detail/statistics로 나뉘어 있어, selector contract를 잘못 두면 Phase 3와 같은 AXID masking/flakiness가 다시 생길 수 있다.
