---
topic: E2E Phase 2 Today Settings Closeout
date: 2026-03-16
status: draft
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase2-today-settings-regression.md
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
  - docs/solutions/testing/2026-03-09-e2e-done-todo-index-consolidation.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: E2E Phase 2 Today Settings Closeout

## Context

`docs/solutions/testing/2026-03-08-e2e-phase2-today-settings-regression.md`와 현재 코드 상태를 보면 Today/Settings phase 2 regression은 이미 구현돼 있다. `TodaySettingsRegressionTests`, `DashboardSmokeTests`, `SettingsSmokeTests`, `CloudSyncConsentRegressionTests`가 `DashboardView`, `ConditionScoreDetailView`, `MetricDetailView`, `AllDataView`, `WeatherDetailView`, `NotificationHubView`, `SettingsView`, `WhatsNewView`, `PinnedMetricsEditorView`, `CloudSyncConsentView` 진입점을 실제로 다루고 있다.

그런데 phase 0 backlog 문서는 아직 `022`~`031`을 `ready`로 유지하고 있어, open backlog와 실제 regression coverage가 어긋난다. 이번 작업은 이 정합성 문제를 해소하고, 필요한 최소 보정을 한 뒤 TODO/index/solution 흐름을 현재 코드 기준으로 맞추는 것이 목적이다.

## Requirements

### Functional

- `022`~`031` surface가 현재 코드와 테스트 기준으로 닫을 수 있는지 검증한다.
- coverage가 충분하면 해당 TODO를 `done`으로 전환하고 open/completed index를 동기화한다.
- coverage나 selector contract에 작은 누락이 있으면 최소 수정으로 보강한다.
- 각 `done` TODO에 entry route, regression lane, deferred note를 현재 테스트 기준으로 남긴다.

### Non-functional

- 기존 Today/Settings regression suite 구조를 유지한다.
- selector는 Apple guidance대로 `.accessibilityIdentifier(...)` 기반으로 유지하고 텍스트 selector 의존을 늘리지 않는다.
- 컨테이너 accessibility behavior는 child hit-testing을 깨지 않는 선에서만 조정한다.
- 변경은 phase 2 closeout 범위에 한정하고 `032` 이후 backlog는 건드리지 않는다.

## Approach

기존 구현을 재사용하는 closeout 배치로 처리한다.

1. phase 2 관련 tests/docs/code를 재검토해 `022`~`031` coverage 매핑을 만든다.
2. verification 실행으로 현재 regression이 여전히 유효한지 확인한다.
3. 누락이 있으면 AXID 또는 test assertion만 최소 수정한다.
4. `022`~`031` TODO를 `done`으로 rename/update 하고, `101` open backlog와 `107` completed index를 동기화한다.
5. compound 단계에서 이번 정합성 복구 패턴을 별도 solution 문서로 남긴다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `022`부터 하나씩 별도 run으로 다시 구현 | TODO 순서를 엄격히 따름 | 이미 구현된 regression을 중복 작업하게 됨 | 기각 |
| TODO 파일만 바로 `done` 처리 | 가장 빠름 | 현재 coverage가 깨졌는지 확인하지 못함 | 기각 |
| phase 2 전체를 검증 후 closeout | 기존 구현 재사용, backlog 정합성 복구, 위험 낮음 | 문서 정리 변경 비중이 높음 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-16-e2e-phase2-today-settings-closeout.md` | add | 이번 closeout 계획서 |
| `DUNEUITests/Full/TodaySettingsRegressionTests.swift` | verify/update | Today/Settings full regression contract 확인, 필요 시 최소 보정 |
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` | verify/update | PR gate smoke contract 확인, 필요 시 최소 보정 |
| `DUNEUITests/Smoke/SettingsSmokeTests.swift` | verify/update | Settings smoke coverage 확인 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | verify/update | AXID contract가 TODO closeout 범위와 일치하는지 확인 |
| `todos/022-*.md` ~ `todos/031-*.md` | move/modify | `ready` → `done`, 현재 regression lane/notes 반영 |
| `todos/101-ready-p2-e2e-phase0-page-backlog-index.md` | modify | `022`~`031` 제거 |
| `todos/107-done-p2-e2e-phase0-completed-surface-index.md` | modify | `022`~`031` 추가 |
| `docs/solutions/testing/2026-03-16-e2e-phase2-today-settings-closeout.md` | add | backlog 정합성 복구 패턴 문서화 |

## Implementation Steps

### Step 1: Coverage-to-TODO 매핑 확정

