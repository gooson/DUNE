---
topic: Activity 탭 동기화 중 로딩 락(아이패드) 완화
date: 2026-03-02
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-02-28-coordinated-healthkit-refresh.md
  - docs/solutions/general/2026-02-26-review-fixes-refresh-feedback-doc-sync.md
related_brainstorms: []
---

# Implementation Plan: Activity Sync Lock on iPad

## Context

아이패드에서 Activity 탭 진입 직후 CloudKit/SwiftData 동기화가 진행되면 `recentRecords.count`가 빠르게 변동한다.
현재 `ActivityView`는 `.task(id: "\(recentRecords.count)-\(refreshSignal)")` 구조로 인해 동기화 이벤트마다 기존 로딩 task를 취소/재시작한다.
초기 로드가 반복적으로 중단되면 사용자는 "동기화 중 멈춤(락)"으로 인식한다.

## Requirements

### Functional

- Activity 초기 로딩은 데이터 동기화 변화와 분리되어 안정적으로 완료되어야 한다.
- `recentRecords` 변경 시 추천 운동/부상 충돌 계산은 계속 갱신되어야 한다.
- 외부 refresh signal(포그라운드/HK observer)은 기존처럼 Activity 재로드를 트리거해야 한다.

### Non-functional

- 탭 간 refresh 아키텍처 일관성 유지 (`Dashboard`, `Wellness`와 동일한 `task(id: refreshSignal)` 패턴).
- 불필요한 HealthKit 재질의를 줄여 UI 멈춤 가능성 감소.

## Approach

`ActivityView`에서 heavy async 로드(`loadActivityData`)를 `refreshSignal` 기반 task로만 실행하고,
`recentRecords` 동기화 변화는 별도 `onChange`에서 경량 연산(`updateSuggestion`, `recomputeInjuryConflicts`)만 수행한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 task id 유지 + ViewModel cancellation 처리 강화 | 최소 변경 | 취소 폭주 자체는 남음, 복잡도 증가 | 미채택 |
| `recentRecords` 변화마다 debounce task | 중간 수준 완화 | debounce/timer 상태 관리 추가 필요 | 미채택 |
| 로드 트리거와 레코드 동기화 트리거 분리 | 구조 단순, 원인 직접 제거 | 초기 1회 구조 정리 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Activity/ActivityView.swift` | modify | `.task(id:)` 트리거 분리 및 records update key 추가 |

## Implementation Steps

### Step 1: 로딩 task 트리거 분리

- **Files**: `DUNE/Presentation/Activity/ActivityView.swift`
- **Changes**: `task id`를 `refreshSignal` 전용으로 변경
- **Verification**: 동기화 중 count 변화가 로딩 task 취소를 유발하지 않는지 코드 경로 확인

### Step 2: 동기화 변화 처리 경량화

- **Files**: `DUNE/Presentation/Activity/ActivityView.swift`
- **Changes**: `recentRecordsUpdateKey` 계산 후 `onChange`에서 suggestion/conflict만 갱신
- **Verification**: `recentRecords` 변경 시 UI 파생 데이터는 갱신되되 HealthKit 재호출은 발생하지 않음

## Edge Cases

| Case | Handling |
|------|----------|
| 동기화 중 레코드가 연속 변경 | onChange 경량 처리만 반복 수행 |
| 포그라운드 복귀/observer refresh | refreshSignal task가 단일 reload 수행 |
| 수동 pull-to-refresh | 기존 `waveRefreshable` 경로 유지 |

## Testing Strategy

- Unit tests: 기존 `ActivityViewModelTests` 회귀 확인
- Integration tests: 없음 (View trigger 분리 변경)
- Manual verification: iPad에서 Activity 탭 진입 후 동기화 진행 중 스피너 고착 여부 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 레코드 변경 시 일부 파생 상태 갱신 누락 | low | medium | `updateSuggestion + recomputeInjuryConflicts`를 onChange로 분리 |
| refreshSignal 누락 시 초기 로드 미실행 | low | high | `.task(id: refreshSignal)`는 initial run 보장 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 취소 폭주를 유발하는 트리거 결합을 제거하는 직접적 수정이며, 기존 탭 패턴과 일관된다.
