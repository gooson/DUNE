---
topic: sleep-all-data-time-anchor
date: 2026-03-11
status: implemented
confidence: high
related_solutions:
  - docs/solutions/healthkit/2026-03-04-all-data-sleep-awake-alignment.md
  - docs/solutions/healthkit/2026-03-06-step-detail-header-notification-total-sync.md
related_brainstorms: []
---

# Implementation Plan: Sleep All Data Time Anchor

## Context

Sleep 상세의 "Show All Data" 목록에서 각 행의 왼쪽 시간이 모두 동일하게 보인다. 현재 구현은 실제 수면 세션 시각이 아니라, 페이지 로드 시점의 `Date()`를 하루씩 감소시킨 조회 앵커를 그대로 `ChartDataPoint.date`로 저장하고 있어 같은 시각이 반복된다.

## Requirements

### Functional

- Sleep All Data 행은 실제 수면 세션을 대표하는 시각을 표시해야 한다.
- 섹션 헤더 날짜는 기존처럼 해당 수면이 귀속되는 일자 기준을 유지해야 한다.
- 기존 sleep duration 계산 정책(`awake` 제외)은 유지해야 한다.

### Non-functional

- 다른 metric category의 All Data 렌더링에는 영향을 주지 않아야 한다.
- 회귀를 막는 테스트를 추가해야 한다.

## Approach

`ChartDataPoint`에 행 표시용 시각을 위한 별도 필드를 추가하고, sleep category만 실제 stage 시작 시각을 넘긴다. 그룹핑/섹션 헤더는 day anchor(`startOfDay`)를 계속 사용해 날짜 귀속을 유지한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `ChartDataPoint.date`를 실제 sleep start로 교체 | 구현이 단순함 | 섹션 헤더가 전날로 밀려 현재 UX와 불일치 | 기각 |
| Sleep row에서 시간을 숨김 | 구조 변경이 적음 | 다른 metric과 표현 불균형, 정보 손실 | 기각 |
| 그룹용 날짜와 표시용 시각을 분리 | 날짜 귀속 유지, 실제 시각 표시 가능 | 모델 필드 1개 추가 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Charts/ChartModels.swift` | modify | `ChartDataPoint`에 optional display date 추가 |
| `DUNE/Presentation/Shared/Detail/AllDataViewModel.swift` | modify | sleep category에서 day anchor와 display time을 분리 |
| `DUNE/Presentation/Shared/Detail/AllDataView.swift` | modify | row/accessibility가 display date를 우선 사용하도록 변경 |
| `DUNETests/AllDataViewModelTests.swift` | modify | sleep row time anchor 회귀 테스트 추가 |

## Implementation Steps

### Step 1: Extend display model

- **Files**: `DUNE/Presentation/Shared/Charts/ChartModels.swift`
- **Changes**: `ChartDataPoint`에 `displayDate`를 추가하고 기존 호출부와 호환되는 initializer를 정의한다.
- **Verification**: 기존 `ChartDataPoint(date:value:)` 호출부가 컴파일 가능해야 한다.

### Step 2: Correct sleep all-data timestamp source

- **Files**: `DUNE/Presentation/Shared/Detail/AllDataViewModel.swift`, `DUNE/Presentation/Shared/Detail/AllDataView.swift`
- **Changes**: sleep fetch 시 `date`는 `startOfDay` anchor로 저장하고, `displayDate`는 non-awake sleep stages의 earliest `startDate`로 저장한다. view는 `displayDate ?? date`를 사용해 시간을 표시한다.
- **Verification**: sleep rows no longer show the page-load clock time; section headers remain on the queried day.

### Step 3: Add regression coverage

- **Files**: `DUNETests/AllDataViewModelTests.swift`
- **Changes**: sleep category data point가 section anchor와 display time을 분리하는지 검증한다.
- **Verification**: `AllDataViewModelTests` passes.

## Edge Cases

| Case | Handling |
|------|----------|
| Sleep day has only awake samples | 기존과 동일하게 row 생성하지 않음 |
| Sleep spans previous evening into current morning | section date는 current day anchor, row time은 actual earliest sleep start 사용 |
| Non-sleep categories | `displayDate == nil` default로 기존 동작 유지 |

## Testing Strategy

- Unit tests: `DUNETests/AllDataViewModelTests.swift`에 sleep time-anchor 회귀 테스트 추가
- Integration tests: 해당 없음
- Manual verification: Sleep metric 상세의 "Show All Data"에서 여러 날짜 row 시간이 서로 다른 실제 수면 시작 시각으로 보이는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `ChartDataPoint` 확장으로 다른 chart 코드 영향 | low | medium | explicit initializer로 기존 호출부 호환 유지 |
| Sleep startDate가 기대한 표시 semantics와 다를 수 있음 | medium | low | section date는 유지하고 display time만 교체해 UX 변화 범위 최소화 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 원인이 `AllDataViewModel` sleep branch에서 조회 앵커 날짜를 그대로 표시하는 것으로 명확하며, 수정 범위가 shared model + sleep branch + unit test로 제한된다.
