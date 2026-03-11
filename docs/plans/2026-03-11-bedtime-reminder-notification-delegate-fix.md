---
topic: bedtime-reminder-notification-delegate-fix
date: 2026-03-11
status: draft
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-04-sleep-notification-cold-start-crash.md
  - docs/solutions/general/2026-03-08-general-bedtime-reminder.md
  - docs/solutions/general/2026-03-08-review-followup-state-and-migration-fixes.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-general-bedtime-reminder.md
---

# Implementation Plan: Bedtime Reminder Notification Delegate Fix

## Context

취침시간 안내 알림이 표시된 뒤 탭해도 화면 전환이 되지 않고, foreground 상태에서 Notification Center 목록에도 남지 않는 회귀가 보고되었다.
현재 조사 결과 `sleepDetail` payload 자체는 `NotificationInboxManager`와 `ContentView`에서 정상 라우팅되며, 실제 회귀 지점은 `AppNotificationCenterDelegate`에 집중되어 있다.

## Requirements

### Functional

- 취침시간 안내 알림 탭 시 `sleepDetail` route가 Wellness 수면 상세로 전달되어야 한다.
- 앱이 foreground일 때 표시되는 취침시간 안내 알림이 시스템 Notification Center 목록에도 남아야 한다.
- 기존 `sleepDetail` 및 기타 notification route 동작을 깨뜨리지 않아야 한다.

### Non-functional

- 변경 범위는 notification delegate와 해당 회귀 테스트에 한정한다.
- 기존 notification routing / pending request dedup 패턴을 유지한다.
- Swift Testing 기반 회귀 테스트를 추가한다.

## Approach

`AppNotificationCenterDelegate`에 두 가지 수정을 적용한다.

1. foreground presentation options에 `.list`를 추가해 banner가 Notification Center에도 기록되게 한다.
2. `didReceive`의 response forwarding을 `MainActor.run`으로 이동시켜 notification tap 처리와 SwiftUI navigation state 갱신이 main actor에서 일어나도록 복원한다.

테스트는 delegate의 presentation 옵션과 response forwarding helper를 검증하는 방향으로 추가한다. `UNNotificationResponse` 직접 생성이 불편하므로, userInfo forwarding을 분리 가능한 내부 helper로 노출해 주입형 spy로 검증한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `AppNotificationCenterDelegate`만 복원 | 최소 변경, 현재 증상과 직접 연결, 기존 routing 테스트 재사용 가능 | 앱 내부 notification hub 기록 문제는 그대로 남음 | 선택 |
| bedtime reminder를 `NotificationServiceImpl` 경로로 통합 | 앱 inbox 기록까지 해결 가능 | `HealthInsight` 모델/반복 알림 dedupe까지 바뀌어 범위가 커짐 | 이번 hotfix 범위에서 제외 |
| `NotificationInboxStore`에 generic append API 추가 | bedtime reminder만 별도 기록 가능 | 새 persistence contract와 icon/type semantics 결정이 필요 | 이번 hotfix 범위에서 제외 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/AppNotificationCenterDelegate.swift` | modify | foreground options 및 main-actor tap forwarding 복원 |
| `DUNETests/AppNotificationCenterDelegateTests.swift` | add | delegate 회귀 테스트 추가 |

## Implementation Steps

### Step 1: Restore delegate behavior

- **Files**: `DUNE/App/AppNotificationCenterDelegate.swift`
- **Changes**:
  - foreground presentation option 상수를 도입하고 `.list` 포함
  - response forwarding internal helper 추가
  - `didReceive`에서 helper 호출을 통해 main actor로 forwarding
- **Verification**:
  - `AppNotificationCenterDelegateTests`에서 `.list` 포함 여부 확인
  - `sleepDetail` payload가 spy handler로 전달되는지 확인

### Step 2: Run focused notification regression checks

- **Files**: `DUNETests/AppNotificationCenterDelegateTests.swift`, 기존 notification test files
- **Changes**:
  - delegate 전용 테스트 추가
  - 필요 시 기존 notification routing 테스트와 충돌 없는지 확인
- **Verification**:
  - `swift test` 또는 대상 테스트 실행으로 delegate + notification routing 회귀 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 앱 cold start 상태에서 notification tap | request forwarding을 main actor에서 수행하고 기존 pending request 소비 경로 유지 |
| foreground 상태에서 notification banner 표시 | `.banner`와 `.list`를 동시에 유지해 즉시 노출 + Notification Center 기록 둘 다 보장 |
| route 없는 기존 notification | delegate는 userInfo만 전달하고 실제 fallback은 `NotificationInboxManager` 기존 로직 유지 |

## Testing Strategy

- Unit tests: `AppNotificationCenterDelegateTests`에서 presentation option 및 response forwarding 검증
- Integration tests: 기존 `NotificationExerciseDataTests`의 `sleepDetail`/pending request 분기 회귀를 함께 실행
- Manual verification: iOS simulator/device에서 앱 foreground 상태로 취침 알림 표시 후 banner tap, Notification Center 목록 잔존 여부 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| delegate helper 추출이 production wiring에 영향 | low | medium | `DUNEApp`의 기존 생성 경로 유지, 기본 handler는 `NotificationInboxManager.shared`로 고정 |
| `.list` 추가가 기존 foreground UX를 바꿀 수 있음 | low | low | banner/sound/badge는 유지하고 list만 추가 |
| 사용자가 말한 "알림센터"가 앱 내부 hub를 의미할 가능성 | medium | medium | 이번 수정 후에도 앱 inbox 기록은 기존과 동일함을 최종 보고에 명시 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 현재 코드와 기존 solution docs 사이에 명확한 회귀가 있고, 증상과 직접 맞닿은 수정이 한 파일에 집중되어 있다. 앱 inbox persistence는 별도 범위지만, delegate 회귀 수정 자체는 낮은 리스크로 수행 가능하다.
