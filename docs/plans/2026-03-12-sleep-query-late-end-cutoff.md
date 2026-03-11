---
topic: Sleep Query Late End Cutoff
date: 2026-03-12
status: draft
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-12-sleep-average-bedtime-card.md
  - docs/solutions/healthkit/2026-03-10-sleep-partial-watch-coverage-data-loss.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-sleep-deficit-personal-average.md
---

# Implementation Plan: Sleep Query Late End Cutoff

## Context

사용자 보고 기준으로 실제 수면 시간이 4시간 11분인데 앱에서는 3시간 46분으로 집계된다.
현재 `SleepQueryService.fetchSleepStages(for:)`는 조회 범위를 `전날 12:00 ~ 당일 12:00`로 고정하고 있어,
정오 이후까지 이어진 수면 stage의 `startDate`가 12시를 넘으면 해당 구간이 통째로 누락될 수 있다.

## Requirements

### Functional

- 정오 이후까지 이어진 수면 세션도 마지막 stage까지 모두 조회되어야 한다.
- 수면 상세, 대시보드, 주간 수면, deficit 집계 등 `fetchSleepStages(for:)`를 재사용하는 모든 경로가 동일하게 수정 효과를 받아야 한다.
- 기존 watch/non-watch dedup 동작은 유지되어야 한다.

### Non-functional

- 기존 overnight day-anchor semantics는 유지해야 한다.
- 늦잠 시나리오 회귀를 막는 유닛 테스트를 추가해야 한다.
- 낮잠/추가 수면을 불필요하게 다른 날짜로 끌어오지 않도록 범위를 보수적으로 확장해야 한다.

## Approach

`SleepQueryService`의 조회 범위를 `startOfDay(for: date)` 기준 고정 24시간 대신, 늦은 종료를 포착할 수 있는 더 넓은 window로 확장한다.
구체적으로는 기존 `-12h/+12h` 컷오프를 `-12h/+18h` 수준으로 넓혀 정오 이후 stage를 포착하고, 기존 dedup 및 downstream 계산은 그대로 재사용한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `+18h`로 조회 범위 확장 | 변경 범위가 작고 모든 기존 호출부에 즉시 적용됨 | 늦은 오후 낮잠이 포함될 가능성이 생김 | 채택 |
| sleep session을 별도 post-filter로 재구성 | 낮잠/다중 세션 구분을 더 정교하게 처리 가능 | 구현/검증 범위가 커지고 risk가 큼 | 보류 |
| UI에서만 부족한 분량을 보정 | 표면 증상은 숨길 수 있음 | source of truth가 계속 틀림 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/HealthKit/SleepQueryService.swift` | logic update | sleep query window 상한 확장 및 관련 주석 정리 |
| `DUNETests/SleepQueryServiceTests.swift` | test update | 정오 이후 종료 수면 누락 회귀 테스트 추가 |

## Implementation Steps

### Step 1: Query window 확장 및 의도 명시

- **Files**: `DUNE/Data/HealthKit/SleepQueryService.swift`
- **Changes**: `fetchSleepStages(for:)`의 query upper bound를 늦은 종료 수면까지 포함하도록 확장하고, 왜 noon cutoff가 부족한지 주석으로 남긴다.
- **Verification**: 정오 이후 stage가 predicate 범위에 포함되는 단위 테스트가 실패 없이 통과한다.

### Step 2: 늦은 종료 수면 회귀 테스트 추가

- **Files**: `DUNETests/SleepQueryServiceTests.swift`
- **Changes**: query window helper 또는 계산식을 직접 검증하는 테스트를 추가해 12:25 종료 같은 사례가 포함되는지 확인한다.
- **Verification**: 새 테스트가 수정 전 실패하고 수정 후 통과하는지 확인한다.

### Step 3: Downstream 영향 검증

- **Files**: `DUNETests/SleepViewModelTests.swift` 또는 existing sleep-related tests as needed
- **Changes**: 필요 시 `fetchSleepStages(for:)` 재사용 경로가 새 total을 그대로 반영하는 간접 테스트를 보강한다.
- **Verification**: sleep 관련 테스트 스위트가 통과하고 build가 깨지지 않는다.

## Edge Cases

| Case | Handling |
|------|----------|
| 수면이 12:00 이후 종료됨 | query upper bound를 오후까지 확장해 마지막 stage 포함 |
| 수면이 매우 늦게 시작되어 다음날 오후까지 이어짐 | 보수적으로 오후까지는 포함하되, 그 이후 장시간 세션은 별도 이슈로 남김 |
| 오후 낮잠이 같은 anchor day에 존재 | 이번 수정은 source truncation 해결이 우선이며, 낮잠 혼입 여부는 테스트 결과를 보고 추가 분리 검토 |
| watch/non-watch partial overlap | 기존 `deduplicateAndConvert` 로직 유지 |

## Testing Strategy

- Unit tests: `SleepQueryServiceTests`에 query window 회귀 테스트 추가
- Integration tests: `scripts/test-unit.sh --ios-only`로 sleep 관련 기존 테스트와 함께 확인
- Manual verification: 늦잠 시나리오에서 대시보드/수면 상세의 총 수면 시간이 Health 앱과 일치하는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 오후 낮잠이 같은 일자 수면에 섞일 수 있음 | medium | medium | 확장 폭을 최소화하고 테스트/문서에 의도를 남긴다 |
| 여러 화면이 같은 service를 재사용해 표시가 동시에 바뀜 | low | medium | service-level fix로 일관성 확보, 관련 테스트 재실행 |
| 실제 원인이 awake 정책 차이일 수 있음 | medium | medium | 수정 전후 stage 합산/차이를 테스트와 코드에서 재검증 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 현재 구현의 noon cutoff와 사용자 차이값이 구조적으로 맞아떨어지지만, awake 정책 차이 가능성도 남아 있어 테스트로 먼저 검증해야 한다.