- **Files**: `docs/solutions/testing/2026-03-08-e2e-phase2-today-settings-regression.md`, `DUNEUITests/Full/TodaySettingsRegressionTests.swift`, `DUNEUITests/Smoke/DashboardSmokeTests.swift`, `DUNEUITests/Smoke/SettingsSmokeTests.swift`, `todos/022-*.md` ~ `todos/031-*.md`
- **Changes**:
  - 각 TODO가 어느 test/AX surface로 닫히는지 표로 정리한다.
  - 현재 suite가 닫지 못하는 surface가 있는지 식별한다.
- **Verification**:
  - `022`~`031` 각각에 대응하는 regression evidence가 문서로 설명 가능하다.

### Step 2: Regression / AX contract 최소 보정

- **Files**: `DUNEUITests/Full/TodaySettingsRegressionTests.swift`, `DUNEUITests/Smoke/DashboardSmokeTests.swift`, `DUNEUITests/Smoke/SettingsSmokeTests.swift`, `DUNEUITests/Helpers/UITestHelpers.swift`, 필요 시 Today/Settings presentation files
- **Changes**:
  - verification 중 드러난 selector 누락, destination assertion 누락, flaky text selector를 최소 수정한다.
  - Apple guidance에 맞춰 `.accessibilityIdentifier`를 우선 사용하고, container accessibility 조정은 child interaction을 보존하는 범위로 제한한다.
- **Verification**:
  - `scripts/test-ui.sh --only-testing DUNEUITests/Smoke/DashboardSmokeTests`
  - `scripts/test-ui.sh --only-testing DUNEUITests/Smoke/SettingsSmokeTests`
  - `scripts/test-ui.sh --test-plan DUNEUITests-Full --only-testing DUNEUITests/Full/TodaySettingsRegressionTests`

### Step 3: TODO / Index closeout

- **Files**: `todos/022-*.md` ~ `todos/031-*.md`, `todos/101-ready-p2-e2e-phase0-page-backlog-index.md`, `todos/107-done-p2-e2e-phase0-completed-surface-index.md`
- **Changes**:
  - `022`~`031` TODO를 `done`으로 rename하고 `updated` 날짜를 갱신한다.
  - 각 TODO note에 current entry route, PR gate/nightly lane, deferred lane을 현재 테스트 기준으로 기록한다.
  - `101`에서 해당 항목을 제거하고 `107`에 추가한다.
- **Verification**:
  - `rg -n "022-|023-|024-|025-|026-|027-|028-|029-|030-|031-" todos/101-ready-p2-e2e-phase0-page-backlog-index.md todos/107-done-p2-e2e-phase0-completed-surface-index.md todos`

## Edge Cases

| Case | Handling |
|------|----------|
| surface는 열리지만 dedicated regression이 아닌 smoke만 존재 | TODO note에 PR gate vs nightly lane 경계를 명시하고, 현 scope에서 닫을 수 있는지 근거를 남긴다 |
| TODO note의 future/specialized scope가 남아 있음 | `deferred` 또는 specialized follow-up으로 note에 남기고 surface-level TODO는 닫는다 |
| 일부 route가 text selector fallback에 기대고 있음 | 가능하면 AXID로 치환하고, 불가피하면 en locale 고정 근거를 남긴다 |
| test는 존재하지만 open backlog index와 done index가 중복 링크를 가짐 | active index에서 제거 후 completed index만 source of truth로 유지한다 |

## Testing Strategy

- Unit tests:
  - 없음. 이번 배치는 UI regression / backlog 정합성 closeout이 중심이다.
- Integration tests:
  - `scripts/test-ui.sh --only-testing DUNEUITests/Smoke/DashboardSmokeTests`
  - `scripts/test-ui.sh --only-testing DUNEUITests/Smoke/SettingsSmokeTests`
  - `scripts/test-ui.sh --test-plan DUNEUITests-Full --only-testing DUNEUITests/Full/TodaySettingsRegressionTests`
- Manual verification:
  - `rg -n "022-|023-|024-|025-|026-|027-|028-|029-|030-|031-" todos`
  - `ls -la docs/plans/`

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| existing UI regression이 현재 브랜치 기준으로 깨져 있어 closeout이 막힘 | Medium | High | 먼저 failing selector/fixture만 최소 수정하고 재검증 |
| surface-level TODO와 deeper follow-up scope를 혼동해 과도하게 닫음 | Medium | Medium | note에 deferred lane을 명시하고 surface contract 기준으로만 판단 |
| index rename이 많은 TODO 파일 변경과 충돌 | Low | Medium | `022`~`031`만 한정해서 순차 rename하고 rg로 링크를 검증 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: phase 2 구현/solution/test가 이미 저장소에 존재하고, open backlog와 실제 상태의 불일치가 핵심 문제다. 필요한 작업은 coverage 재검증과 문서/인덱스 정합화가 중심이라 범위가 명확하고 위험이 낮다.
