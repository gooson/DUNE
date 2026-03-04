---
topic: notification-hub-chart-detail-routing
date: 2026-03-04
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
  - docs/solutions/general/2026-03-04-notification-hub-ux-ui-integration-improvement.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-notification-hub-ux-ui-integration-improvement.md
---

# Implementation Plan: Notification Hub Chart Detail Routing

## Context

Notification Hub에서 알림 항목을 탭하면 `route == nil` 케이스가 `AllDataView`(데이터 리스트)로 이동한다.
요구사항은 리스트 화면 대신 차트가 포함된 상세 화면(`MetricDetailView`)으로 이동해, 탭 직후 인사이트 맥락을 더 빠르게 이해할 수 있게 하는 것이다.

## Requirements

### Functional

- Notification Hub에서 `route == nil` 알림 탭 시 `AllDataView`가 아니라 차트 상세 화면으로 이동한다.
- `route != nil`(운동 PR) 딥링크 동작은 기존과 동일하게 유지한다.
- 알림 타입별(`HRV/RHR/Sleep/Steps/Body`) 상세 카테고리 매핑은 유지한다.

### Non-functional

- 기존 NotificationInboxManager 이벤트 플로우를 변경하지 않는다.
- 오래된 알림/비정형 메시지에서도 크래시 없이 동작한다.
- 회귀 방지를 위한 단위 테스트를 추가한다.

## Approach

`NotificationHubView` 내부에 "알림 -> HealthMetric 상세 모델" 변환기를 추가하고,
`HubDestination.metric`이 `HealthMetric.Category` 대신 `HealthMetric`을 보유하도록 변경한다.
탭 시 변환된 metric으로 `MetricDetailView(metric:)`를 push한다.

알림 본문에서 값 파싱이 가능한 경우(예: `37ms`, `70.5kg`, `7h 20m`)는 해당 값을 현재값으로 사용하고,
파싱이 불가능하면 안전한 기본값(0)으로 fallback하여 차트 로딩 자체는 보장한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| NotificationRoute를 `metricDetail`까지 확장 | 구조적으로 명확하고 push/허브 경로 통합 가능 | 도메인/저장소/알림 userInfo 스키마 확장 범위가 큼 | 기각 |
| NotificationHub에서 DashboardViewModel 값을 주입받아 상세 생성 | 현재값 정확도 높음 | 화면 간 결합도 증가, cold path 복잡도 증가 | 기각 |
| Hub 내부에서 lightweight 변환기로 `HealthMetric` 생성 | 변경 범위 최소, 기존 라우팅 구조 유지 | 일부 케이스에서 현재값 fallback(0) 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | update | 알림 탭 destination을 `MetricDetailView`로 전환, metric 변환/파싱 로직 추가 |
| `DUNETests/DomainModelCoverageTests.swift` | update | 알림 본문 파싱 및 category 매핑 단위 테스트 추가 |

## Implementation Steps

### Step 1: Notification Hub 라우팅 전환

- **Files**: `NotificationHubView.swift`
- **Changes**:
  - `HubDestination.metric` payload를 `HealthMetric` 기반으로 변경
  - `navigationDestination`에서 `MetricDetailView(metric:)`로 연결
  - `route == nil` 알림 탭 시 metric 변환 후 상세 push
- **Verification**:
  - 빌드 성공
  - Notification Hub 알림 탭 시 차트 상세 화면 진입

### Step 2: 값 파싱/매핑 안정화 + 테스트

- **Files**: `NotificationHubView.swift`, `DomainModelCoverageTests.swift`
- **Changes**:
  - insight 타입별 카테고리 매핑 유틸 분리
  - 본문 숫자 파싱(일반 숫자 + sleep 시/분 형식) 추가
  - 파서/매퍼 단위 테스트 추가
- **Verification**:
  - 신규 테스트 통과
  - 파싱 실패 케이스에서도 크래시 없이 fallback 동작

## Edge Cases

| Case | Handling |
|------|----------|
| 본문 숫자 포맷이 비정형이라 파싱 실패 | 값 `0` fallback으로 상세 진입은 유지 |
| 오래된 workoutPR 알림에 route가 없음 | `exercise` category metric fallback으로 상세 진입 |
| 알림 item 조회 실패(open nil) | 기존과 동일하게 unavailable 화면으로 이동 |

## Testing Strategy

- Unit tests: `NotificationHub` 변환기(category 매핑, 숫자 파싱, sleep 파싱) 검증
- Integration tests: `xcodebuild test`에서 `DUNETests` 대상 실행
- Manual verification: Today → Notifications → 알림 탭 시 MetricDetail(차트) 진입 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 본문 파싱 규칙이 locale별 문구를 완전히 커버하지 못함 | medium | low | 파싱 실패 fallback + 추후 locale 패턴 확장 가능 구조 유지 |
| 현재값 fallback(0)이 일부 카드에서 일시적으로 부정확하게 보임 | medium | low | 차트/요약은 로딩 후 정상 반영, 향후 route schema 확장 검토 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 변경이 `NotificationHubView` 단일 진입점에 집중되고, 기존 route 기반 딥링크 경로를 건드리지 않아 회귀 위험이 낮다.
