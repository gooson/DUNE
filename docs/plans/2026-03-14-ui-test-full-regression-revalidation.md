---
topic: UI Test Full Regression Revalidation
date: 2026-03-14
status: draft
confidence: medium
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
  - docs/solutions/testing/2026-03-09-ui-test-aut-launch-lifecycle-hardening.md
related_brainstorms:
  - docs/brainstorms/2026-03-02-ui-test-nightly-hardening.md
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: UI Test Full Regression Revalidation

## Context

전체 iOS UI 테스트 풀 런을 다시 검증하고, 현재 깨지는 케이스를 재현 가능한 로그와 함께 분류한 뒤 모두 수정해야 한다.
최근 문서상 UI 테스트 인프라와 launch lifecycle 하드닝은 이미 적용되어 있으므로, 이번 작업은 단순 재실행이 아니라
"base harness 문제인지, selector debt인지, 실제 화면 회귀인지"를 분리해서 수정하는 것이 핵심이다.

## Requirements

### Functional

- `scripts/test-ui.sh` 기본 full regression lane을 실제로 실행한다.
- 실패 테스트를 모두 식별하고, 각 실패의 재현 경로를 확보한다.
- failing case를 코드 또는 테스트에서 수정한다.
- 수정 후 targeted rerun으로 각 실패 케이스를 재검증한다.
- 마지막에 full regression lane을 다시 실행해 전체 통과를 확인한다.

### Non-functional

- manual HealthKit permission lane은 자동 full regression 범위에 섞지 않는다.
- 기존 launch argument, seeded scenario, test plan semantics를 보존한다.
- selector는 가능하면 텍스트가 아니라 accessibility identifier와 helper를 우선 사용한다.
- flaky 환경 이슈와 product regression을 구분해 기록한다.

## Approach

