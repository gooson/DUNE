---
tags: [ui-test, e2e, xctestplan, smoke-test, watchos, swiftdata, deterministic-launch]
category: testing
date: 2026-03-08
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNE/App/TestDataSeeder.swift
  - DUNEWatch/DUNEWatchApp.swift
  - DUNEWatch/WatchConnectivityManager.swift
  - DUNEUITests/Helpers/UITestBaseCase.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
  - DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift
  - DUNE/project.yml
  - scripts/test-ui.sh
  - scripts/test-watch-ui.sh
related_solutions:
  - docs/solutions/testing/ui-test-infrastructure-design.md
  - docs/solutions/testing/2026-03-04-pr-fast-gate-and-nightly-regression-split.md
  - docs/solutions/testing/2026-03-02-watch-ui-test-coverage-expansion.md
---

# Solution: E2E Phase 1 테스트 인프라 구축

## Problem

전체 E2E 확장을 시작하기 전에 iOS/watch UI 테스트의 launch 상태, fixture seeding, 공통 helper, runner/test plan 구성이 서로 다른 수준으로 흩어져 있었다.
이 상태에서는 Phase 2 이후 페이지/플로우 테스트를 추가할수록 중복과 flaky 경로가 다시 늘어날 가능성이 컸다.

### Symptoms

- UI 테스트가 `seed` 여부만 부분적으로 제어하고 `reset`/`scenario`를 공통 API로 선언하지 못함
- watch UI 테스트는 fixture launch와 session helper가 분산되어 신규 시나리오 추가 비용이 큼
- PR smoke와 full regression의 test plan이 명시적으로 분리되지 않아 runner 확장성이 낮음
- 일부 iOS smoke는 탭/모달/폼 조작 helper 부족으로 개별 테스트 파일에 로직이 퍼져 있었음

### Root Cause

테스트 인프라가 "기존 smoke 유지" 중심으로만 성장했고, deterministic launch state와 reusable helper를 위한 공통 계층이 충분히 추상화되지 않았다.
또한 CI/로컬 runner가 legacy plan 이름과 고정 simulator 가정에 묶여 있어 Phase별 lane 분리가 코드 구조에 반영되지 못했다.

## Solution

UI 테스트 실행 상태를 `reset + seed + scenario` 조합으로 표준화하고, iOS/watch 공통 helper 및 PR/Full test plan 분리를 함께 도입했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEUITests/Helpers/UITestBaseCase.swift` | iOS launch configuration, failure screenshot helper 추가 | 테스트별 deterministic launch와 디버깅 artifact를 공통화하기 위해 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | tab/sidebar/scroll/modal/form helper 정리 | smoke test 중복 제거와 flaky interaction 완화를 위해 |
| `DUNE/App/DUNEApp.swift` | `--ui-reset`, `--seed-mock`, `--ui-scenario` 해석 추가 | 앱 런타임이 테스트 상태를 명시적으로 수용하도록 하기 위해 |
| `DUNE/App/TestDataSeeder.swift` | scenario-aware seeding entrypoint 추가 | empty/default-seeded 기반 확장 포인트를 만들기 위해 |
| `DUNEWatch/DUNEWatchApp.swift` | watch UI reset 시 in-memory SwiftData 사용 | watch UI tests도 isolated state로 실행하기 위해 |
| `DUNEWatch/WatchConnectivityManager.swift` | watch fixture scenario 분기 추가 | seeded/empty watch state를 동일 패턴으로 유지하기 위해 |
| `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift` | watch launch/session helper 추가 | watch smoke/test flow 재사용성을 높이기 위해 |
| `DUNE/project.yml` | iOS/watch UI scheme에 PR/Full test plan 연결 | runner와 Xcode scheme에서 lane을 명시적으로 분리하기 위해 |
| `DUNEUITests/*.xctestplan` | `DUNEUITests-PR`, `DUNEUITests-Full` 추가 | PR gate와 full regression 역할을 분리하기 위해 |
| `DUNEWatchUITests/*.xctestplan` | `DUNEWatchUITests-PR`, `DUNEWatchUITests-Full` 추가 | watch regression lane도 동일 전략으로 맞추기 위해 |
| `scripts/test-ui.sh`, `scripts/test-watch-ui.sh` | plan alias/default, simulator fallback, smoke target 정리 | 로컬/CI 실행 환경 차이를 줄이고 기본 실행을 안정화하기 위해 |

### Key Code

```swift
private struct UITestLaunchConfiguration {
    let shouldResetState: Bool
    let shouldSeedMockData: Bool
    let scenario: UITestSeedScenario
}
```

```bash
if [[ "$SMOKE_MODE" -eq 1 ]]; then
    echo "DUNEUITests-PR"
else
    echo "DUNEUITests-Full"
fi
```

## Prevention

이후 UI 테스트를 추가할 때는 개별 테스트 파일에서 launch/reset 로직을 직접 구성하지 않고, base case configuration과 scenario enum을 먼저 확장한다.
PR lane에는 안정적인 핵심 경로만 유지하고, 깊은 상호작용 검증은 full/nightly lane으로 보내는 원칙을 유지한다.

### Checklist Addition

- [ ] 신규 UI test가 `reset`, `seed`, `scenario` 중 어떤 launch state를 요구하는지 base case 수준에서 선언했는지 확인
- [ ] flaky 가능성이 있는 deep interaction test를 PR smoke에 바로 넣지 않고 Full plan으로 분리했는지 확인
- [ ] runner script 변경 시 simulator 이름/OS 고정 가정 없이 fallback 경로가 유지되는지 확인
- [ ] UI test helper 변경 후 compiler warning과 smoke 결과를 함께 확인했는지 확인

### Rule Addition (if applicable)

새 규칙 파일 추가는 보류한다.
다음 E2E Phase에서도 본 문서를 기준으로 scenario 확장, PR lane 범위, helper 재사용 여부를 먼저 점검한다.

## Lessons Learned

UI 테스트 안정화는 개별 assertion을 늘리는 것보다 launch state와 runner semantics를 먼저 표준화하는 편이 효과가 크다.
또한 PR lane을 "모든 smoke"가 아니라 "지속적으로 통과 가능한 핵심 smoke"로 좁히고, 전체 회귀는 별도 plan으로 분리해야 확장 속도와 신뢰성을 동시에 유지할 수 있다.
