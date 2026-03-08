---
topic: ui-smoke-toolbar-tap-stability
date: 2026-03-08
status: draft
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-03-ipad-activity-tab-ui-test-navigation-stability.md
  - docs/solutions/testing/2026-03-04-ui-test-max-hardening-and-axid-stability.md
  - docs/solutions/testing/ui-test-infrastructure-design.md
  - docs/solutions/general/2026-03-07-whats-new-toolbar-tipkit-entrypoint.md
related_brainstorms:
  - docs/brainstorms/2026-03-02-ui-test-nightly-hardening.md
---

# Implementation Plan: UI Smoke Toolbar Tap Stability

## Context
GitHub Actions run `22813985954`의 `ios-ui-tests` job에서 `Activity`, `Dashboard`, `Life` smoke 테스트가 연쇄 실패했다. 첫 실패는 각 탭의 root toolbar action을 여는 테스트에서 발생했고, 이후 앱 terminate/launch timeout이 뒤따라 나머지 테스트가 무너졌다.

로그와 현재 코드 기준으로 보면 앱 로직 자체보다 UI test가 `ToolbarItem` AXID를 `descendants(matching: .any)`로 찾아 탭하는 경로가 CI에서 불안정해진 가능성이 높다. 실제 toolbar 버튼들은 모두 `Button`에 직접 AXID가 부여되어 있으므로, 테스트는 wrapper가 아닌 실제 button element를 우선 탭하도록 정리하는 편이 안전하다.

## Requirements

### Functional
- Activity, Dashboard, Life smoke 테스트의 toolbar action open flow를 안정화한다.
- 공통 UI test helper에서 AXID 기반 interactive element 탐색/탭 경로를 재사용 가능하게 만든다.
- 기존 smoke 테스트의 검증 의도(화면 열림, sheet 표시, dismiss)는 유지한다.

### Non-functional
- 앱 production 코드 변경은 최소화하거나 생략한다.
- iPhone smoke 기준에서 flaky selector를 줄이고 CI timeout 가능성을 낮춘다.
- 기존 AXID naming / UI test helper 패턴과 일관성을 유지한다.

## Approach
`DUNEUITests/Helpers/UITestHelpers.swift`에 AXID 기반 interactive element를 찾고 탭하는 경량 helper를 추가한다. helper는 `app.buttons[identifier]`를 최우선으로 보고, 필요 시 기존 generic descendant 경로로 fallback한다.

그 다음, CI에서 실패한 smoke 테스트들과 `navigateToSettings()` 같은 공통 진입점을 helper로 전환한다. 이렇게 하면 toolbar wrapper ambiguity를 줄이면서도 테스트 목적은 그대로 유지할 수 있다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 앱 쪽 toolbar/sheet 구조 변경 | 근본 UX 구조를 손볼 수 있음 | 현재 앱 회귀 근거가 약하고 범위가 커짐 | 기각 |
| 실패 테스트별 개별 selector 수정 | 가장 빠른 국소 수정 | 패턴 중복이 남고 같은 문제가 재발하기 쉬움 | 부분 채택 |
| 공통 helper 추가 + 실패 테스트 일괄 전환 | 범위가 작고 재발 방지 효과가 큼 | helper 설계가 과하면 불필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEUITests/Helpers/UITestHelpers.swift` | modify | AXID 기반 button-first tap helper 추가 |
| `DUNEUITests/Helpers/UITestBaseCase.swift` | modify | 공통 navigation helper에서 새 tap helper 사용 |
| `DUNEUITests/Smoke/ActivitySmokeTests.swift` | modify | toolbar add open flow를 안정 경로로 전환 |
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` | modify | settings / what's new / notifications toolbar tap 안정화 |
| `DUNEUITests/Smoke/LifeSmokeTests.swift` | modify | habit form open flow의 toolbar tap 안정화 |

## Implementation Steps

### Step 1: 공통 AXID tap helper 추가

