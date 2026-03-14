---
topic: heart-rate-detail-intraday-aggregation
date: 2026-03-15
status: draft
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-08-chart-scroll-unified-vitals.md
  - docs/solutions/architecture/2026-03-14-metric-detail-today-scroll-padding.md
  - docs/solutions/healthkit/2026-03-06-step-detail-header-notification-total-sync.md
related_brainstorms: []
---

# Implementation Plan: Heart Rate Detail Intraday Aggregation

## Context

심박수 상세 화면의 `일` 탭이 시간대별 추이를 보여야 하는데, 현재는 일 단위 평균만 반환되어 차트가 사실상 24시간 집계를 잃고 있습니다. 추가 조사 결과 `Weight/BMI/Body Fat/Lean Body Mass` 상세도 `일` 탭에서 샘플을 다시 일 단위로 뭉개고 있어 동일한 유형의 해상도 손실이 존재합니다.

## Requirements

### Functional

- `Heart Rate` 상세의 `일` 탭은 시간 단위 집계를 사용해야 한다.
- `Heart Rate`의 주/월/6개월/년은 기존 일/주/월 집계 의미를 유지해야 한다.
- `Body Composition` 상세의 `일` 탭은 같은 날의 여러 측정치를 하나의 일 평균으로 뭉개지 않아야 한다.
- 다른 상세 메트릭에서 동일한 시간 해상도 손실 여부를 점검하고 결과를 기록해야 한다.

### Non-functional

- 기존 `All Data` 목록과 다른 화면의 심박수 조회 동작은 불필요하게 바꾸지 않는다.
- `MetricDetailViewModel`의 period별 패턴과 레이어 경계를 유지한다.
- 회귀를 막기 위한 unit test를 추가한다.

## Approach

심박수는 서비스 계층에서 period-aware interval을 받아 HealthKit statistics collection을 시간/일 단위로 생성하도록 확장하고, 상세 화면은 그 새 경로를 사용합니다. Body composition은 서비스가 이미 raw sample을 제공하므로 ViewModel에서 `day`일 때만 raw timestamp를 유지하고, 주 이상에서만 일 단위 평균을 유지합니다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `MetricDetailViewModel`에서 heart rate raw sample을 다시 로컬 집계 | 서비스 변경 최소화 | 기존 `HeartRateQueryService`의 mock/real 동작 차이를 키우고 HealthKit dedup 책임이 ViewModel로 새어 나감 | 기각 |
| `fetchHeartRateHistory(start:end:)` 자체 의미를 raw sample로 변경 | API 단순화 | `AllDataViewModel` 등 기존 호출 의미가 바뀌어 부작용 범위가 커짐 | 기각 |
| 상세 전용 interval 파라미터를 추가하고 기존 API는 유지 | 영향 범위를 detail 화면으로 제한, HealthKit 집계 책임 유지 | 프로토콜/테스트 수정 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/HealthKit/HeartRateQueryService.swift` | modify | interval-aware range fetch 추가 및 mock/real 동작 정렬 |
| `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift` | modify | heart rate/body composition day-period aggregation 수정 |
| `DUNETests/MetricDetailViewModelTests.swift` | modify | day-period intraday regression test 추가 |
| `DUNETests/HeartRateQueryServiceTests.swift` | modify | heart rate interval aggregation regression test 추가 또는 보강 |

## Implementation Steps

### Step 1: Heart Rate detail query를 period-aware interval로 확장

- **Files**: `DUNE/Data/HealthKit/HeartRateQueryService.swift`, `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift`
- **Changes**: `start/end` 기반 heart rate fetch에 interval 파라미터를 추가하고, detail 화면은 `HealthDataAggregator.intervalComponents(for:)`를 전달한다. `day`는 시간 단위, 나머지는 기존 의미를 유지한다.
- **Verification**: day 선택 시 24시간 범위에서 여러 hourly bucket이 생성되고, week/month summary 계산이 기존과 동일하게 유지되는지 테스트한다.

### Step 2: Body composition day view의 일 단위 재집계를 제거

- **Files**: `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift`
- **Changes**: `Weight/BMI/Body Fat/Lean Body Mass`는 `day`일 때 raw timestamp를 그대로 사용하고, week/month 이상에서만 일 단위 평균을 적용한다.
- **Verification**: 같은 날 2개 이상 샘플이 있을 때 day chartData가 2개 이상 유지되는지 테스트한다.

### Step 3: 회귀 테스트 추가

- **Files**: `DUNETests/MetricDetailViewModelTests.swift`, `DUNETests/HeartRateQueryServiceTests.swift`
- **Changes**: intraday heart rate aggregation, body composition same-day multi-sample preservation, 기존 long-range aggregation 유지 케이스를 고정한다.
- **Verification**: 관련 테스트만 선택 실행 후 전체 DUNETests 또는 빌드 검증으로 확장한다.

## Edge Cases

| Case | Handling |
|------|----------|
| 당일 심박수 샘플이 1개뿐인 경우 | 단일 hour bucket만 표시하되 0시~24시 축은 유지 |
| 같은 시간 버킷에 심박수 샘플이 여러 개인 경우 | HealthKit statistics collection의 `.discreteAverage`로 평균 처리 |
| body composition이 하루에 여러 번 기록된 경우 | `day`에서는 raw timestamp 모두 유지, `week+`에서는 일 평균으로 시각적 노이즈 완화 |
| mock 데이터 사용 시 | real path와 동일하게 interval 의미를 반영하도록 맞춘다 |

## Testing Strategy

- Unit tests: `HeartRateQueryService`의 interval별 반환 해상도, `MetricDetailViewModel`의 heart rate/body composition day-period chartData 검증
- Integration tests: 없음. HealthKit 실쿼리는 mock/unit 수준으로 보호
- Manual verification: 심박수/체중 상세에서 `일` 탭 진입 후 시간축 점 개수와 헤더 요약 수치 확인, 다른 vitals는 raw sample 유지 여부만 스팟체크

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 심박수 API 시그니처 변경으로 다른 호출부 영향 | medium | medium | 기존 `days:`/기존 `start:end:` 경로는 유지하고 detail 전용 overload 추가 |
| mock과 real aggregation semantics 불일치 | medium | medium | mock path도 interval 기준으로 동일하게 집계하거나 최소한 테스트로 의미 고정 |
| body composition day chart에 포인트가 많아져 보간이 과해짐 | low | low | day만 raw 유지, 주 이상은 기존 평균 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 원인이 `HeartRateQueryService`의 고정 day interval과 `MetricDetailViewModel`의 day-period body aggregation으로 명확히 식별되었고, 수정 범위가 상세 화면 전용 경로로 비교적 좁습니다.
