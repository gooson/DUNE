---
topic: iPad Activity 탭 sync 중 UI 무반응/스크롤 정지 재발 수정
date: 2026-03-02
status: implemented
confidence: high
related_solutions:
  - docs/plans/2026-03-02-activity-sync-lock-on-ipad.md
  - docs/solutions/general/2026-02-24-activity-pr-cardio-healthkit-review-fixes.md
  - docs/solutions/performance/2026-02-16-review-triage-task-cancellation-and-caching.md
  - docs/solutions/general/2026-02-26-review-fixes-refresh-feedback-doc-sync.md
related_brainstorms:
  - docs/brainstorms/2026-03-02-ipad-activity-tab-sync-ui-lock-fix.md
---

# Implementation Plan: iPad Activity 탭 sync UI lock fix

## Context

이전 수정으로 `loadActivityData` 재시작 폭주는 줄였지만, iPad에서 앱 실행 직후 Activity 탭 진입 시 여전히 무반응/스크롤 멈춤이 재발한다.
현재 구조에서 `recentRecords` sync 변화 시 파생 계산(추천 운동/피로/PR)이 짧은 간격으로 반복되고,
ActivityViewModel이 `@MainActor`에서 대량 계산을 수행해 메인 스레드 점유가 커질 수 있다.
또한 에러 노출이 하단 텍스트 중심이라 sync 실패 피드백이 즉시 인지되지 않는다.

## Requirements

### Functional

- Activity 탭 진입 직후 sync 변화가 연속 발생해도 UI 입력(스크롤/탭)이 유지되어야 한다.
- `recentRecords` 기반 파생 상태(추천, PR, streak 등)는 최신 상태를 유지해야 한다.
- sync 실패 시 상단 toast 형태의 non-blocking 에러 피드백 + 재시도 액션을 제공해야 한다.

### Non-functional

- 기존 refresh 아키텍처(`refreshSignal`, `AppRefreshCoordinator`)는 유지한다.
- 계산 정확도는 유지하되 메인 스레드 장시간 점유를 피한다.
- 기존 테스트와 API를 최대한 깨지 않도록 점진 변경한다.

## Approach

핵심은 “중복 계산을 합치고(coalescing), 한 번 계산할 때도 메인 점유를 짧게 쪼개는(yield) 것”이다.

1. `ActivityView`에서 `refreshSignal` 기반 HealthKit reload와 `recentRecords` 기반 파생 계산을 완전히 분리 유지
2. `recentRecords` 변화는 debounce + cancellation 가능한 async 경로로 합쳐 burst sync를 1회 계산으로 축약
3. ViewModel의 대량 루프(특히 카드 seed/파생 계산)에서 주기적 `Task.yield()` 적용으로 UI starvation 완화
4. Activity 탭 상단에 sync 에러 toast를 overlay로 노출하고 retry 액션 연결

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Background detached task로 파생 계산 전체 이관 | 메인 점유 최소화 | SwiftData 모델 캡처/Sendable 처리 복잡, 리스크 큼 | 미채택 |
| 현재 구조 유지 + debounce만 적용 | 변경 작음 | 단일 계산 자체가 무거우면 여전히 프레임 드랍 가능 | 부분 채택 |
| debounce + chunked yield + toast feedback | 리스크 대비 효과 높음, 현 구조와 호환 | 일부 계산은 여전히 메인 actor | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Activity/ActivityView.swift` | modify | records 변화 처리 task 분리, 상단 sync toast overlay + retry 추가 |
| `DUNE/Presentation/Activity/ActivityViewModel.swift` | modify | debounce 가능한 파생 계산 경로 추가, chunked yield, cardio seed 처리 개선 |
| `DUNETests/ActivityViewModelTests.swift` | modify | 새 async 파생 계산 경로(즉시/취소) 테스트 추가 |

## Implementation Steps

### Step 1: Activity records update coalescing

- **Files**: `DUNE/Presentation/Activity/ActivityView.swift`, `DUNE/Presentation/Activity/ActivityViewModel.swift`
- **Changes**:
  - `recentRecords` 변경 전용 update key 도입
  - debounce 가능한 async `refreshSuggestionFromRecords(...)` 경로 추가
  - 기존 sync update 호출을 records task 기반으로 치환
- **Verification**:
  - burst sync 상황에서 이전 task 취소 + 최신 계산만 반영되는지 확인

### Step 2: Main-thread load 분산

- **Files**: `DUNE/Presentation/Activity/ActivityViewModel.swift`
- **Changes**:
  - 대량 루프(파생 snapshot/seed 처리)에 주기적 `Task.yield()` 적용
  - seed 완료 후 필요한 파생값만 재계산하도록 범위 축소
- **Verification**:
  - Activity 탭 진입 후 스크롤 반응성 유지(수동 확인)
  - 기존 PR/streak/frequency 결과 회귀 없음 확인

### Step 3: Sync error top toast

- **Files**: `DUNE/Presentation/Activity/ActivityView.swift`
- **Changes**:
  - `viewModel.errorMessage`를 상단 overlay toast로 노출
  - auto-dismiss + retry 버튼 제공
- **Verification**:
  - 에러 발생 시 상단 toast 노출/자동 사라짐/재시도 동작 확인

### Step 4: Test updates

- **Files**: `DUNETests/ActivityViewModelTests.swift`
- **Changes**:
  - async records refresh 경로 검증 테스트 추가
  - cancellation 시 stale 반영 방지 테스트 추가
- **Verification**:
  - 대상 테스트 통과

## Edge Cases

| Case | Handling |
|------|----------|
| CloudKit 동기화로 records count가 짧은 시간에 연속 증가 | debounce + task cancellation으로 최종 1회 계산 |
| 계산 도중 새 sync 이벤트 도착 | 기존 task 취소 후 최신 snapshot으로 재시작 |
| sync 부분 실패 | 상단 toast + retry로 non-blocking 피드백 |
| 대용량 과거 workout seed | chunked yield로 메인 점유 분산 |

## Testing Strategy

- Unit tests: `ActivityViewModelTests`에 async refresh/coalescing/cancellation 케이스 추가
- Integration tests: 없음 (View trigger + ViewModel state path 중심 변경)
- Manual verification:
  - iPad 앱 시작 → Activity 탭 진입 즉시 스크롤/탭 반응성 확인
  - sync 중 연속 스크롤 시 멈춤 재현 여부 확인
  - 에러 상황에서 상단 toast 및 Retry 동작 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| debounce로 파생 UI 반영이 약간 늦어짐 | medium | low | 짧은 debounce(수백 ms) + 수동 refresh 경로 유지 |
| yield 주기 과다로 계산 완료 지연 | low | low | 배치 크기 조정(기본 80~120) |
| toast 상태와 기존 errorMessage 노출 중복 | low | low | Activity에서는 toast를 단일 피드백 경로로 정리 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 재발 원인(연속 sync 이벤트 + 메인 actor 대량 계산)과 대응(이벤트 coalescing + chunked yielding + 즉시 피드백)이 직접적으로 매칭되며, 기존 아키텍처를 크게 흔들지 않는다.
