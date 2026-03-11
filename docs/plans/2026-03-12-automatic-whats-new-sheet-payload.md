---
topic: automatic-whats-new-sheet-payload
date: 2026-03-12
status: implemented
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-08-whatsnew-sheet-list-blank-simulator.md
  - docs/solutions/architecture/2026-03-07-launch-permission-whatsnew-sequencing.md
related_brainstorms:
  - docs/brainstorms/2026-03-07-whats-new-space.md
---

# Implementation Plan: Automatic What's New Sheet Payload

## Context

launch 시점에 자동 표시되는 `What's New` sheet가 제목과 닫기 버튼만 보이고 본문이 비어 보이는 문제가 재발했다.

현재 `DUNEApp`는 automatic sheet visibility, build marker, release payload를 각각 별도 state로 관리한다. manual 진입 경로는 row 존재 UI 테스트가 있지만, automatic sheet 경로는 화면 표시 여부만 확인하고 실제 release row 존재는 검증하지 않는다.

## Requirements

### Functional

- automatic `What's New` sheet가 표시될 때 release payload가 빈 상태로 먼저 뜨지 않아야 한다.
- automatic sheet dismiss 후 opened build 기록은 기존처럼 유지되어야 한다.
- launch 자동 `What's New` 경로도 최소 1개 feature row 존재를 검증해야 한다.

### Non-functional

- 기존 manual `What's New` 진입 동작을 깨지 않아야 한다.
- launch orchestration 순서(`consent -> permissions -> what's new -> ready`)는 유지해야 한다.
- 테스트 전용 변경은 production flow를 오염시키지 않아야 한다.

## Approach

automatic `What's New` presentation payload를 단일 optional state로 묶고, sheet는 boolean 대신 item binding으로 표시한다. 이렇게 하면 sheet가 열리는 시점과 release payload 전달 시점이 동일한 source of truth를 공유하게 되어 빈 payload race를 줄일 수 있다.

automatic dismiss bookkeeping은 build marker를 별도 state로 유지해 현재 동작을 보존한다. UI 회귀는 existing launch permission UI test에서 row 존재를 확인하는 방식으로 보강한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `showWhatsNewSheet` + releases array 유지 | 변경 범위가 작음 | visibility와 payload가 분리돼 race 가능성 유지 | 기각 |
| `sheet(item:)` + presentation payload struct | sheet visibility와 payload를 한 state로 통합 | dismiss bookkeeping state 1개가 추가로 필요 | 채택 |
| `WhatsNewManager`를 ObservableObject로 전환 | 확장성 있음 | 문제에 비해 과한 구조 변경 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/DUNEApp.swift` | update | automatic `What's New` presentation state를 item-based payload로 정리 |
| `DUNEUITests/Manual/HealthKitPermissionUITests.swift` | update | automatic sheet에서 실제 feature row 존재를 검증 |
| `docs/solutions/general/2026-03-12-automatic-whats-new-sheet-payload.md` | add | 문제와 해결책을 compound 문서로 기록 |

## Implementation Steps

### Step 1: Automatic sheet state 정리

- **Files**: `DUNE/App/DUNEApp.swift`
- **Changes**: automatic `What's New` payload struct 추가, separate bool/array state 제거, `.sheet(isPresented:)`를 `.sheet(item:)`로 교체
- **Verification**: automatic presentation code path가 build + releases를 함께 설정하는지 확인

### Step 2: Dismiss bookkeeping 유지

- **Files**: `DUNE/App/DUNEApp.swift`
- **Changes**: dismiss 시 opened build 기록이 유지되도록 build marker state 정리
- **Verification**: dismiss handler가 기존과 동일하게 `markOpened(build:)`를 호출하는지 확인

### Step 3: Automatic launch regression coverage 보강

- **Files**: `DUNEUITests/Manual/HealthKitPermissionUITests.swift`
- **Changes**: automatic `What's New` sheet가 뜨면 known row 존재를 확인한 뒤 닫도록 테스트 보강
- **Verification**: UI test가 blank sheet를 pass시키지 않는지 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 현재 build에 해당하는 release가 없을 때 | 기존 guard 유지, automatic sheet 미표시 |
| interactive dismiss로 sheet가 닫힐 때 | dismiss handler에서 마지막 presented build 기준으로 opened 처리 |
| UI test 환경에서 automatic `What's New`가 뜨지 않을 때 | 기존처럼 early return 허용 |

## Testing Strategy

- Unit tests: 기존 `LaunchExperiencePlannerTests`, `WhatsNewManagerTests` 영향 여부 확인
- Integration tests: `HealthKitPermissionUITests`에서 automatic `What's New` row 존재 확인
- Manual verification: fresh state에서 launch 후 automatic `What's New` 본문 row 표시 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| item-based sheet dismiss timing이 기존과 달라짐 | medium | medium | build marker를 별도 state로 유지하고 dismiss handler 확인 |
| manual `What's New` 경로와 동작 차이가 생김 | low | medium | manual path는 건드리지 않고 automatic path만 변경 |
| manual-only UI test라 CI coverage가 제한적임 | medium | low | targeted build/test와 수동 재현 절차를 응답에 명시 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: visual symptom은 automatic sheet payload race와 가장 잘 맞지만, 시뮬레이터 전용 rendering 요인도 완전히 배제되지는 않는다. 이번 변경은 state 전달을 단순화해 해당 가설을 직접 차단한다.
