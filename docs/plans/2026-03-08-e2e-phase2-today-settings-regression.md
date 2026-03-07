---
topic: E2E Phase 2 Today Settings Regression
date: 2026-03-08
status: draft
confidence: high
related_solutions:
  - docs/solutions/testing/ui-test-infrastructure-design.md
  - docs/solutions/testing/2026-03-04-pr-fast-gate-and-nightly-regression-split.md
  - docs/solutions/testing/2026-03-03-ipad-activity-tab-ui-test-navigation-stability.md
  - docs/solutions/testing/2026-02-27-tab-reselect-scroll-regression-ui-test.md
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: E2E Phase 2 Today Settings Regression

## Context

`docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md`의 Phase 2는 `Today / Settings` 표면을 PR gate와 nightly full regression에 연결하는 단계다. 현재 저장소에는 `DashboardSmokeTests`, `SettingsSmokeTests`, `What's New` detail smoke가 일부 존재하지만, seeded `Today` 상태가 없어 hero / metric / weather / pinned flow를 deterministic하게 열 수 없고, `NotificationHubView`의 empty vs seeded 상태와 `CloudSyncConsentView`는 자동 진입 훅이 없다.

이번 작업은 Phase 1 인프라 위에서 `Today / Settings` 전체 핵심 플로우를 실제 regression suite로 연결하는 것이 목적이다.

## Requirements

### Functional

- `defaultSeeded` UI launch가 `Today` hero, pinned metrics, notification hub control, weather card를 안정적으로 렌더링해야 한다.
- `DashboardView`에서 다음 흐름을 UI test로 검증할 수 있어야 한다.
  - Today root render
  - Today tab reselection scroll-to-top
  - condition hero -> `ConditionScoreDetailView`
  - metric card -> `MetricDetailView`
  - `MetricDetailView` -> `AllDataView`
  - weather card -> `WeatherDetailView`
  - pinned edit -> `PinnedMetricsEditorView`
- `NotificationHubView`에서 empty state와 seeded controls(`Read All`, `Delete All`, settings entry)를 분리 검증할 수 있어야 한다.
- `SettingsView`에서 Phase 2 backlog에 적힌 주요 row와 하위 route(`Exercise Defaults`, `Preferred Exercises`, `What's New`)를 full regression으로 검증할 수 있어야 한다.
- `CloudSyncConsentView`는 후속 specialized lane 전에 진입 가능한 UI test hook을 가져야 한다.

### Non-functional

- PR smoke 범위는 기존 빠른 gate 성격을 유지해야 한다.
- 새 fixture와 test hook은 UI test launch argument가 있을 때만 활성화되어 production path에 영향을 주지 않아야 한다.
- iPhone/iPad 모두 같은 AXID 기반 selector로 동작해야 한다.
- 기존 `Activity`, `Wellness`, `Life` smoke 동작을 깨뜨리지 않아야 한다.

## Approach

Phase 2는 "깊은 flow를 위한 seeded harness 확장 + surface-specific AXID 보강 + full regression suite 추가" 조합으로 구현한다.

1. `defaultSeeded` 시나리오를 `Today / Settings`까지 커버하도록 확장한다.
   - shared health snapshot mirror record
   - deterministic weather fixture
   - notification inbox seeded/empty 상태
   - pinned metric defaults
   - relevant UserDefaults reset
