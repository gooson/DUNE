---
topic: concurrency-load-state-hardening
date: 2026-03-14
status: draft
confidence: high
related_solutions:
  - docs/solutions/performance/2026-02-16-review-triage-task-cancellation-and-caching.md
  - docs/solutions/architecture/2026-03-12-notification-ingress-mainactor-hardening.md
related_brainstorms: []
---

# Implementation Plan: Concurrency Load State Hardening

## Context

여러 `@MainActor` ViewModel이 period 변경, notification refresh, `.task(id:)` 재실행, 수동 refresh가 겹칠 때
이전 load Task의 결과가 나중에 state를 덮을 수 있다. 현재 구현은 `Task.isCancelled` 체크를 갖고 있어도,
실제 state write가 그 체크보다 먼저 일어나거나, 새 요청이 `isLoading`에 막혀 시작조차 못 하는 경로가 남아 있다.

## Requirements

### Functional

- 이전/취소된 load 결과가 최신 UI state를 덮지 않도록 막는다.
- 새 load 요청이 이전 요청보다 늦게 시작돼도 최신 요청이 최종 state를 소유해야 한다.
- pagination/detail/chart period 전환에서 stale append/update가 발생하지 않아야 한다.

### Non-functional

- 기존 서비스/UseCase API는 유지한다.
- 변경 범위는 load orchestration과 회귀 테스트에 한정한다.
- `@MainActor`/Swift 6 concurrency 규칙을 유지한다.

## Approach

각 ViewModel에 request generation counter를 도입해 load 시작마다 새 generation을 발급하고,
await 이후 및 state write 직전에 `Task.isCancelled`와 generation 일치를 함께 확인한다.
`isLoading` 종료도 “현재 generation인 경우에만” 수행해 취소된 이전 Task가 새 로딩 상태를 끄지 못하게 한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 단순 `Task.isCancelled` guard 추가 | 변경량 적음 | await 이전/이후 state write 순서를 모두 막지 못함 | Rejected |
| 모든 load를 별도 actor/service로 이전 | 동시성 모델이 더 명시적 | 범위 과대, UI state orchestration까지 흔듦 | Rejected |
| request generation + current-request guard | 패턴이 단순하고 재사용 가능, stale write와 isLoading race를 함께 차단 | ViewModel별 소규모 보일러플레이트 필요 | Accepted |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift` | modify | period reload stale overwrite 차단 |
| `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift` | modify | detail reload stale overwrite 차단 |
| `DUNE/Presentation/Wellness/WellnessViewModel.swift` | modify | refresh/load 경쟁 시 stale card/state write 차단 |
| `DUNE/Presentation/Activity/ActivityViewModel.swift` | modify | refresh signal 겹침 시 최신 load 우선 보장 |
| `DUNE/Presentation/Activity/WeeklyStats/WeeklyStatsDetailViewModel.swift` | modify | `.task(id:)` period 전환 stale 반영 차단 |
| `DUNE/Presentation/Activity/TrainingVolume/ExerciseTypeDetailViewModel.swift` | modify | type detail period 전환 stale 반영 차단 |
| `DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift` | modify | training load period 전환 stale 반영 차단 |
| `DUNE/Presentation/Shared/Detail/AllDataViewModel.swift` | modify | pagination/initial reset stale append 차단 |
| `DUNETests/*ViewModelTests.swift` | modify | 최신 요청 우선/취소된 요청 무시 회귀 테스트 추가 |

## Implementation Steps

### Step 1: 공통 stale-request 방어 패턴 적용

- **Files**: ViewModel source files above
- **Changes**:
  - request generation counter + helper 추가
  - load 시작 시 generation 발급
  - await 후/상태 반영 전 current-request guard 적용
  - `isLoading` reset을 current-request 전용으로 제한
- **Verification**: selectedPeriod/refresh 중첩 시 이전 Task가 최신 state를 덮지 않는지 코드상 확인

### Step 2: 회귀 테스트 보강

- **Files**: 관련 `DUNETests/*ViewModelTests.swift`
- **Changes**:
  - 지연되는 첫 요청과 빠른 두 번째 요청을 겹치게 한 뒤 최신 결과만 남는지 검증
  - `isLoading`이 이전 취소 Task 때문에 잘못 내려가지 않는지 검증
- **Verification**: 새 테스트가 실패 재현 후 수정 후 통과

### Step 3: 빌드/테스트 검증

- **Files**: 없음
- **Changes**: `scripts/build-ios.sh`, 관련 unit tests 실행
- **Verification**: 빌드 성공, 수정 대상 ViewModel 테스트 통과

## Edge Cases

| Case | Handling |
|------|----------|
| 첫 요청이 이미 state 일부를 반영한 뒤 두 번째 요청이 시작 | 이후 write는 generation mismatch로 차단하고 최종 state는 두 번째 요청이 소유 |
| 취소된 이전 Task의 `defer`가 늦게 실행 | current-request check로 `isLoading` reset을 무시 |
| `.task(id:)`가 빠르게 연속 발화 | 새 generation이 이전 결과를 모두 폐기 |
| pagination 초기화 직후 이전 페이지 fetch 완료 | stale append를 generation mismatch로 차단 |

## Testing Strategy

- Unit tests: detail/activity/wellness/training volume 계열 ViewModel에 stale-request 회귀 테스트 추가
- Integration tests: 없음
- Manual verification: period 전환, pull-to-refresh, notification-trigger refresh 연속 수행 시 로딩/차트 상태 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| generation 증가만으로 중복 fetch 비용이 약간 남음 | medium | low | state 오염 방지가 우선이며, 중복 호출은 이후 별도 coalescing으로 최적화 가능 |
| helper 적용이 일부 await 지점을 놓침 | medium | medium | 테스트에서 느린 첫 요청/빠른 두 번째 요청 패턴으로 검증 |
| `isLoading` semantics 변경으로 기존 테스트 영향 | low | medium | current-request 기준으로만 reset하도록 테스트도 함께 갱신 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 저장소에 이미 동일 범주의 race-condition 선례와 solution doc이 있고, 현재 후보 파일들도 동일한 load orchestration 패턴을 반복 사용한다.
