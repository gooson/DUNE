---
topic: E2E Phase 5 Life Regression
date: 2026-03-09
status: draft
confidence: medium
related_solutions:
  - docs/solutions/testing/ui-test-infrastructure-design.md
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
  - docs/solutions/testing/2026-03-08-e2e-phase2-today-settings-regression.md
  - docs/solutions/testing/2026-03-08-e2e-phase3-activity-exercise-regression-hardening.md
  - docs/solutions/testing/2026-03-09-e2e-phase4-wellness-regression.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: E2E Phase 5 Life Regression

## Context

`docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md`의 다음 must-have surface는 `LifeView`, `HabitFormSheet`, `HabitHistorySheet`다.
현재 저장소에는 `LifeSmokeTests`와 seeded smoke가 있어 root 렌더링, add form open/cancel, weekly frequency toggle, actions menu edit/archive 정도는 잡고 있다.
하지만 full regression lane에서 실제 사용자 경로로 묶인 suite는 아직 없고, history sheet는 screen-level AX contract가 없어 seeded history assertion을 안정적으로 작성하기 어렵다.

이번 단계의 목적은 `defaultSeeded` fixture를 재사용해 `Life` 핵심 root/form/history 흐름을 nightly full regression에 고정하고, stale 상태인 `072`~`074` backlog를 실제 구현 기준으로 정리하는 것이다.

## Requirements

### Functional

- `defaultSeeded` launch에서 `LifeView`의 핵심 surface가 안정적으로 렌더링돼야 한다.
  - completion hero
  - habits section
  - seeded habit actions entry
- `LifeView`에서 다음 주요 route를 full regression으로 검증할 수 있어야 한다.
  - `Life` root render
  - add toolbar -> `HabitFormSheet`
  - seeded habit actions -> `HabitHistorySheet`
- `HabitFormSheet`에서 다음 핵심 경로를 검증할 수 있어야 한다.
  - add flow save
  - edit flow open
  - frequency picker / validation smoke와 충돌하지 않는 persistence assertion
- `HabitHistorySheet`에서 다음 핵심 경로를 검증할 수 있어야 한다.
  - seeded history present state
  - empty history state
  - close/dismiss path
- `072`, `073`, `074` TODO가 이번 구현 범위와 맞게 `done`으로 갱신돼야 한다.

### Non-functional

- 기존 `LifeSmokeTests`와 `Today/Activity/Wellness` regression을 깨뜨리지 않아야 한다.
- screen-level AXID는 child CTA를 가리지 않는 안정 anchor에만 추가해야 한다.
- 테스트는 locale-safe selector를 우선 사용해야 한다.
- PR gate는 기존 smoke-only 범위를 유지하고, 새 경로는 nightly full lane에서 자동 포함돼야 한다.

## Approach

Phase 5는 `existing defaultSeeded reuse + Life history AXID 보강 + full regression suite 추가` 조합으로 구현한다.

