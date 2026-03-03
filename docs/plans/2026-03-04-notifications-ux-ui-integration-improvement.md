---
topic: notifications-ux-ui-integration-improvement
date: 2026-03-04
status: draft
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
  - docs/solutions/general/2026-03-04-dashboard-notification-badge-clipping.md
  - docs/solutions/testing/2026-03-04-ui-test-max-hardening-and-axid-stability.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-notification-hub-ux-ui-integration-improvement.md
---

# Implementation Plan: Notifications UX/UI Integration Improvement

## Context

Notification hub가 기본 `List` 기반이라 Today 탭의 디자인 시스템(배경 wave, glass card, 카드 간 간격/모션)과 불일치한다.
또한 `route == nil` 알림 탭 시 이동이 발생하지 않아 사용자 관점에서 무반응처럼 보이는 UX 갭이 있다.
이번 변경은 시각 일관성, 아이콘 기반 가독성, 읽음/삭제 관리, 탭 시 항상 이동 가능한 정책을 동시에 달성한다.

## Requirements

### Functional

- Notification hub 화면을 디자인 시스템 기반 카드 레이아웃으로 교체
- 각 알림 row에 타입별 아이콘/목적지 힌트 표시
- 읽음/미읽음/삭제 액션 제공 (개별 + 전체)
- 알림 탭 시 항상 목적지로 이동
  - `route` 있으면 기존 deep link 사용
  - `route` 없으면 타입별 상세 화면(AllDataView category)으로 이동
  - 위 실패 시 fallback destination으로 이동
- 빈 상태에서 `알림 설정 열기` CTA 제공

### Non-functional

- 기존 notification routing 파이프라인(푸시 탭/인앱 탭) 회귀 없음
- reduce motion 접근성 설정 시 과도한 애니메이션 비활성
- 대량 알림(수십~수백)에서도 스크롤 성능 유지
- 테스트 규칙(`testing-required`) 충족: 저장소 로직 변경 테스트 추가

## Approach

`NotificationHubView`를 `ScrollView + LazyVStack + InlineCard` 구조로 재작성하고, 액션 툴바/헤더 요약/빈 상태 CTA를 통합한다.
읽음/삭제 상태 관리는 `NotificationInboxStore`/`NotificationInboxManager`에 메서드를 추가해 단일 소스에서 처리한다.
탭 이동은 `NotificationHubView` 내부 destination enum으로 처리하되, workout route는 기존 manager event emission 경로를 유지해 Activity 탭 전환 동작을 보존한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `List` 유지 + row 스타일만 강화 | 변경량 적음 | 카드형/헤더/모션 제어 제한 큼 | 기각 |
| 전역 `NotificationRoute` 확장(모든 타입) | 아키텍처 일관성 높음 | 앱 전역 routing 영향 큼, 리스크 큼 | 기각 (후속 고려) |
| Hub 내부 로컬 destination + 기존 route 병행 | 구현 리스크 낮고 즉시 UX 개선 가능 | route 체계가 이원화됨 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | update | 카드형 UI, 아이콘, 애니메이션, CTA, 항상 이동 정책 적용 |
| `DUNE/Data/Persistence/NotificationInboxStore.swift` | update | markUnread/delete/deleteAll 저장소 API 추가 |
| `DUNE/Data/Persistence/NotificationInboxManager.swift` | update | unread/delete facade 메서드 추가 |
| `DUNETests/NotificationInboxStoreTests.swift` | update | unread/delete 동작 단위 테스트 추가 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | update | 신규 AXID 상수 추가(필요 시) |
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` | update | Notification hub 핵심 액션 존재 검증 보강(필요 시) |

## Implementation Steps

### Step 1: Inbox Data Actions 확장

- **Files**: `NotificationInboxStore.swift`, `NotificationInboxManager.swift`
- **Changes**:
  - `markUnread(id:)`, `delete(id:)`, `deleteAll()` 추가
  - manager에서 변경 notification 전파
- **Verification**:
  - 단위 테스트로 unread count, 삭제 반영, idempotent 동작 확인

### Step 2: NotificationHubView UI 리디자인

- **Files**: `NotificationHubView.swift`
- **Changes**:
  - `ScrollView + LazyVStack + InlineCard`로 전환
  - 헤더(미읽음 카운트 + Read All + Delete)
  - 빈 상태 `EmptyStateView` + Settings CTA
  - 타입 아이콘/목적지 힌트/읽음 상태 시각 강화
  - reduce-motion 대응 row 등장 애니메이션
- **Verification**:
  - Today → Notifications 진입 및 렌더링 확인
  - read/delete 버튼 상태 및 빈 화면 전환 확인

### Step 3: Always-Navigable 정책 적용

- **Files**: `NotificationHubView.swift`
- **Changes**:
  - row 탭 시 `open(itemID:)` 호출
  - `route == nil`이면 타입별 상세 화면 destination으로 push
  - 목적지 결정 불가 시 fallback destination으로 이동
- **Verification**:
  - route 있는 항목: 기존 workout 라우팅 유지
  - route 없는 항목: AllDataView 상세로 이동
  - 데이터 없음 케이스: fallback/빈 상세 상태 확인

### Step 4: 테스트 및 안정화

- **Files**: `DUNETests/NotificationInboxStoreTests.swift`, (필요 시) UITest helper/smoke
- **Changes**:
  - unread/delete/deleteAll 회귀 테스트 추가
  - AXID 추가 시 smoke 테스트 갱신
- **Verification**:
  - `xcodebuild test ... -only-testing DUNETests/NotificationInboxStoreTests`
  - 앱 빌드/관련 smoke 테스트 실행 가능 범위 검증

## Edge Cases

| Case | Handling |
|------|----------|
| route 없는 알림 탭 | 타입별 상세 destination으로 강제 이동 |
| 알림이 탭 직전에 삭제됨 | 안전 fallback destination으로 이동 |
| 모든 알림 삭제 후 UI 상태 | 빈 상태 + 설정 CTA 즉시 노출 |
| 대량 항목 최초 진입 | LazyVStack + 간단 모션 + reduce motion 분기 |

## Testing Strategy

- Unit tests: `NotificationInboxStoreTests`에 markUnread/delete/deleteAll 추가
- Integration tests: Notification hub에서 read/delete/route-null 탭 이동 수동 검증
- Manual verification:
  - Today toolbar → Notifications
  - Read All/개별 read-unread
  - 개별/전체 삭제
  - route 있는 workout 알림 탭 후 Activity 상세 진입
  - route 없는 알림 탭 후 상세(AllData) 진입

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 기존 workout route 동작 회귀 | Medium | High | route 존재 시 기존 `open()` + global event 경로 유지 |
| ScrollView 전환으로 접근성/테스트 selector 변화 | Medium | Medium | AXID 유지/추가, smoke test 보강 |
| 삭제 API 추가로 저장소 상태 불일치 | Low | Medium | 저장소 단위 테스트로 count/item 상태 검증 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 변경이 notification 허브/저장소 국소 범위에 집중되어 있고, 기존 routing 파이프라인을 보존하는 방향이라 회귀 리스크를 낮출 수 있다.
