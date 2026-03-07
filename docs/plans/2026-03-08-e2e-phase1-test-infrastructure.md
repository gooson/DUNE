---
topic: E2E Phase 1 Test Infrastructure
date: 2026-03-08
status: draft
confidence: high
related_solutions:
  - docs/solutions/testing/ui-test-infrastructure-design.md
  - docs/solutions/testing/2026-03-04-pr-fast-gate-and-nightly-regression-split.md
  - docs/solutions/testing/2026-03-02-watch-ui-test-coverage-expansion.md
  - docs/solutions/testing/2026-03-03-ipad-activity-tab-ui-test-navigation-stability.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: E2E Phase 1 Test Infrastructure

## Context

`docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md`의 Phase 1은 E2E 확장을 위한 공통 테스트 인프라를 먼저 고정하는 단계다. 현재 저장소에는 `UITestBaseCase`, `WatchUITestBaseCase`, `--seed-mock`, smoke suite, CI 전용 test plan이 이미 존재한다. 하지만 테스트 런치 상태를 일관되게 reset하는 경로, scenario별 seed 확장 포인트, watch session 전용 helper, 공통 UI interaction helper, PR/full 회귀 lane용 명시적 test plan 분리는 아직 부족하다.

이번 작업은 Phase 2 이후의 페이지/플로우 테스트를 빠르게 쌓을 수 있도록, iOS와 watchOS UI 테스트의 기반 레이어를 재정비하는 데 목적이 있다.

## Requirements

### Functional

- iOS UI tests가 `reset`, `seed`, `scenario`를 공통 API로 지정해 앱을 deterministic하게 launch할 수 있어야 한다.
- watch UI tests도 동일하게 `reset`, `seed`, `scenario` 기반 launch helper를 가져야 한다.
- 앱 런타임이 `--ui-reset`, `--seed-mock`, `--ui-scenario`를 해석해 Phase 2 이후 seeded/empty/flow 시나리오 확장을 받을 수 있어야 한다.
- SwiftData mock seeding이 scenario-aware 구조로 정리되어야 한다.
- 재사용 가능한 UI helper가 공통 위치에 모여야 한다.
- iOS/watch 모두 PR gate와 Full regression을 분리하는 test plan 파일이 있어야 한다.

### Non-functional

- 기존 smoke suite 동작을 깨지 않아야 한다.
- production path 영향은 UI test launch argument가 있을 때로 제한해야 한다.
- 구현은 Phase 2 테스트 작성 전에 바로 재사용 가능한 수준으로 유지해야 한다.
- `scripts/test-ui.sh`, `scripts/test-watch-ui.sh`와 충돌하지 않아야 한다.

## Approach

기존 smoke 인프라를 교체하지 않고 확장한다. 핵심은 "테스트 상태 결정"을 공통 런치 설정으로 끌어올리는 것이다.

