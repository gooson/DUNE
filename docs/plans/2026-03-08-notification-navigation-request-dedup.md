---
topic: notification-navigation-request-dedup
date: 2026-03-08
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
  - docs/solutions/architecture/2026-03-08-notification-navigation-multi-update-warning.md
  - docs/solutions/architecture/2026-03-02-watch-navigation-request-observer-update-loop.md
related_brainstorms: []
---

# Implementation Plan: Notification Navigation Request Dedup

## Context

Cold launch 또는 notification tap 타이밍에서 동일한 notification navigation request가 `ContentView`에 두 번 전달될 수 있다. `NotificationInboxManager`는 request를 `pendingNavigationRequest`에 저장한 뒤, 별도로 비동기 `NotificationCenter` post도 예약한다. 그 결과 startup `.task`의 pending consume과 `.onReceive`가 같은 request를 각각 처리할 수 있고, 현재 탭의 `NavigationPath`가 같은 프레임에 중복 갱신되며 `NavigationRequestObserver`/`NavigationAuthority bound path` warning으로 이어질 수 있다.

## Requirements

### Functional

- 동일 notification request는 앱 진입 흐름에서 한 번만 처리되어야 한다.
- active app 상태의 notification route delivery는 기존처럼 `.onReceive`로 즉시 처리되어야 한다.
- cold launch에서 pending request를 먼저 consume한 뒤 늦게 도착한 notification post는 무시되어야 한다.

### Non-functional

- 기존 notification routing contract를 깨지 않는다.
- 수정 범위는 notification request broker와 root routing handler에 한정한다.
- 중복 처리 방지 규칙을 unit test로 고정한다.

## Approach

`NotificationInboxManager`에 "이 request가 아직 pending이면 지금 소비한다"는 matching consume API를 추가하고, `ContentView`의 `.onReceive`가 실제 route 적용 전에 이 API로 ownership을 확인하도록 바꾼다. startup `.task`가 먼저 request를 가져간 경우 `.onReceive`는 no-op이 되므로 같은 request가 한 프레임 안에서 다시 path write를 만들지 않는다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `ContentView`에서 마지막 request를 state로 기억해 동일 request 무시 | 구현이 단순 | 사용자가 같은 알림을 다시 여는 정상 시나리오까지 막기 쉬움 | Rejected |
| `handleNotificationNavigationRequest()` 내부에서 path 동일성 비교 후 skip | path 중복 write 자체는 줄일 수 있음 | duplicate request broker 문제는 그대로 남고 non-push route signal 중복은 못 막음 | Rejected |
| `NotificationInboxManager` matching consume + `ContentView` gate | cold launch/foreground 양쪽 흐름을 모두 보존 | manager API가 조금 늘어남 | Selected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Persistence/NotificationInboxManager.swift` | modify | matching request consume API 추가 |
| `DUNE/App/ContentView.swift` | modify | notification route apply 전 pending ownership 확인 |
| `DUNETests/NotificationInboxManagerTests.swift` | modify | request가 한 번만 소비되는 contract 테스트 추가 |

## Implementation Steps

### Step 1: Add pending-request ownership gate

- **Files**: `DUNE/Data/Persistence/NotificationInboxManager.swift`
- **Changes**: matching request를 조건부로 소비하는 API 추가
- **Verification**: pending request가 없거나 이미 task에서 소비된 경우 false 반환

### Step 2: Apply gate before route handling

- **Files**: `DUNE/App/ContentView.swift`
- **Changes**: `.onReceive`에서 request를 바로 적용하지 않고 matching consume 성공 시에만 route 처리
- **Verification**: active app route는 계속 처리되고, startup pending + delayed post 중복 적용은 차단

### Step 3: Lock behavior with unit tests

- **Files**: `DUNETests/NotificationInboxManagerTests.swift`
- **Changes**: matching consume 성공/실패, pending consume 이후 duplicate post 무시 시나리오 테스트 추가
- **Verification**: `scripts/test-unit.sh --ios-only` 또는 최소 `xcodebuild` 대상 테스트 통과

## Edge Cases

| Case | Handling |
|------|----------|
| active app에서 새 request가 post될 때 | `.onReceive`가 matching consume에 성공하고 정상 처리 |
| cold launch에서 task가 먼저 pending request를 소비 | 이후 같은 request notification post는 matching consume 실패로 skip |
| 잘못된/mismatched request object가 전달될 때 | pending이 유지되고 route 처리도 하지 않음 |

## Testing Strategy

- Unit tests: `NotificationInboxManagerTests`에 matching consume contract 추가
- Integration tests: `NotificationExerciseDataTests` 기존 routing contract 유지 확인
- Manual verification: notification tap 후 console에서 multi-update warning 재발 여부 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| matching consume 조건이 너무 엄격해 정상 route를 놓침 | low | medium | exact same request를 `emitNavigationRequest`와 `.onReceive`가 공유하는 현재 구조에 맞춰 테스트 추가 |
| manager API 변경으로 기존 call site 누락 | low | low | 호출 지점 검색 후 단일 call site 교체 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: duplicate delivery 경로가 코드상 명확하고, 수정도 broker ownership gate 한 곳으로 수렴한다.