1. 새로운 seeded scenario는 만들지 않고, 기존 `defaultSeeded`의 habits fixture를 그대로 사용한다.
2. `UITestHelpers`에 Life action/history selector를 확장하고, `HabitHistorySheet`에 필요한 screen/empty/row/close anchor를 추가한다.
3. `DUNEUITests/Full/LifeRegressionTests.swift`를 추가해 root render, add/save, edit entry, seeded history, empty history 경로를 묶는다.
4. CI lane은 기존 구성을 유지한다. PR은 `test-ui.yml`의 smoke set만 사용하고, nightly는 full plan이 `DUNEUITests` 전체를 실행하므로 새 suite가 자동 포함된다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 smoke만 확대 | 앱 코드 수정이 적음 | backlog의 full regression 목적과 history seeded assertion을 닫지 못함 | 기각 |
| Life 전용 seeded scenario 추가 | fixture 세밀 제어 가능 | 현재 fixture로 충분하고 scenario 관리 복잡도만 증가 | 기각 |
| default seed 재사용 + missing history AXID 추가 + full regression suite 작성 | 범위를 작게 유지하면서 route contract를 명확히 고정 가능 | private sheet 내부 anchor를 조심해서 추가해야 함 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-09-e2e-phase5-life-regression.md` | add | 이번 작업의 구현 계획서 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | update | Life full regression용 AXID constants 추가 |
| `DUNE/Presentation/Life/LifeView.swift` | update | `HabitHistorySheet` screen/row/empty/close anchor 추가 |
| `DUNEUITests/Full/LifeRegressionTests.swift` | add | Life root/form/history full regression suite |
| `todos/072-ready-p2-e2e-dune-life-view.md` | update/rename | Life root backlog 상태 갱신 |
| `todos/073-ready-p2-e2e-dune-habit-form-sheet.md` | update/rename | habit form backlog 상태 갱신 |
| `todos/074-ready-p2-e2e-dune-habit-history-sheet.md` | update/rename | habit history backlog 상태 갱신 |

## Implementation Steps

### Step 1: Life history selector contract 보강

- **Files**: `DUNEUITests/Helpers/UITestHelpers.swift`, `DUNE/Presentation/Life/LifeView.swift`
- **Changes**:
  - planned 상태였던 Life action/history selector를 상수로 고정한다.
  - `HabitHistorySheet`에 screen, empty state, close button, row prefix AXID를 추가한다.
- **Verification**:
  - seeded history sheet를 localized label 없이 AXID로 탐색할 수 있다.
  - screen anchor가 child button hit-testing을 가리지 않는다.

### Step 2: Life full regression suite 작성

- **Files**: `DUNEUITests/Full/LifeRegressionTests.swift`
- **Changes**:
  - root render, add/save, edit entry, seeded history, empty history 경로를 real user flow 기준으로 추가한다.
  - destructive archive path는 기존 smoke에 맡기고, 이번 batch는 add/history 중심으로 제한한다.
- **Verification**:
  - `scripts/test-ui.sh --test-plan DUNEUITests-Full --only-testing DUNEUITests/LifeRegressionTests`

### Step 3: TODO/solution 상태 정리

- **Files**: `todos/072...074`, `docs/solutions/testing/YYYY-MM-DD-e2e-phase5-life-regression.md`
- **Changes**:
  - 이번 batch에서 닫힌 surface TODO를 `done`으로 전환한다.
  - PR gate는 smoke 유지, nightly full은 새 suite 자동 포함이라는 lane 결정을 문서에 남긴다.
- **Verification**:
  - TODO 파일명/status/frontmatter가 일치한다.
  - solution 문서가 실제 구현 범위를 반영한다.

## Edge Cases

| Case | Handling |
|------|----------|
| history sheet root에 AXID를 잘못 두어 close 버튼 selector가 가려지는 문제 | root 전체가 아니라 별도 비인터랙티브 anchor를 둔다 |
| seeded habit마다 history 유무가 다름 | `Morning Stretch`는 populated history, `Read`는 empty history로 역할을 분리한다 |
| add flow 저장 직후 list re-query 타이밍이 늦는 문제 | sheet dismiss 후 새 habit label 또는 actions button이 나타날 때까지 wait한다 |
| actions button identifier가 habit 이름을 포함해 공백/locale 영향이 생기는 문제 | seeded 고정 이름만 사용하고, 신규 habit은 화면 label로 존재를 확인한다 |
| PR gate에 새 full test가 실수로 포함되는 문제 | workflow 변경 없이 nightly full auto-include만 문서화한다 |

## Testing Strategy

- Unit tests:
  - 추가 없음. form validation과 log sync는 existing `LifeViewModelTests`가 담당한다.
- Integration tests:
  - `scripts/test-ui.sh --test-plan DUNEUITests-Full --only-testing DUNEUITests/LifeRegressionTests`
  - `scripts/test-ui.sh --smoke --only-testing DUNEUITests/LifeSmokeTests`
- Manual verification:
  - seeded launch에서 `Life` hero / habits section / actions menu 렌더링 확인
  - history sheet populated/empty 경로 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| history row selector 추가가 SwiftUI List 접근성 트리와 충돌 | Medium | Medium | row 단위에 additive identifier만 두고 layout/interaction은 유지한다 |
| add/save 흐름이 keyboard 또는 scroll 위치에 따라 flaky | Medium | Medium | existing helper + explicit waitForExistence 기반으로 작성한다 |
| seeded fixture가 향후 바뀌면 populated/empty history 가정이 깨짐 | Low | Medium | solution 문서에 fixture contract를 명시하고 selector는 habit name 기준으로 고정한다 |
| TODO를 072~074 모두 닫았는데 후속 destructive flow가 남는 문제 | Low | Low | notes에 archive/delete는 기존 smoke 범위 또는 follow-up으로 남긴다 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: Life surface는 이미 smoke와 default seed가 있어 기반이 좋다. 다만 `HabitHistorySheet`가 private sheet이고 현재 AX contract가 비어 있어, anchor를 잘못 두면 selector masking이 다시 생길 수 있다. 이를 additive anchor로 제한하면 리스크는 관리 가능하다.
