---
topic: steps detail header and notification total sync
date: 2026-03-06
status: implemented
confidence: high
related_solutions:
  - docs/solutions/healthkit/2026-03-06-step-detail-header-notification-total-sync.md
  - docs/solutions/healthkit/healthkit-deduplication-best-practices.md
related_brainstorms: []
---

# Implementation Plan: Steps Detail Header And Notification Total Sync

## Context

Steps 상세 화면의 큰 숫자와 step goal 알림 문구가 사용자가 보는 실제 오늘 총합과 어긋날 수 있었다. `/run` 품질 게이트도 별도 동시성 오류 때문에 막혀 있어 함께 정리해야 했다.

## Requirements

### Functional

- Steps 상세 헤더는 현재 선택 기간 데이터와 일치해야 한다.
- Step goal 알림은 anchored sample incremental sum이 아니라 실제 오늘 총합을 기준으로 만들어야 한다.
- strict concurrency 빌드 차단 오류를 제거해야 한다.

### Non-functional

- 기존 HealthKit query 패턴을 유지한다.
- 회귀 테스트를 추가한다.
- 변경 범위는 steps/notification 관련 경로로 제한한다.

## Approach

Steps 상세 헤더는 ViewModel이 로드한 period-aware current value를 사용하고, step goal 평가는 `StepsQueryService.fetchSteps(for:)`로 authoritative total을 다시 조회한다. 별도 build blocker인 `WorkoutTypeCorrectionStore.shared`는 `@unchecked Sendable`로 strict concurrency를 통과시킨다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| step 샘플 incremental sum 유지 | 구현 변경이 작음 | observer delivery 단위에 따라 실제 총합과 어긋남 | 기각 |
| Background evaluator에서 HKStatisticsQuery 직접 추가 | authoritative total 확보 | steps query 경로 중복 | 기각 |
| `WorkoutTypeCorrectionStore`를 actor로 전환 | 이론적으로 가장 엄격 | 기존 동기 call site 대량 수정 필요 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | update | Steps 헤더 값 바인딩 보정 |
| `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift` | update | period-aware steps currentValue 계산 추가 |
| `DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift` | update | step goal resolver 도입, authoritative total 사용 |
| `DUNE/Data/Persistence/WorkoutTypeCorrectionStore.swift` | update | strict concurrency build blocker 해소 |
| `DUNETests/MetricDetailViewModelTests.swift` | update | steps 헤더 회귀 테스트 강화 |
| `DUNETests/BackgroundNotificationEvaluatorTests.swift` | add | step goal resolver 테스트 추가 |

## Implementation Steps

### Step 1: Steps 상세 헤더 동기화

- **Files**: `MetricDetailView.swift`, `MetricDetailViewModel.swift`
- **Changes**: steps 카테고리에서 ViewModel currentValue 사용, period별 currentValue 계산
- **Verification**: 주간 테스트 데이터에서 헤더가 오늘 슬롯 값으로 덮이는지 확인

### Step 2: Step notification 총합 정렬

- **Files**: `BackgroundNotificationEvaluator.swift`
- **Changes**: sample sum cache 제거, `fetchSteps(for:)` 기반 resolver 사용
- **Verification**: 작은 sample payload로도 실제 today total 기준으로 threshold 판단하는 테스트 추가

### Step 3: Build blocker 제거

- **Files**: `WorkoutTypeCorrectionStore.swift`
- **Changes**: strict concurrency가 허용하도록 sendability 선언 추가
- **Verification**: xcodebuild/test 재실행

## Edge Cases

| Case | Handling |
|------|----------|
| 오늘 steps 데이터가 0인 경우 | 상세 헤더도 0 유지 |
| anchored query payload에 0-step sample만 들어오는 경우 | 알림 미발송 |
| UserDefaults-backed singleton strict concurrency 경고 | `@unchecked Sendable`로 명시 |

## Testing Strategy

- Unit tests: `MetricDetailViewModelTests`, `BackgroundNotificationEvaluatorTests`
- Integration tests: `xcodebuild test`로 DUNETests 일부/전체 실행
- Manual verification: Steps 상세 주간 화면과 step goal notification body 비교

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| steps header가 비-steps 화면에 영향 | low | medium | steps category에서만 새 currentValue 사용 |
| notification total query가 background에서 실패 | low | medium | 실패 시 nil 반환 + 로그 기록 |
| `@unchecked Sendable` 오남용 | medium | low | UserDefaults-only store라는 전제 주석 추가 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: UI와 notification 모두 동일한 authoritative total 경로로 정렬했고, 회귀 테스트를 추가했다. 남은 리스크는 전체 워크스페이스 빌드 상태에 달려 있다.
