---
topic: notification-badge-persistence-fix
date: 2026-03-04
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
  - docs/solutions/general/2026-03-04-dashboard-notification-badge-clipping.md
related_brainstorms: []
---

# Implementation Plan: Notification Badge Persistence Fix

## Context

알림 허브에서 읽음 처리(`Read All`, 개별 읽음, `Delete All`) 후에도 Today 툴바 뱃지 또는 앱 아이콘 배지가 즉시 0으로 정리되지 않는 현상이 재현되었다.
현재 구현은 inbox 변경 notification으로 UI 동기화를 시도하지만, 화면 재진입 타이밍과 시스템 badge 동기화 경로가 분리되어 있어 잔상 상태가 남을 수 있다.

## Requirements

### Functional

- unread가 0이 되면 Today 툴바 뱃지가 즉시 사라져야 한다.
- unread 변경 시 iOS 앱 아이콘 badge 수치도 동일하게 동기화되어야 한다.
- 기존 알림 허브 기능(read/unread/delete/navigation)은 유지되어야 한다.

### Non-functional

- 변경 범위는 Notification inbox 흐름과 Dashboard 표시 로직으로 제한한다.
- 테스트 가능하도록 side effect(시스템 badge 반영)를 주입 가능한 형태로 만든다.

## Approach

`NotificationInboxManager`를 unread 상태 변경의 단일 source로 사용해, `inboxDidChange` 이벤트 발행과 시스템 badge 갱신을 한 지점에서 실행한다.
그리고 `DashboardView`는 화면 재진입(`onAppear`)마다 unread를 재조회해 이벤트 누락 시에도 최종 상태를 맞춘다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Dashboard `onReceive`만 유지 | 코드 변경 최소 | 백스택/재진입 타이밍에서 갱신 누락 가능 | ❌ |
| Dashboard에서만 `onAppear` 재조회 추가 | UI 잔상 일부 해결 | 앱 아이콘 badge 불일치가 남음 | ❌ |
| Manager에서 이벤트+시스템 badge 동기화 + Dashboard 재진입 재조회 | UI/시스템 상태 동시 정합성 확보 | Manager 의존성(UNUserNotificationCenter) 추가 | ✅ |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Persistence/NotificationInboxManager.swift` | modify | unread 변경 시 시스템 badge 동기화 훅 추가, 주입 가능한 `badgeUpdater` 도입 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | modify | 화면 재진입 시 unread count 재동기화(`onAppear`) 추가 |
| `DUNETests/NotificationInboxManagerTests.swift` | add | `markAllRead`, `deleteAll` 후 badge 0 동기화 회귀 테스트 추가 |

## Implementation Steps

### Step 1: Manager badge sync 단일화

- **Files**: `DUNE/Data/Persistence/NotificationInboxManager.swift`
- **Changes**:
  - `badgeUpdater` 의존성 주입(기본값: `UNUserNotificationCenter.setBadgeCount`)
  - `postInboxDidChange()`에서 unread count 계산 후 notification post + badge update 동시 수행
- **Verification**:
  - read/unread/delete 동작 이후 동일 경로로 badge update가 호출되는지 확인

### Step 2: Dashboard 재진입 동기화 보강

- **Files**: `DUNE/Presentation/Dashboard/DashboardView.swift`
- **Changes**:
  - `.onAppear { reloadUnreadCount() }` 추가
- **Verification**:
  - NotificationHub에서 뒤로 돌아올 때 unread가 0이면 뱃지가 즉시 사라지는지 확인

### Step 3: 회귀 테스트 추가

- **Files**: `DUNETests/NotificationInboxManagerTests.swift`
- **Changes**:
  - `badgeUpdater` 테스트 더블(`BadgeRecorder`)로 호출 결과 캡처
  - `markAllRead`, `deleteAll` 경로에서 마지막 badge 값이 0인지 검증
- **Verification**:
  - 신규 테스트가 통과하고 기존 store 테스트와 충돌이 없는지 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 이미 unread=0 상태에서 변경 API 호출 | badgeUpdater가 0으로 재동기화되어 상태 일치 유지 |
| 화면 전환 중 이벤트 miss | `DashboardView.onAppear`에서 store 기준 재조회 |
| 시스템 badge API 실패 | 로깅 후 앱 내부 unread 상태는 유지 |

## Testing Strategy

- Unit tests: `NotificationInboxManagerTests`, `NotificationInboxStoreTests`
- Integration tests: 해당 없음
- Manual verification: NotificationHub에서 `Read All`/`Delete All` 후 Today 복귀 시 뱃지 사라짐 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| badgeUpdater 비동기 타이밍으로 테스트 flaky | Medium | Low | polling 기반 wait helper + 마지막 값 검증 |
| UNUserNotificationCenter badge API 실패 | Low | Medium | 에러 로깅 + UI unread는 store 기준으로 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: unread 상태 변경 경로가 `NotificationInboxManager`로 집중되어 있어 단일 지점 동기화가 가능하고, 단위 테스트로 회귀를 방지했다.
