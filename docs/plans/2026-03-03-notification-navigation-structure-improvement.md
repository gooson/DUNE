---
topic: notification-navigation-structure-improvement
date: 2026-03-03
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
related_brainstorms:
  - docs/brainstorms/2026-03-03-notification-navigation-structure-improvement.md
  - docs/brainstorms/2026-03-03-healthkit-background-notifications.md
---

# Implementation Plan: Notification Navigation Structure Improvement

## Context

Today 탭에서 알림 접근 지점이 없고, 푸시/알림 내역 탭 시 운동 상세 이동 규칙이 구현되어 있지 않다.
요구사항은 벨 아이콘 기반 알림 허브, 최신순 리스트, 읽음/미읽음, 무제한 보관, 푸시/내역 탭 시 운동 상세 이동, 대상 누락 fallback이다.

## Requirements

### Functional

- Today 탭 상단 벨 아이콘에서 알림 허브 진입
- 알림 허브는 최신순 정렬
- 읽음/미읽음 상태 관리 + 전체 읽음 처리
- 로컬 알림 발송 시 알림 히스토리 저장
- 푸시 탭/허브 탭 시 해당 운동 상세 화면으로 이동
- 이동 시 기존 NavigationStack 유지
- 대상 운동이 없으면 not found 화면 표시

### Non-functional

- 기존 HealthKit observer/notification 흐름과 충돌 없이 동작
- UserDefaults key는 bundle prefix 규칙 준수
- 신규 저장소/모델에 대한 유닛 테스트 추가
- iPhone/iPad 동작 동일, Watch는 기존 미러링 정책과 충돌 없음

## Approach

