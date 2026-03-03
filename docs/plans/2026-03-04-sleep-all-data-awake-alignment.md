---
topic: sleep-all-data-awake-alignment
date: 2026-03-04
status: implemented
confidence: high
related_solutions:
  - docs/solutions/healthkit/2026-02-24-sleep-dedup-watch-detection.md
related_brainstorms: []
---

# Implementation Plan: Align AllData Sleep Duration With Existing Sleep Policy

## Context

`AllDataViewModel`의 sleep 경로가 `awake` 시간을 포함해 총합을 계산하면서, 동일 앱 내 다른 수면 경로(`SleepSummary`, `MetricDetailViewModel`, `SleepQueryService`)의 정책(awake 제외)과 불일치가 발생했다.  
기존 이력(2026-02-24 sleep dedup 교정)에서도 수면 지표 일관성은 핵심 규칙으로 관리되고 있다.

## Requirements

### Functional

- `AllDataViewModel`의 sleep 합산은 `awake` stage를 제외해야 한다.
- 기존 테스트 `Sleep category includes only days with positive sleep duration`이 통과해야 한다.

### Non-functional

- 기존 HealthKit dedup 정책(동일 소스 overlap 유지)과 충돌하지 않아야 한다.
- 다른 metric 경로(HRV/RHR/steps 등)에는 영향이 없어야 한다.

## Approach

`AllDataViewModel.fetchData()`의 `case .sleep`에서 stage 합산 직전에 `awake` stage를 필터링한다.  
변경 범위는 단일 분기 로직으로 제한하고, 기존 테스트로 회귀를 확인한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `AllDataViewModel`에서 `awake` 제외 필터 적용 | 최소 변경, 현재 정책과 즉시 정렬 | 경로별 정책 중복은 유지 | Selected |
| `SleepQueryService`에서 반환 자체를 non-awake로 제한 | 호출부 단순화 | stage 원본이 필요한 화면(분해 차트)에 부작용 가능 | Rejected |
| sleep 정책을 별도 shared helper로 추출 | 장기 일관성 향상 | 이번 이슈 범위를 넘어 구조 변경 커짐 | Deferred |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Detail/AllDataViewModel.swift` | modify | sleep total minutes 계산 시 `awake` 제외 |

## Implementation Steps

### Step 1: Sleep 합산 로직 일치화

- **Files**: `DUNE/Presentation/Shared/Detail/AllDataViewModel.swift`
- **Changes**: `stages.reduce(...)`를 `stages.filter { $0.stage != .awake }.reduce(...)`로 변경
- **Verification**: 컴파일 오류 없음, sleep 분기에서 `total > 0` 필터 동작 유지

### Step 2: 회귀 검증

- **Files**: `DUNETests/AllDataViewModelTests.swift` (기존 테스트 사용)
- **Changes**: 없음
- **Verification**: `-only-testing DUNETests/AllDataViewModelTests` 통과

## Edge Cases

| Case | Handling |
|------|----------|
| 하루 데이터가 전부 `awake`만 존재 | 합계 0분 → 기존 로직대로 데이터 포인트 제외 |
| mixed stage(`awake` + `core/rem/deep`) | non-awake stage만 합산되어 실제 수면 시간만 반영 |
| sleep stage 없음 | 합계 0분으로 처리, pagination 동작 유지 |

## Testing Strategy

- Unit tests: `AllDataViewModelTests`의 sleep 케이스 포함 전체 스위트 실행
- Integration tests: 없음 (범위 외)
- Manual verification: 필요 시 All Data 화면 sleep 값과 Sleep 상세 값 비교

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| “time in bed”를 원하는 기대와 충돌 | medium | medium | 제품 정의를 명시하고 용어 분리(time in bed vs sleep duration) |
| 경로별 정책 중복으로 재발 | medium | medium | 후속으로 shared sleep-total helper 추출 검토 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 문서화된 정책과 테스트 기대값이 동일 방향이며, 변경이 단일 분기에 국한된다.
