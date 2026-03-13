---
topic: notification-tap-cold-start-crash-fix
date: 2026-03-13
status: draft
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-04-sleep-notification-cold-start-crash.md
  - docs/solutions/general/2026-03-11-bedtime-reminder-notification-delegate-fix.md
  - docs/solutions/architecture/2026-03-12-notification-ingress-mainactor-hardening.md
related_brainstorms: []
---

# Implementation Plan: Notification Tap Cold Start Crash Fix

## Context

OS 알림센터에서 알림을 탭했을 때 앱이 실행되지 않거나 크래시가 발생하는 문제. Cold start 시 notification delegate → inbox manager → ContentView routing 경로에 여러 취약점이 존재한다.

### Root Cause Analysis

코드 정적 분석 결과, 단일 crash vector보다 복합적 취약점이 문제:

1. **fatalError in ModelContainer fallback** (`DUNEApp.swift:168`): in-memory fallback container 생성 실패 시 `fatalError`로 앱이 즉시 종료. Cold start에서 migration 실패 시 복구 불가.

2. **Bedtime reminder notification에 insightType 미포함**: `BedtimeWatchReminderScheduler`가 보내는 알림의 userInfo에 `notificationItemID`와 `notificationInsightType`가 없어, tap 시 inbox에 기록되지 않고 routing만 시도. routing 자체는 작동하지만 inbox 추적이 누락됨.

3. **Cold start 시 notification 처리 타이밍**: ContentView가 splash screen 동안 view hierarchy에 없어(~1초), 이 시간 동안 도착한 notification은 `pendingNavigationRequest`로 큐잉됨. ContentView 마운트 후 `.task`에서 소비하지만, launch experience flow(consent sheet, WhatsNew)가 완료되기 전에 navigation을 시도하면 실패할 수 있음.

4. **진단 로깅 부재**: notification tap → navigation 경로에 로깅이 없어 실제 실패 지점을 추적하기 어려움.

## Requirements

### Functional

- OS 알림센터에서 알림 탭 시 앱이 정상적으로 실행되어야 함
- 알림 탭 후 해당 화면으로 올바르게 이동해야 함
- 모든 알림 유형(health insight, bedtime reminder, life checklist)에서 동작해야 함

### Non-functional

- ModelContainer 초기화 실패 시에도 앱이 크래시하지 않아야 함
- Cold start 시 notification 처리가 launch experience 완료 후 안전하게 실행되어야 함
- 문제 발생 시 진단 가능한 로그가 남아야 함

## Approach

4가지 취약점을 개별적으로 수정:
1. `fatalError` 제거 → graceful fallback
2. Bedtime reminder userInfo 보강
3. Cold start notification deferral (launch experience 인식)
4. 진단 로깅 추가

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| notification 전체 재설계 | 근본 해결 | 범위 과대, 위험 | 기각 |
| didReceive에서 직접 navigation | 단순 | SwiftUI lifecycle 위반 | 기각 |
| 개별 취약점 패치 | 최소 변경, 안전 | 근본 원인 불확실 시 누락 가능 | **채택** |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/DUNEApp.swift` | Modify | fatalError → graceful empty container fallback |
| `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift` | Modify | userInfo에 insightType 추가 |
| `DUNE/App/ContentView.swift` | Modify | cold start notification deferral + 진단 로깅 |
| `DUNE/Data/Persistence/NotificationInboxManager.swift` | Modify | handleNotificationResponse 진단 로깅 |
| `DUNE/App/AppNotificationCenterDelegate.swift` | Modify | didReceive 진단 로깅 |
| `DUNETests/AppNotificationCenterDelegateTests.swift` | Modify | 새 동작 테스트 |

## Implementation Steps

### Step 1: fatalError 제거 — graceful ModelContainer fallback

- **Files**: `DUNE/App/DUNEApp.swift`
- **Changes**: `makeInMemoryFallbackContainer()`에서 `fatalError` 대신 최소한의 빈 ModelContainer 반환. 스키마 없는 기본 configuration으로 시도 후에도 실패하면 빈 in-memory container를 catch 없이 생성.
- **Verification**: 빌드 성공, fatalError 제거 확인

### Step 2: Bedtime reminder notification userInfo 보강

- **Files**: `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift`
- **Changes**: `scheduleReminder()`의 notification content에 `NotificationResponsePayload` 사용하여 `insightType: .sleepComplete`(또는 신규 타입)과 `routeKind` 포함. 이를 통해 tap 시 inbox에 기록되고 routing도 정상 동작.
- **Verification**: bedtime reminder 알림의 userInfo에 insightType이 포함되는지 확인

### Step 3: Cold start notification deferral

- **Files**: `DUNE/App/ContentView.swift`
- **Changes**: `.task`에서 `consumePendingNavigationRequest` 호출 전에 `launchExperienceReady`가 true가 될 때까지 대기. `launchExperienceReady`가 변경되면 pending request를 다시 확인하는 `.onChange` 추가.
- **Verification**: cold start 시 consent sheet 후에도 notification navigation이 정상 동작

### Step 4: 진단 로깅 추가

- **Files**: `AppNotificationCenterDelegate.swift`, `NotificationInboxManager.swift`, `ContentView.swift`
- **Changes**: notification tap 수신, routing 결정, navigation 실행 각 단계에 `AppLogger.notification` 로그 추가
- **Verification**: 로그 출력 확인

### Step 5: 테스트 보강

- **Files**: `DUNETests/AppNotificationCenterDelegateTests.swift`
- **Changes**: bedtime reminder payload에 insightType이 포함되는지 테스트, cold start pending request 소비 테스트
- **Verification**: 테스트 통과

## Edge Cases

| Case | Handling |
|------|----------|
| ModelContainer 완전 실패 | 빈 in-memory container로 앱은 실행되되 데이터 없는 상태 |
| Launch experience 중 notification tap | pending request 큐잉, experience 완료 후 처리 |
| 동일 notification 중복 tap | consumePendingNavigationRequest dedup으로 방어 (기존) |
| userInfo 완전 비어있는 notification | parseRoute nil → 무시 (기존 fallback) |

## Testing Strategy

- Unit tests: `AppNotificationCenterDelegateTests` — payload 포워딩, bedtime reminder userInfo 검증
- Unit tests: `NotificationInboxManagerTests` — handleNotificationResponse 각 경로 검증
- Manual verification: 시뮬레이터에서 bedtime reminder 스케줄 → notification center에서 tap → 앱 실행 + sleep detail 이동 확인
- Build verification: `scripts/build-ios.sh` 통과

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 실제 crash가 다른 원인 | Medium | High | 진단 로깅으로 실제 원인 추적 가능하게 함 |
| notification deferral이 UX 지연 유발 | Low | Low | launch experience는 이미 1-2초, 추가 지연 미미 |
| bedtime reminder userInfo 변경이 기존 scheduled notification에 영향 | Low | Low | 이미 스케줄된 알림은 기존 format 유지, 새로 스케줄된 것부터 적용 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 정적 분석으로는 명확한 단일 crash point를 특정하기 어려움. 다만 식별된 4가지 취약점 모두 실제 문제를 유발할 수 있는 valid한 결함이며, 수정 시 cold start notification 안정성이 전반적으로 개선됨. 진단 로깅 추가로 향후 재발 시 빠른 원인 파악이 가능해짐.
