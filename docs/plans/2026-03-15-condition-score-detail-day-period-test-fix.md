---
topic: condition-score-detail day period test fix
date: 2026-03-15
status: implemented
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-14-condition-score-intraday-stability.md
related_brainstorms:
  - docs/brainstorms/2026-03-13-hourly-condition-tracking.md
---

# Implementation Plan: Condition Score Detail Day Period Test Fix

## Context

`ConditionScoreDetailViewModelTests.dayPeriodUsesIntradayRecompute()`가 새벽 시간대에 현재 시각보다 미래인 HRV 샘플을 생성해 `loadHourlyData()`가 샘플을 제외하면서 `chartData`와 `summaryStats`가 비는 회귀가 발생한다. 목표는 테스트를 시간 독립적으로 만들어 raw HRV 기반 day chart contract를 안정적으로 고정하는 것이다.

## Requirements

### Functional

- `dayPeriodUsesIntradayRecompute()`가 로컬 실행 시각과 무관하게 항상 today chart 데이터를 생성해야 한다.
- 테스트는 snapshot service 없이 raw HRV 샘플 경로를 계속 검증해야 한다.

### Non-functional

- 수정 범위는 최소화한다.
- 기존 intraday 계산 로직 contract는 유지한다.

## Approach

테스트 데이터에서 `Date()`의 hour component를 직접 조합하는 대신, 항상 현재 시각보다 과거인 시간대를 기준으로 샘플을 생성한다. 이렇게 하면 새벽 0시~2시 실행에서도 future sample이 만들어지지 않는다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Production code에서 future sample 허용 | 테스트를 안 건드릴 수 있음 | 실제 앱 contract를 바꾸고 의미 없는 미래 데이터까지 포함할 위험 | 기각 |
| 테스트에서 고정 clock/date 주입 | 완전한 결정성 | 현재 구조상 주입점이 없고 수정 범위가 커짐 | 보류 |
| 테스트 샘플 시간을 항상 `now` 이전으로 조정 | 최소 변경, flake 제거 | helper 계산을 조금 바꿔야 함 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNETests/ConditionScoreDetailViewModelTests.swift | test fix | 새벽 시간대에도 과거 샘플만 생성하도록 day-period 테스트 데이터 안정화 |

## Implementation Steps

### Step 1: 실패 원인 고정

- **Files**: `DUNETests/ConditionScoreDetailViewModelTests.swift`
- **Changes**: 현재 hour 기반 샘플 생성이 future timestamps를 만들 수 있음을 테스트 코드에서 제거
- **Verification**: 대상 테스트가 새벽 시간대에도 `chartData.count >= 2`를 만족

### Step 2: 회귀 검증

- **Files**: `DUNETests/ConditionScoreDetailViewModelTests.swift`
- **Changes**: 필요 시 assertion은 유지하고 입력 데이터만 안정화
- **Verification**: `ConditionScoreDetailViewModelTests` 대상 실행 통과

## Edge Cases

| Case | Handling |
|------|----------|
| 자정 직후 실행 | 샘플 시각을 `now` 기준 과거 hour로 계산해 future sample 생성 방지 |
| 느린 async load | 기존 `loadData()` fallback 호출 유지 |
| timezone 차이 | `Calendar.current` 기준 today contract는 유지하되 `now` 이전 샘플만 사용 |

## Testing Strategy

- Unit tests: `dayPeriodUsesIntradayRecompute()` 단건 재현 후 `ConditionScoreDetailViewModelTests` 전체 실행
- Integration tests: 없음
- Manual verification: 없음

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 테스트만 고치고 실제 구현 문제를 놓침 | low | medium | `loadHourlyData()` 필터 조건과 `executeIntraday()` 경로를 함께 재확인 |
| 시간 계산 변경으로 assertion 의미 약화 | low | low | raw HRV recompute contract와 same-day assertion은 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 현재 로컬 시간이 00시대이며, failing test가 future sample 생성 패턴과 정확히 일치한다. 수정 범위가 테스트에 한정되어 검증이 명확하다.