- **Files**: `DUNEUITests/Helpers/UITestHelpers.swift`
- **Changes**:
  - AXID로 interactive element를 찾을 때 `buttons[identifier]`를 우선하는 helper 추가
  - 필요 시 generic descendant fallback 유지
  - helper가 `waitForExistence` + `tap` semantics를 한 번에 제공하도록 정리
- **Verification**:
  - helper를 사용하는 테스트가 compile 되는지 확인
  - button AXID가 있는 toolbar/action element에서 helper가 정상 동작하는지 focused UI test로 확인

### Step 2: 실패 smoke 테스트를 helper로 전환

- **Files**: `DUNEUITests/Helpers/UITestBaseCase.swift`, `DUNEUITests/Smoke/ActivitySmokeTests.swift`, `DUNEUITests/Smoke/DashboardSmokeTests.swift`, `DUNEUITests/Smoke/LifeSmokeTests.swift`
- **Changes**:
  - Activity add, Dashboard toolbar actions, Life add button tap을 helper 기반으로 교체
  - `navigateToSettings()`도 동일 helper를 사용해 중복 selector를 줄임
- **Verification**:
  - `LifeSmokeTests/testHabitFormOpens`
  - `ActivitySmokeTests/testExercisePickerOpens`
  - `DashboardSmokeTests/testNavigateToSettings`
  - `DashboardSmokeTests/testNavigateToWhatsNew`

### Step 3: smoke 회귀 확인 및 baseline 정리

- **Files**: 변경 없음 또는 재현 중 생성된 project artifacts만 정리
- **Changes**:
  - focused smoke tests 재실행
  - 가능하면 smoke subset 또는 전체 smoke 재실행
  - 재현 중 생성된 baseline dirty 파일을 ship 대상에서 제외
- **Verification**:
  - 변경 파일만 남는지 `git status`로 확인
  - 실행한 테스트 결과를 기록

## Edge Cases

| Case | Handling |
|------|----------|
| AXID가 실제로 button이 아닌 wrapper에만 붙은 경우 | helper에서 generic descendant fallback 유지 |
| toolbar button이 존재하지만 hittable 전환이 느린 경우 | `buttons[identifier]` 우선 탐색으로 wrapper snapshot 비용 감소 기대 |
| CI와 로컬 simulator OS minor 버전 차이 | 로컬 focused test + smoke subset으로 동작 확인 후 CI 안정화 목적 수정으로 제한 |
| 재현 명령이 project regeneration을 유발해 worktree가 더러워지는 경우 | baseline으로 분리하고 최종 커밋/ship 대상에서 제외 |

## Testing Strategy
- Unit tests: 없음 (UI test helper 변경)
- Integration tests: 없음
- Manual verification:
  - `scripts/test-ui.sh --stream-log --smoke --only-testing DUNEUITests/LifeSmokeTests/testHabitFormOpens`
  - `scripts/test-ui.sh --stream-log --smoke --only-testing DUNEUITests/ActivitySmokeTests/testExercisePickerOpens`
  - `scripts/test-ui.sh --stream-log --smoke --only-testing DUNEUITests/DashboardSmokeTests/testNavigateToSettings`
  - 필요 시 smoke suite 재실행

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| helper가 특정 control type만 가정해 다른 AXID tap을 깨뜨릴 수 있음 | medium | medium | fallback 경로 유지, 변경 범위는 실패 테스트 중심으로 제한 |
| 실제 원인이 app-side performance stall일 수 있음 | low | high | focused smoke 재현 결과와 CI failure clustering으로 재검증 |
| test runner가 regen으로 project 파일을 수정함 | high | low | baseline dirty 파일을 기록하고 최종 정리에서 제외 |

## Confidence Assessment
- **Overall**: High
- **Reasoning**: 실패가 여러 탭의 toolbar action open flow에 집중되어 있고, 현재 앱 코드는 단순 button state toggle인데 테스트 쿼리만 generic wrapper 경로를 쓰고 있다. button-first helper로 바꾸는 수정은 범위가 작고 재발 방지 효과가 크다.