2. `DashboardView`, detail views, pinned editor, settings routes에 AXID를 추가해 root / primary CTA / route assertion 포인트를 고정한다.
3. PR gate는 기존 `DashboardSmokeTests` 중심으로 유지하고, 상세 flow는 별도 full regression test 파일로 추가한다.
4. `CloudSyncConsentView`는 전용 launch argument로 강제 노출해 specialized TODO 전에 회귀 진입점을 마련한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 empty smoke만 확장 | 변경 범위가 작음 | hero / weather / notification control / pinned flow가 flaky하거나 검증 불가 | 기각 |
| 테스트에서 HealthKit 실제 데이터에 의존 | 앱 코드 수정이 적음 | 시뮬레이터/CI에서 결정성이 없고 Phase 2 목적과 충돌 | 기각 |
| Today용 별도 mock service graph를 앱 루트에서 전면 주입 | 가장 강한 제어 | 변경 범위가 커지고 현재 Phase 2 범위를 넘음 | 보류 |
| `defaultSeeded` fixture를 확장하고 필요한 곳만 launch hook 추가 | 결정성 확보와 범위 제어가 가능 | fixture 관리 코드가 늘어남 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-08-e2e-phase2-today-settings-regression.md` | add | 이번 작업의 구현 계획서 |
| `DUNE/App/TestDataSeeder.swift` | update | Today/Settings seeded fixture, notification seed, shared snapshot seed, cloud-consent hook support |
| `DUNE/App/DUNEApp.swift` | update | UI test defaults reset / cloud sync consent force-show wiring |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | update | weather/pinned/section/metric AXID 노출 |
| `DUNE/Presentation/Dashboard/ConditionScoreDetailView.swift` | update | detail root assertion ID 추가 |
| `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | update | detail root + show-all-data AXID 추가 |
| `DUNE/Presentation/Shared/Detail/AllDataView.swift` | update | all-data root/empty state AXID 추가 |
| `DUNE/Presentation/Dashboard/WeatherDetailView.swift` | update | weather detail root AXID 추가 |
| `DUNE/Presentation/Dashboard/Components/PinnedMetricsEditorView.swift` | update | editor root / done / cancel AXID 추가 |
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | update | hub root/seeded row assertion 보강 필요 시 적용 |
| `DUNE/Presentation/Shared/CloudSyncConsentView.swift` | update | consent view assertion ID 점검 및 보강 필요 시 적용 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | update | Today/Settings AXID constants + helper 확장 |
| `DUNEUITests/Helpers/UITestBaseCase.swift` | update | scenario / consent hook launch config 확장 필요 시 반영 |
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` | update | PR gate용 Today 핵심 route 검증 보강 |
| `DUNEUITests/Smoke/SettingsSmokeTests.swift` | update | full lane와 충돌 없이 Settings smoke 정리 |
| `DUNEUITests/Full/TodaySettingsRegressionTests.swift` | add | Today / Settings full regression suite |

## Implementation Steps

### Step 1: Today/Settings seeded fixture 고정

- **Files**: `DUNE/App/TestDataSeeder.swift`, `DUNE/App/DUNEApp.swift`
- **Changes**:
  - UI test reset 시 relevant UserDefaults(`TodayPinnedMetricsStore`, notification inbox, cloud consent, What's New opened state 등)를 deterministic하게 초기화한다.
  - `defaultSeeded`가 shared health snapshot mirror, notification inbox items, pinned categories를 seed하도록 확장한다.
  - `CloudSyncConsentView`를 강제로 띄우는 launch hook을 추가한다.
- **Verification**:
  - seeded launch에서 Today hero / weather / pinned edit / notifications가 보인다.
  - empty launch에서 notification hub empty state가 유지된다.
  - consent hook launch에서 `cloud-sync-consent-view`가 즉시 보인다.

### Step 2: Today/Settings surface selector 보강

- **Files**: `DUNE/Presentation/Dashboard/DashboardView.swift`, `DUNE/Presentation/Dashboard/ConditionScoreDetailView.swift`, `DUNE/Presentation/Shared/Detail/MetricDetailView.swift`, `DUNE/Presentation/Shared/Detail/AllDataView.swift`, `DUNE/Presentation/Dashboard/WeatherDetailView.swift`, `DUNE/Presentation/Dashboard/Components/PinnedMetricsEditorView.swift`, `DUNE/Presentation/Dashboard/NotificationHubView.swift`, `DUNEUITests/Helpers/UITestHelpers.swift`
- **Changes**:
  - dashboard weather card, metric card, section container, detail root, all-data link, pinned editor actions, notification hub root 등을 AXID로 노출한다.
  - 기존 planned AXID 중 Phase 2에 해당하는 항목을 active 상태로 전환한다.
- **Verification**:
  - UI tests가 visible text 의존 없이 Today / Settings 주요 흐름을 식별자만으로 탐색한다.
  - iPhone/iPad 공통 selector가 유지된다.

### Step 3: PR smoke + full regression suite 작성

- **Files**: `DUNEUITests/Smoke/DashboardSmokeTests.swift`, `DUNEUITests/Smoke/SettingsSmokeTests.swift`, `DUNEUITests/Full/TodaySettingsRegressionTests.swift`, `DUNEUITests/Helpers/UITestBaseCase.swift`
- **Changes**:
  - PR smoke에는 Today root, toolbar entry, seeded notification route 등 빠른 핵심 검증만 남긴다.
  - full regression에는 tab reselection scroll-to-top, condition detail, metric detail + all data, weather detail, notification empty/control states, settings rows/routes, pinned editor, cloud consent hook을 추가한다.
- **Verification**:
  - `scripts/test-ui.sh --only-testing DUNEUITests/Smoke/DashboardSmokeTests`
  - `scripts/test-ui.sh --test-plan DUNEUITests-Full --only-testing DUNEUITests/Full/TodaySettingsRegressionTests`

## Edge Cases

| Case | Handling |
|------|----------|
| HealthKit available simulator에서 Today가 실제 query path로 섞이는 문제 | shared snapshot seed + UI test-only fixture 경로로 deterministic state를 우선 제공 |
| Notification inbox / What's New 상태가 UserDefaults에 남아 테스트 간 오염 | `--ui-reset` 시 relevant keys를 명시적으로 초기화 |
| iPad에서 tab bar 대신 sidebar/floating tab가 보이는 경우 | 기존 `tab-*` AXID 기반 navigation helper를 유지하고 새 테스트도 동일 helper 사용 |
| `Show All Data`가 실제 데이터 없이 empty state로 열리는 경우 | route 진입 자체를 검증하고 empty state도 정상 surface로 인정 |
| cloud consent가 launch orchestration bypass 때문에 자동으로 뜨지 않는 경우 | 전용 force-show launch argument로 진입점 고정 |

## Testing Strategy

- Unit tests:
  - 필요 시 launch/reset helper의 분기 로직만 최소 단위로 보강
- Integration tests:
  - `scripts/test-ui.sh --only-testing DUNEUITests/Smoke/DashboardSmokeTests`
  - `scripts/test-ui.sh --only-testing DUNEUITests/Smoke/SettingsSmokeTests`
  - `scripts/test-ui.sh --test-plan DUNEUITests-Full --only-testing DUNEUITests/Full/TodaySettingsRegressionTests`
- Manual verification:
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNEUITests -showTestPlans`
  - seeded / empty / consent hook launch arguments 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| seeded fixture 확장으로 기존 smoke state가 달라짐 | Medium | High | 기존 `defaultSeeded` 소비 테스트를 재실행하고 fallback values를 보수적으로 유지 |
| UserDefaults reset이 과하거나 부족해서 launch flow가 달라짐 | Medium | Medium | UI test 관련 key만 제한적으로 reset하고 consent hook은 별도 arg로 분리 |
| weather fixture 경로가 production fetch와 충돌 | Low | Medium | UI test launch argument가 있을 때만 mock weather 사용 |
| full regression test가 PR smoke script에 unintentionally 포함 | Low | Medium | 새 파일을 별도 suite로 두고 smoke runner는 existing `only-testing` 집합을 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: Phase 1에서 launch/reset/test plan 기반은 이미 확보되어 있고, Phase 2의 핵심은 missing fixtures와 selector를 채운 뒤 route-oriented UI tests를 쌓는 작업이다. 가장 큰 리스크는 Today seeded state인데, shared snapshot + weather/notification fixture를 함께 넣으면 결정성을 확보할 수 있다.