1. 테스트 코드 쪽에는 launch configuration helper를 추가해 reset/seed/scenario를 선언적으로 조합한다.
2. 앱 코드 쪽에는 lightweight launch argument parser를 추가해 in-memory container 사용 여부와 seeding scenario를 결정한다.
3. iOS `TestDataSeeder`와 watch fixture path는 `scenario` enum 기반으로 재구성해, 지금은 `defaultSeeded`/`empty` 정도만 제공하되 후속 Phase에서 시나리오를 쉽게 늘릴 수 있게 한다.
4. 반복적으로 흩어져 있던 scroll/sheet/form/screenshot helper를 공통 helper로 올린다.
5. test plan은 `PR`/`Full` naming으로 추가하되, 기존 CI plan은 호환성을 위해 유지하거나 alias 역할을 맡긴다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 `--uitesting`, `--seed-mock`만 유지하고 테스트 파일에서 개별 처리 | 변경 범위가 작음 | Phase 2부터 helper 중복과 상태 불안정이 다시 커짐 | 기각 |
| UI 테스트 전용 별도 app build/profile 도입 | 상태 격리 강력 | project/workflow 변경이 커지고 현재 Phase 1 범위를 넘음 | 기각 |
| `--ui-reset`에서 UserDefaults/SwiftData 전체를 강제 삭제 | 매우 강한 초기화 | AppStorage 초기화 순서와 production 경계가 복잡해짐 | 보류 |
| `--ui-reset`을 in-memory persistence 중심으로 해석하고 scenario-aware seeding만 추가 | 안전하고 확장 가능 | 일부 UserDefaults 기반 상태는 후속 보강이 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-08-e2e-phase1-test-infrastructure.md` | add | 이번 작업의 구현 계획서 |
| `DUNEUITests/Helpers/UITestBaseCase.swift` | update | iOS launch/reset/seed/scenario helper 확장 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | update | scroll/sidebar/sheet/form/screenshot helper 공통화 |
| `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift` | update | watch launch/reset/seed/scenario/session helper 추가 |
| `DUNE/App/DUNEApp.swift` | update | UI test launch configuration 해석 및 reset/scenario wiring |
| `DUNE/App/TestDataSeeder.swift` | update | scenario-aware fixture seeding 구조 추가 |
| `DUNEWatch/DUNEWatchApp.swift` | update | watch test reset/configuration wiring 추가 |
| `DUNEWatch/WatchConnectivityManager.swift` | update | watch scenario-aware UI test fixture path 추가 |
| `DUNE/project.yml` | update | UI test scheme에 PR/Full test plan 연결 |
| `DUNEUITests/*.xctestplan` | add/update | PR / Full test plan 분리 |
| `DUNEWatchUITests/*.xctestplan` | add/update | PR / Full test plan 분리 |
| `scripts/test-ui.sh` | update | 새 test plan naming/default 지원 |
| `scripts/test-watch-ui.sh` | update | 새 test plan naming/default 지원 |

## Implementation Steps

### Step 1: iOS/watch launch configuration 공통화

- **Files**: `DUNEUITests/Helpers/UITestBaseCase.swift`, `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift`, `DUNE/App/DUNEApp.swift`, `DUNEWatch/DUNEWatchApp.swift`
- **Changes**:
  - 테스트 base case에 `resetState`, `shouldSeedMockData`, `uiScenario` 등 override/launch builder를 추가한다.
  - 앱 쪽에 `--ui-reset`, `--seed-mock`, `--ui-scenario` 파서를 추가한다.
  - `--ui-reset`일 때 SwiftData는 in-memory configuration을 사용하도록 한다.
- **Verification**:
  - 기존 smoke tests가 base class 변경 후에도 동일하게 launch된다.
  - seeded test와 non-seeded test가 각자 원하는 launch argument 조합을 갖는다.

### Step 2: scenario-aware seeding 및 watch fixture 확장

- **Files**: `DUNE/App/TestDataSeeder.swift`, `DUNE/App/DUNEApp.swift`, `DUNEWatch/WatchConnectivityManager.swift`
- **Changes**:
  - `TestDataSeeder`에 scenario enum과 entrypoint를 추가한다.
  - 기본 seeded scenario와 empty scenario를 분리한다.
  - watch fixture path도 scenario enum 기반으로 정리하고 session-related future hook을 남긴다.
- **Verification**:
  - seeded base case에서 기존 Life seeded smoke가 계속 통과 가능한 fixture를 유지한다.
  - watch smoke suite가 기존 fixture exercise를 계속 찾을 수 있다.

### Step 3: reusable UI helper 공통화

- **Files**: `DUNEUITests/Helpers/UITestHelpers.swift`, `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift`, 필요한 smoke tests
- **Changes**:
  - iPad sidebar navigation helper, off-screen scroll helper, modal dismissal helper, form fill helper, screenshot attachment naming helper를 공통 helper로 추가한다.
  - `SettingsSmokeTests` 등 파일 내부 중복 helper는 공통 helper 사용으로 정리한다.
  - watch base에는 session launch helper와 interruption helper를 둔다.
- **Verification**:
  - 공통 helper로 기존 테스트가 그대로 읽히고 중복 코드가 줄어든다.
  - screenshot helper가 failure/debug attachment naming에 사용 가능하다.

### Step 4: PR / Full test plan 및 runner wiring

- **Files**: `DUNEUITests/UITests-CI.xctestplan`, `DUNEWatchUITests/WatchUITests-CI.xctestplan`, 신규 `DUNEUITests-PR.xctestplan`, `DUNEUITests-Full.xctestplan`, `DUNEWatchUITests-PR.xctestplan`, `DUNEWatchUITests-Full.xctestplan`, `scripts/test-ui.sh`, `scripts/test-watch-ui.sh`
- **Changes**:
  - iOS/watch 각각 PR / Full 명시적 test plan을 추가한다.
  - 기존 CI plan은 backward compatibility를 위해 유지하거나 PR plan과 동일 내용으로 정렬한다.
  - runner script가 새 plan 이름을 받거나 기본 plan alias를 이해하게 조정한다.
- **Verification**:
  - `xcodebuild` 또는 runner script로 PR/Full plan 이름이 resolve된다.
  - smoke mode와 full mode가 서로 충돌하지 않는다.

## Edge Cases

| Case | Handling |
|------|----------|
| 기존 smoke test가 `--seed-mock`만 가정 | base case에서 새 args를 추가하되 기존 seeded 동작은 유지한다 |
| `--ui-reset`이 AppStorage 초기값을 완전히 초기화하지 못함 | 이번 단계는 in-memory SwiftData 중심으로 해석하고, defaults reset은 후속 필요 시 보강한다 |
| watch fixture가 iPhone 연결 없이만 동작해야 함 | current `--uitesting-watch` fixture path를 scenario-aware로 감싸되 독립 동작을 유지한다 |
| xctestplan naming 변경이 기존 스크립트/CI를 깨뜨릴 수 있음 | legacy CI plan을 즉시 삭제하지 않고 호환 alias로 유지한다 |

## Testing Strategy

- Unit tests: 없음. 이번 범위는 UI test infrastructure와 runner wiring 중심이다.
- Integration tests:
  - `scripts/test-ui.sh --smoke`
  - `scripts/test-watch-ui.sh --smoke`
  - 필요 시 특정 smoke test만 `--only-testing`으로 재실행
- Manual verification:
  - `git diff --stat`
  - `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNEUITests -showTestPlans`
  - `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNEWatchUITests -showTestPlans`

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| launch argument parsing 추가로 기존 UI test launch가 깨짐 | Medium | High | base class default args를 기존 호환 중심으로 유지 |
| in-memory reset이 일부 persistence path와 어긋남 | Medium | Medium | UI test 전용 guard 아래서만 적용하고 smoke suite로 즉시 검증 |
| xctestplan 분리 후 scheme/test runner가 plan을 찾지 못함 | Medium | High | legacy plan 유지 + `-showTestPlans`/runner smoke로 즉시 검증 |
| watch scenario hook이 과도하게 복잡해짐 | Low | Medium | 현재는 default seeded / empty 두 단계만 제공 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존에 seed-mock, smoke suite, watch fixture, test runner가 이미 존재해 Phase 1은 신규 시스템 구축보다 확장 작업에 가깝다. 핵심 리스크는 test plan resolution과 reset semantics인데, 둘 다 좁은 범위에서 검증 가능하다.
