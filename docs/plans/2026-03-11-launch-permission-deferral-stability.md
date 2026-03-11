---
topic: launch permission deferral stability
date: 2026-03-11
status: draft
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-07-launch-permission-whatsnew-sequencing.md
  - docs/solutions/testing/2026-02-23-healthkit-permission-ui-test-gating.md
  - docs/solutions/general/2026-03-04-weather-permission-first-tap-refresh.md
related_brainstorms: []
---

# Implementation Plan: Launch Permission Deferral Stability

## Context

최초 설치 직후 `DUNEApp`의 launch orchestrator가 `iCloud consent -> HealthKit -> notification -> What's New -> ready` 순서로 권한 요청까지 launch readiness에 묶고 있다. 이 구조는 첫 화면 렌더링보다 system permission prompt가 먼저 개입하도록 만들고, 권한 단계가 꼬이면 Today 탭 초기 로드가 시작되지 않아 앱이 멈춘 것처럼 보이는 증상을 만든다.

## Requirements

### Functional

- launch readiness는 권한 요청 완료와 분리되어야 한다.
- 최초 설치 시 splash/consent 이후 앱 콘텐츠가 먼저 표시되어야 한다.
- HealthKit/notification 권한 요청은 launch ready 이후로 지연되어야 한다.
- Today 초기 로드는 deferred authorization이 끝나기 전까지 protected HealthKit query를 실행하지 않아야 한다.

### Non-functional

- 기존 `DUNEApp` 단일 오케스트레이터 책임은 유지한다.
- UI test/manual permission flow가 새 순서를 반영해야 한다.
- Swift Testing 기반 unit test로 launch sequencing 회귀를 막아야 한다.

## Approach

launch planner에서 permission 단계를 blocking launch sequence에서 제거하고, `DUNEApp`이 ready 이후 별도 deferred task로 HealthKit/notification authorization을 순차 실행한다. Today 탭은 `canLoadHealthKitData` gate를 받아 deferred authorization 완료 전에는 shared snapshot/live query를 모두 건너뛰고, authorization 완료 후 prop 변화로 다시 로드한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Launch 단계는 유지하고 prompt 순서만 조정 | 변경 범위 작음 | readiness가 여전히 system prompt에 종속됨 | 기각 |
| Dashboard에서만 HealthKit prompt를 늦춤 | Today 탭은 개선 가능 | notification prompt와 app-level launch blocking이 남음 | 기각 |
| App ready 후 deferred authorization + dashboard query gate | launch 안정성 확보, 오케스트레이터 단일화 유지 | prop/state plumbing이 조금 늘어남 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/LaunchExperiencePlanner.swift` | update | blocking launch sequence에서 permission step 제거 |
| `DUNE/App/DUNEApp.swift` | update | ready 이후 deferred authorization task 실행, dashboard gate 전달 |
| `DUNE/App/ContentView.swift` | update | Today 탭에 HealthKit data gate 전달 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | update | gate 변화 시 reload되도록 load trigger 조정 |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | update | deferred authorization 전 shared snapshot/live query skip |
| `DUNETests/LaunchExperiencePlannerTests.swift` | update | 새 launch sequencing 검증 |
| `DUNETests/DashboardViewModelTests.swift` | update | deferred load gate 회귀 테스트 추가 |
| `DUNEUITests/Manual/HealthKitPermissionUITests.swift` | update | consent/What's New/permission 새 순서 반영 |

## Implementation Steps

### Step 1: Launch flow를 permission-free ready sequence로 재구성

- **Files**: `DUNE/App/LaunchExperiencePlanner.swift`, `DUNE/App/DUNEApp.swift`
- **Changes**: planner에서 permission blocking step 제거, `DUNEApp`에 deferred authorization runner 추가, ready 이후에만 prompt 실행
- **Verification**: `LaunchExperiencePlannerTests`에서 consent/What's New/ready 순서가 통과하고, `DUNEApp` 컴파일이 유지됨

### Step 2: Today 초기 load에서 HealthKit query를 deferred gate로 보호

- **Files**: `DUNE/App/ContentView.swift`, `DUNE/Presentation/Dashboard/DashboardView.swift`, `DUNE/Presentation/Dashboard/DashboardViewModel.swift`
- **Changes**: `canLoadHealthKitData` 전달, initial load에서 shared snapshot/live query skip, gate 변화 시 reload
- **Verification**: deferred gate가 false일 때 빈 HealthKit query 경로로 종료하고, true 전환 시 재로드됨

### Step 3: 테스트와 manual verification 경로 업데이트

- **Files**: `DUNETests/LaunchExperiencePlannerTests.swift`, `DUNETests/DashboardViewModelTests.swift`, `DUNEUITests/Manual/HealthKitPermissionUITests.swift`
- **Changes**: 새 sequencing/unit tests 추가, manual UI test의 expected order 수정
- **Verification**: 관련 unit tests와 build 통과, manual test helper가 새 순서를 설명과 함께 반영

## Edge Cases

| Case | Handling |
|------|----------|
| HealthKit unavailable device/mac path | `canLoadHealthKitData`와 별개로 mirrored snapshot 경로 유지 |
| authorization request가 throw로 실패 | same-launch attempt flag로 재시도 루프 방지, 다음 launch에서만 재시도 |
| notification만 미완료 상태 | ready 이후 HealthKit과 독립적으로 deferred runner가 순차 처리 |
| deferred authorization 완료 후 Today가 이미 렌더링됨 | `DashboardView` task id에 gate를 포함해 prop 변화만으로 재로드 |

## Testing Strategy

- Unit tests: `LaunchExperiencePlannerTests`, `DashboardViewModelTests`에 deferred sequencing/query gate 케이스 추가
- Integration tests: `scripts/build-ios.sh` 및 관련 `xcodebuild test` 실행
- Manual verification: fresh simulator에서 `HealthKitPermissionUITests` 흐름으로 consent -> optional What's New -> dashboard -> HealthKit/notification prompt 순서 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| deferred prompt 이후 Today가 자동 갱신되지 않음 | medium | medium | dashboard load trigger에 gate state 포함 |
| shared snapshot 경로가 여전히 HealthKit query를 수행 | medium | high | `DashboardViewModel`에서 snapshot fetch 자체를 gate로 감쌈 |
| UI test 기대 순서 변경으로 manual script 혼동 | low | medium | manual UI test helper/주석을 함께 업데이트 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 solution 문서가 이미 launch orchestrator 구조와 permission race를 설명하고 있어, 이번 변경은 blocking scope를 줄이고 query gate를 추가하는 정리된 후속 작업이다.
