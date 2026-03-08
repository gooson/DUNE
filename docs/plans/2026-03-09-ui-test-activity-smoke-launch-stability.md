---
topic: UI test Activity smoke launch stability
date: 2026-03-09
status: draft
confidence: medium
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
  - docs/solutions/testing/2026-03-08-ui-smoke-toolbar-tap-stability.md
  - docs/solutions/testing/2026-03-09-e2e-phase4-wellness-regression.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: UI test Activity smoke launch stability

## Context

GitHub Actions job `22824264855`의 iOS UI smoke lane이 `ActivitySmokeTests`에서 red가 났다.
로그를 보면 첫 실패는 `testActivityScrollRemainsResponsive`의 assertion이 아니라 `UITestBaseCase.launchApp()` 내부 `app.launch()` timeout이며,
이후 동일 job 안에서 runner restart 후 같은 테스트들이 통과했다.
즉 Activity 화면 기능 회귀보다 UI test harness의 launch/terminate contract가 더 유력한 원인이다.

## Requirements

### Functional

- `ActivitySmokeTests`가 CI에서 launch hang 없이 시작되어야 한다.
- AUT가 이미 죽었거나 아직 뜨지 않은 상태에서도 base test setup/teardown이 2차 실패를 만들지 않아야 한다.
- 기존 smoke assertion scope는 가능하면 유지한다.

### Non-functional

- 수정 범위는 UI test target 중심으로 제한한다.
- flaky workaround보다 재현 가능한 launch lifecycle 안정화를 우선한다.
- PR smoke lane 실행 시간은 현재 수준에서 악화시키지 않는다.

## Approach

`DUNEUITests/Helpers/UITestBaseCase.swift`의 공통 lifecycle을 harden한다.
구체적으로는 launch 전에 무조건 `terminate()` 하지 않고, 앱이 실제 실행 중인 경우에만 종료를 시도하며, teardown도 이미 죽은 AUT를 다시 종료하려다 실패하지 않게 한다.
이후 `ActivitySmokeTests`를 단일 테스트와 클래스 단위로 재실행한다.
만약 launch는 안정화됐지만 특정 smoke가 여전히 2분 allowance에 근접하면 그때만 `ActivitySmokeTests`의 interaction budget을 줄이거나 assertion을 더 가벼운 anchor로 교체한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `UITestBaseCase` lifecycle hardening | 실패 지점과 직접 연결되고 영향 범위가 작다 | launch hang이 앱 runtime 원인일 경우 단독 해결이 아닐 수 있다 | 채택 |
| `ActivitySmokeTests` 순서/이름만 조정 | 빠른 우회 가능 | flaky root cause를 숨기고 다른 첫 테스트로 전이될 수 있다 | 기각 |
| 스크립트에서 simulator terminate/reboot만 추가 | CI 환경 전체를 정리할 수 있다 | 이미 일부 정리가 있고, test target 내부 2차 실패는 남는다 | 보류 |
| per-test time allowance 상향 | 일시적으로 red를 줄일 수 있다 | hang 자체를 숨기고 smoke lane을 느리게 만든다 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEUITests/Helpers/UITestBaseCase.swift` | modify | safe terminate/wait contract 추가, launch/teardown hardening |
| `DUNEUITests/Smoke/ActivitySmokeTests.swift` | maybe modify | launch 안정화 후에도 timeout pressure가 남을 때만 scroll/assertion budget 조정 |
| `docs/solutions/testing/2026-03-09-*.md` | add | 최종 원인과 예방책 문서화 |

## Implementation Steps

### Step 1: Base UI test lifecycle hardening

- **Files**: `DUNEUITests/Helpers/UITestBaseCase.swift`
- **Changes**: launch 전/teardown 시 AUT state를 보고 종료를 조건부 수행하는 helper 추가, wait timeout과 failure handling 정리
- **Verification**: `scripts/test-ui.sh --no-regen --no-stream-log --test-plan DUNEUITests-PR --only-testing DUNEUITests/ActivitySmokeTests/testActivityScrollRemainsResponsive`

### Step 2: Activity smoke focused stabilization

- **Files**: `DUNEUITests/Smoke/ActivitySmokeTests.swift` (필요 시)
- **Changes**: 여전히 CI/runtime budget을 넘는 경우에만 scroll gesture 수 또는 responsiveness assertion을 더 작은 smoke contract로 축소
- **Verification**: `scripts/test-ui.sh --no-regen --no-stream-log --test-plan DUNEUITests-PR --only-testing DUNEUITests/ActivitySmokeTests`

### Step 3: Smoke lane regression check

- **Files**: 없음 또는 `scripts/test-ui.sh` (필요 시)
- **Changes**: focused rerun 결과를 확인하고, 필요 시 smoke lane 전체에서 side effect가 없는지 검증
- **Verification**: `scripts/test-ui.sh --no-regen --no-stream-log --smoke --skip-testing DUNEUITests/HealthKitPermissionUITests`

## Edge Cases

| Case | Handling |
|------|----------|
| AUT가 crash/timeout으로 이미 종료된 상태 | teardown에서 terminate를 재호출하지 않고 screenshot만 남긴 뒤 종료 |
| 이전 테스트의 AUT가 lingering 상태 | launch 전에 running state일 때만 terminate + wait 수행 |
| 첫 cold launch만 비정상적으로 느린 경우 | base lifecycle hardening 후에도 남으면 scroll smoke scope 대신 launch warm-up 필요 여부를 재평가 |

## Testing Strategy

- Unit tests: 없음. XCTest harness 변경이라 UI test로 직접 검증
- Integration tests: `ActivitySmokeTests` 단일/클래스 rerun, 필요 시 PR smoke lane 재실행
- Manual verification: CI 실패 로그와 local rerun timing 비교

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| launch hang 원인이 simulator/runtime 쪽이라 base fix만으로 해결되지 않음 | medium | high | focused rerun 후 필요 시 Activity smoke scope 또는 runner warm-up을 2차 조치로 적용 |
| state check가 lingering AUT 정리를 충분히 못함 | low | medium | terminate helper에서 running state와 wait 결과를 모두 기록하고, 실패 시 fallback 조정 |
| Activity smoke scope를 과도하게 줄여 회귀 탐지력이 낮아짐 | low | medium | scope 조정은 2차 옵션으로 제한하고 hero/add button render 보장은 유지 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: CI 로그상 실패 지점은 base lifecycle과 강하게 연결되지만, 첫 launch timeout이 simulator/runtime race일 가능성도 있어 focused rerun으로 확인이 필요하다.
