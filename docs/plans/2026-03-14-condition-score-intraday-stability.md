---
topic: condition-score-intraday-stability
date: 2026-03-14
status: draft
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-12-condition-score-rhr-baseline-and-chart-scroll.md
  - docs/solutions/architecture/2026-03-13-hourly-score-snapshot-system.md
related_brainstorms:
  - docs/brainstorms/2026-03-13-hourly-condition-tracking.md
---

# Implementation Plan: Condition Score Intraday Stability

## Context

Condition Score 상세 화면의 `day` 그래프가 시간별 변화를 보여주지만, 현재는 일간용 `CalculateConditionScoreUseCase.execute` 결과를 시간별 snapshot으로 그대로 저장해 그리기 때문에 자정 이후 HRV 샘플이 몇 개만 쌓여도 점수가 크게 출렁인다. 사용자가 보는 그래프는 "시간별 컨디션 변화"인데 계산식은 "오늘 누적 일평균 컨디션"에 가까워 의미가 어긋난다.

## Requirements

### Functional

- `ConditionScoreDetailView`의 `day` 기간 차트는 intraday 전용 점수 계산을 사용해야 한다.
- intraday 점수는 최근 짧은 시간창의 HRV를 기준으로 계산하되, 샘플 수가 부족하면 더 넓은 시간창으로 확장해야 한다.
- 기존 Today hero / 7일 history / shared snapshot의 일간 컨디션 점수 계산은 유지한다.

### Non-functional

- 기존 `CalculateConditionScoreUseCase`의 일간 경로 회귀가 없어야 한다.
- 차트 계산은 현재 day 화면에서 충분히 가벼운 수준을 유지해야 한다.
- 수학 로직 변경에는 Swift Testing 회귀 테스트를 추가한다.

## Approach

`CalculateConditionScoreUseCase`에 intraday 전용 helper를 추가하고, `ConditionScoreDetailViewModel.loadHourlyData()`가 snapshot 저장값을 그대로 읽는 대신 해당 날짜까지의 HRV/RHR 원본 데이터로 시간별 score를 재계산한다.

핵심 규칙:

- HRV 현재값: 최근 3시간 평균
- 샘플이 3개 미만이면 최근 6시간 평균으로 확장
- 그래도 부족하면 `startOfDay ... evaluationDate` 누적 평균으로 fallback
- baseline: 같은 use case의 기존 14일 day-level baseline을 재사용하되, 현재 시간창 평균을 오늘 값으로 사용
- RHR: 기존 baseline-relative day average 로직 유지

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| snapshot 차트에 moving average만 적용 | 구현이 작다 | 잘못된 점수 정의를 숨길 뿐 원인 해결이 아님 | Rejected |
| 기존 일간 condition score 자체를 partial-day 안정화로 변경 | hero/detail/snapshot 전부 일관화 가능 | 앱 전체 현재 점수 의미가 바뀌고 영향 범위가 큼 | Rejected |
| detail `day` 차트에 intraday 전용 score helper 도입 | 사용자 문제를 직접 해결, 일간 경로 영향 최소화 | helper 추가 설계 필요 | Selected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/UseCases/CalculateConditionScoreUseCase.swift` | Modify | intraday score helper 추가 및 공통 scoring 로직 추출 |
| `DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift` | Modify | `day` 기간 차트를 raw snapshot 대신 intraday recompute로 전환 |
| `DUNETests/CalculateConditionScoreUseCaseTests.swift` | Modify | intraday stability / window fallback 테스트 추가 |
| `DUNETests/ConditionScoreDetailViewModelTests.swift` | Modify | `day` 차트가 stabilized hourly score를 사용하는지 검증 |

## Implementation Steps

### Step 1: UseCase intraday helper 추가

- **Files**: `DUNE/Domain/UseCases/CalculateConditionScoreUseCase.swift`
- **Changes**:
  - 일간 `execute(input:)` 내부 수식을 공통 private helper로 정리
  - 최근 3h/6h window 기반 HRV 평균을 사용하는 intraday helper 추가
  - baseline readiness, RHR adjustment, time-of-day adjustment는 기존 규칙을 그대로 적용
- **Verification**: 기존 unit test + 신규 intraday test 통과

### Step 2: Detail day chart 재계산 경로로 전환

- **Files**: `DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift`
- **Changes**:
  - `loadHourlyData()`에서 `ScoreRefreshService.fetchSnapshots()` 의존 제거
  - 선택 날짜의 시간대별 evaluation 시점을 만들고 intraday helper로 차트 포인트 생성
  - summary/highlight는 이 recomputed hourly series를 기준으로 유지
- **Verification**: `day` 기간에서 차트 데이터가 시간순으로 생성되고 극단적인 튐이 줄어든다

### Step 3: 회귀 테스트 보강

- **Files**: `DUNETests/CalculateConditionScoreUseCaseTests.swift`, `DUNETests/ConditionScoreDetailViewModelTests.swift`
- **Changes**:
  - 동일 baseline에서 단일 outlier 추가 시 intraday helper가 cumulative-day 방식보다 덜 과민한지 검증
  - view model의 `day` 로드 결과가 빈 snapshot service 없이도 생성되는지 검증
- **Verification**: targeted tests green

## Edge Cases

| Case | Handling |
|------|----------|
| 새벽 초반에 HRV 샘플이 1-2개뿐인 경우 | 6시간 window 또는 day-to-date fallback 사용 |
| 해당 날짜에 HRV 샘플이 전혀 없는 경우 | 차트 포인트를 만들지 않고 빈 상태 유지 |
| RHR가 당일에 없는 경우 | 기존 display/baseline fallback 규칙 유지, intraday score는 HRV 중심으로 계산 |
| baseline day 수가 7일 미만인 경우 | 기존과 동일하게 score nil |

## Testing Strategy

- Unit tests: intraday helper window fallback, outlier stability, 기존 execute 회귀 없음
- Integration tests: 없음
- Manual verification: Condition Score detail `day` 그래프에서 새벽/오전 구간이 이전보다 과도하게 지그재그하지 않는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| intraday helper가 기존 일간 수식과 너무 달라 사용자가 점수 의미를 혼동 | Medium | Medium | 변경 범위를 `day` 차트에만 제한하고 hero/current score는 유지 |
| window fallback이 지나치게 보수적이어서 초반 차트가 비거나 반응이 늦음 | Medium | Low | 테스트에서 3h/6h/day fallback 시나리오를 모두 고정 |
| ViewModel이 day 차트에서 더 많은 원본 데이터를 읽어 성능 저하 | Low | Medium | 당일 + baseline window 범위만 조회하고 시간별 계산을 선형으로 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 원인이 현재 구현과 brainstorm 문서에서 동일하게 드러나 있으며, 수정 범위를 detail `day` 차트와 use case helper로 제한하면 회귀 리스크를 제어하면서 사용자 체감 문제를 직접 해결할 수 있다.