먼저 full regression을 실제 실행해 현재 실패 집합을 고정한다.
그다음 실패를 launch/base helper, runner configuration, test helper, app surface regression으로 분류하고,
공통 원인부터 작은 단위로 수정한다.
각 수정은 실패 테스트만 골라 빠르게 다시 돌려 원인을 닫고, 마지막에 full lane으로 회귀를 확인한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| full run 없이 smoke + 정적 점검만 수행 | 빠름 | 실제 failing set을 놓칠 수 있음 | 기각 |
| 실패 테스트별 즉시 수정 후 마지막에 전체 런 | 수정 속도는 빠를 수 있음 | 공통 root cause를 놓치기 쉬움 | 기각 |
| full run으로 실패 집합 고정 후 공통 원인부터 수정 | 실제 회귀 신호를 기준으로 움직일 수 있음 | 첫 실행 시간이 김 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/test-ui.sh` | verify / possible update | full lane, simulator fallback, test-plan wiring 확인 및 필요 시 수정 |
| `DUNEUITests/Helpers/UITestBaseCase.swift` | possible update | launch, teardown, seeded reset lifecycle 문제 수정 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | possible update | flaky selector/navigation helper 보강 |
| `DUNEUITests/Smoke/*.swift` | possible update | smoke assertion/selector 회귀 수정 |
| `DUNEUITests/Full/*.swift` | possible update | full regression assertion/flow 회귀 수정 |
| `DUNE/App/DUNEApp.swift` | possible update | UI test launch argument 처리 문제 수정 |
| `DUNE/App/TestDataSeeder.swift` | possible update | scenario seed/fixture 누락 수정 |
| `DUNE/Presentation/**` | possible update | failing UI surface의 accessibility identifier 또는 flow 회귀 수정 |
| `Shared/Resources/Localizable.xcstrings` | possible update | 사용자 대면 문자열 수정이 생길 경우 localization 동기화 |

## Implementation Steps

### Step 1: Baseline full regression and classify failures

- **Files**: `scripts/test-ui.sh`, `.xcodebuild/ui-test.log`, `DUNEUITests/**/*.swift`
- **Changes**: 코드 변경 없이 full lane 실행, failing tests와 first-failure stack을 수집하고 공통 root cause를 분류한다.
- **Verification**: `scripts/test-ui.sh`

### Step 2: Fix infrastructure-level failures first

- **Files**: `scripts/test-ui.sh`, `DUNEUITests/Helpers/UITestBaseCase.swift`, `DUNEUITests/Helpers/UITestHelpers.swift`, `DUNE/App/DUNEApp.swift`, `DUNE/App/TestDataSeeder.swift`
- **Changes**: simulator boot, launch lifecycle, seeded state, navigation helper, runner wiring 같은 공통 실패 원인을 먼저 수정한다.
- **Verification**: failing test별 `scripts/test-ui.sh --only-testing ...`

### Step 3: Fix surface-specific regressions

- **Files**: failing surface와 연결된 `DUNEUITests/*` 및 `DUNE/Presentation/**`
- **Changes**: accessibility identifier 누락, route 진입 실패, sheet/form validation 변화, localization-fragile selector를 수정한다.
- **Verification**: surface별 targeted rerun

### Step 4: Re-run full regression and stabilize residual flakes

- **Files**: Step 2-3에서 수정된 파일 전체
- **Changes**: 남은 실패가 있으면 flaky 환경 이슈인지 product regression인지 다시 분리하고 잔여 수정을 마친다.
- **Verification**: `scripts/test-ui.sh`

### Step 5: Review, document, and prepare ship

- **Files**: 변경 파일 전체, `docs/solutions/testing/...`
- **Changes**: diff 기반 리뷰, 필요한 solution doc 작성, ship 가능 상태 정리
- **Verification**: `git diff main...HEAD`, `scripts/build-ios.sh`, `scripts/test-ui.sh`

## Edge Cases

| Case | Handling |
|------|----------|
| simulator boot fallback이 다른 기기로 바뀌는 경우 | script output에서 resolved simulator를 확인하고 동일 기기 기준으로 rerun |
| manual permission test가 full lane에 섞이는 경우 | test plan 설정을 점검하고 자동 lane에서 제외 유지 |
| 텍스트 기반 selector가 localization/copy 변경에 깨지는 경우 | AXID 또는 helper selector로 전환 |
| seeded scenario 데이터가 화면 기대 상태와 어긋나는 경우 | `TestDataSeeder` 또는 launch scenario mapping 수정 |
| 첫 launch hang 이후 후속 테스트가 연쇄 실패하는 경우 | first failure 기준으로 base harness부터 확인 |
| iPad/sidebar와 iPhone/tab 구조 차이로 navigation helper가 깨지는 경우 | 공통 helper에서 idiom-aware navigation 보강 |

## Testing Strategy

- Unit tests: 새 도메인 로직이 생기지 않는 한 추가하지 않고, 앱 로직 변경이 생기면 해당 테스트를 보강한다.
- Integration tests: `scripts/test-ui.sh --only-testing ...`로 실패 케이스별 targeted rerun을 반복한다.
- Manual verification: 필요 시 simulator/device resolution과 seed scenario를 로그 기준으로 점검한다.
- Final regression: `scripts/test-ui.sh` full lane 재실행, 필요 시 `scripts/build-ios.sh`로 빌드 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| detached HEAD 상태에서 커밋/ship 준비가 꼬임 | medium | high | Work setup에서 `codex/` prefix 작업 브랜치를 먼저 생성 |
| simulator 환경 불안정으로 false failure 발생 | high | medium | first failure 중심 분류, targeted rerun으로 재현성 확인 |
| 한 실패를 고치며 다른 lane이 깨짐 | medium | medium | 수정 후 해당 surface targeted rerun, 마지막 full rerun |
| UI 문자열 변경이 localization 누락을 만들 수 있음 | low | medium | 문자열 변경 시 localization rule 체크 및 xcstrings 동기화 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 현재 harness와 runner 문서는 충분하지만, 실제 failing set은 full regression 실행 전까지 확정되지 않는다. 공통 인프라 이슈일 가능성과 화면별 회귀가 섞여 있을 가능성을 모두 열어 둔다.