- `NotificationInboxStore`(UserDefaults)로 알림 히스토리/읽음 상태를 영속화
- `NotificationInboxManager`에서 저장소 + 라우팅 이벤트를 단일 진입점으로 관리
- `NotificationServiceImpl`에서 로컬 알림 발송 시 `userInfo`에 route payload 포함
- `UNUserNotificationCenterDelegate`를 앱에 연결해 푸시 탭 이벤트를 라우팅 이벤트로 변환
- `ContentView`에서 라우팅 이벤트를 받아 Activity 탭으로 전환 후 대상 ID 전달
- `ActivityView`에서 대상 workout을 찾고, 있으면 상세 push / 없으면 fallback push
- `DashboardView` toolbar에 벨 아이콘 및 unread badge 추가, 허브 화면 연결

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 전역 NavigationPath 도입 | 외부 라우팅 일원화 | 기존 탭 구조 대규모 변경 | 기각 |
| 딥링크 URL만 사용 | 시스템 표준 활용 | 내부 리스트 탭 라우팅과 분리됨 | 기각 |
| 알림 허브를 SwiftData로 저장 | 확장성 높음 | 스키마/마이그레이션 범위 확대 | 기각 |
| UserDefaults + 이벤트 브로커 | 구현 범위 최소, 빠른 적용 | 동기화 범위 제한 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Models/HealthInsight.swift` | update | 알림 route 메타데이터 확장 |
| `DUNE/Domain/Models/NotificationInboxItem.swift` | add | 알림 허브 도메인 모델 추가 |
| `DUNE/Data/Persistence/NotificationInboxStore.swift` | add | 알림 히스토리/읽음 상태 저장소 |
| `DUNE/App/NotificationInboxManager.swift` | add | 저장/라우팅 이벤트 관리 |
| `DUNE/App/AppNotificationCenterDelegate.swift` | add | 푸시 탭 응답 처리 delegate |
| `DUNE/Data/Services/NotificationServiceImpl.swift` | update | 히스토리 저장 + route userInfo 포함 |
| `DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift` | update | workout PR insight에 workout route 부여 |
| `DUNE/App/DUNEApp.swift` | update | notification center delegate 연결 |
| `DUNE/App/ContentView.swift` | update | 라우팅 이벤트 수신 + 탭 전환 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | update | 벨 아이콘 + unread badge + 허브 진입 |
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | add | 최신순 허브, 읽음/미읽음 UI |
| `DUNE/Presentation/Activity/ActivityView.swift` | update | 외부 route로 상세 push/not found 처리 |
| `DUNE/Presentation/Shared/NotificationTargetNotFoundView.swift` | add | 대상 누락 fallback 화면 |
| `DUNETests/NotificationInboxStoreTests.swift` | add | 신규 저장소 테스트 |

## Implementation Steps

### Step 1: Data/Domain 기반 구축

- **Files**: `HealthInsight.swift`, `NotificationInboxItem.swift`, `NotificationInboxStore.swift`, `NotificationInboxStoreTests.swift`
- **Changes**:
  - 알림 route 모델 추가
  - 알림 허브 item 모델 정의
  - UserDefaults 기반 append/load/markRead/markAllRead/unreadCount 구현
  - 정렬/읽음 상태 테스트 추가
- **Verification**:
  - `NotificationInboxStoreTests` 통과
  - store API가 최신순 및 읽음 상태를 정확히 반영

### Step 2: Notification 파이프라인 연결

- **Files**: `NotificationInboxManager.swift`, `AppNotificationCenterDelegate.swift`, `NotificationServiceImpl.swift`, `BackgroundNotificationEvaluator.swift`, `DUNEApp.swift`
- **Changes**:
  - send 시 히스토리 저장 및 route userInfo 포함
  - workout PR 알림에 workout ID route 주입
  - 푸시 탭 응답을 앱 라우팅 이벤트로 변환
- **Verification**:
  - `NotificationServiceImpl` 경로에서 item 생성 + userInfo 포함 확인
  - delegate 수신 시 pending route 생성 확인

### Step 3: UI/Navigation 연결

- **Files**: `ContentView.swift`, `DashboardView.swift`, `NotificationHubView.swift`, `ActivityView.swift`, `NotificationTargetNotFoundView.swift`
- **Changes**:
  - Today toolbar 벨 아이콘 + unread badge
  - 허브 화면 최신순 리스트, 읽음/미읽음, 모두 읽음
  - 허브/푸시 탭 이벤트 수신 시 Activity 탭 전환
  - 운동 상세 push 또는 not found push
- **Verification**:
  - 수동 플로우: Today -> 허브 -> 알림 탭 -> Activity 상세 이동
  - 수동 플로우: 존재하지 않는 ID -> not found 표시

### Step 4: Quality Check & 문서 반영

- **Files**: 변경 파일 전체
- **Changes**:
  - iOS 빌드/테스트
  - self-review 및 리뷰 이슈 수정
  - plan/solution 문서 상태 업데이트
- **Verification**:
  - `xcodebuild` 빌드/테스트 통과
  - P1 이슈 0건 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 앱 실행 전 푸시 탭 이벤트 수신 | manager pending queue로 보관 후 ContentView 시작 시 소비 |
| 동일 알림 중복 탭 | 읽음 상태 idempotent 처리 |
| 라우트 대상이 recentWorkouts에 없음 | Activity에서 not found fallback push |
| unread badge 과도한 숫자 | UI 표시는 `99+` 캡 |

## Testing Strategy

- Unit tests:
  - `NotificationInboxStoreTests` (정렬, 읽음, 모두 읽음, unread count)
- Integration tests:
  - `xcodebuild test`에서 `DUNETests` 실행
- Manual verification:
  - Today 벨 아이콘 진입
  - 허브 최신순/읽음 상태
  - 허브 탭 및 푸시 탭 라우팅
  - not found fallback

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 탭 전환 시점과 route 소비 타이밍 불일치 | medium | medium | pending route 소비 + signal 기반 재트리거 |
| 알림 히스토리 무제한 보관으로 defaults 크기 증가 | medium | low | JSON decode 실패 시 복구, 향후 paging/archiving 확장 |
| 푸시 userInfo 누락 시 라우팅 실패 | low | medium | itemID + routeKind/workoutID 이중 저장 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 알림/탭 구조 위에 얹는 변경이라 영향 범위가 다소 넓지만, 저장소/이벤트/화면 연결을 단계 분리해 리스크를 제한할 수 있다.
