---
tags: [notification, push, dedup, rate-limit, race-condition, healthkit]
category: architecture
date: 2026-03-04
severity: important
related_files:
  - DUNE/Data/Persistence/NotificationThrottleStore.swift
  - DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift
  - DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift
  - DUNETests/NotificationThrottleStoreTests.swift
related_solutions:
  - docs/solutions/healthkit/background-notification-system.md
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
---

# Solution: Push Dedup + Daily Budget for Notification Fatigue Control

## Problem

기존 백그라운드 알림 파이프라인은 타입별 일일 쓰로틀만 적용되어, observer 재호출/중복 이벤트 상황에서 동일 알림 반복 전송 위험이 있었다.
또한 정보성 알림량에 대한 전역 예산이 없어 파워 유저에게도 피로를 유발할 수 있었다.

### Symptoms

- 동일 workout 이벤트가 짧은 시간 안에 반복 알림으로 노출될 수 있음
- 정보성 알림이 누적될 때 일일 상한이 없어 과다 전송 가능
- `canSend`와 `recordSent`가 분리되어 동시 실행 시 중복 차단이 깨질 수 있음

### Root Cause

- 정책이 타입 단위(`InsightType`) 중심으로만 설계되어 이벤트 단위 dedup 부재
- 전송 허용 판단과 기록이 원자적으로 묶여 있지 않아 race-condition 가능

## Solution

`NotificationThrottleStore`를 확장해 insight 단위 정책을 추가하고,
`BackgroundNotificationEvaluator`에서 원자적 check-and-record API를 사용하도록 연결했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Persistence/NotificationThrottleStore.swift` | insight-level dedup, informational daily budget, atomic `shouldSendAndRecord` 추가 | 중복/피로 제어 + race-condition 방지 |
| `DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift` | 전송 직전 `shouldSendAndRecord(insight:)` 호출로 변경 | 평가 후 정책 게이트를 단일 진입점으로 통합 |
| `DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift` | footer 문구 업데이트 | 실제 정책(1일 제한 + 1시간 dedup + 예산)과 UI 설명 정합 |
| `DUNETests/NotificationThrottleStoreTests.swift` | dedup, daily budget, atomic flow 테스트 추가 | 신규 정책 회귀 방지 |

### Key Code

```swift
guard throttleStore.shouldSendAndRecord(insight: insight) else { return }
await notificationService.send(insight)
```

```swift
func shouldSendAndRecord(insight: HealthInsight, now: Date = Date()) -> Bool {
    queue.sync {
        guard canSendInsightLocked(insight: insight, now: now) else { return false }
        recordSentInsightLocked(insight: insight, now: now)
        return true
    }
}
```

## Prevention

알림 정책은 "판단"과 "기록"을 분리하지 않고 원자 연산으로 묶는다.
중복 억제는 타입 수준이 아니라 이벤트(signature) 수준으로 설계한다.

### Checklist Addition

- [ ] 알림 전송 게이트가 `check`와 `record`를 원자적으로 처리하는가?
- [ ] 동일 이벤트 재발행 시 dedup window 내 반복 전송이 차단되는가?
- [ ] 정보성 알림은 일일 예산 상한을 초과하지 않는가?

### Rule Addition (if applicable)

없음. 기존 `testing-required`, `input-validation`, `swift-layer-boundaries` 규칙 범위 내에서 해결.

## Lessons Learned

- 알림 피로 제어는 "몇 번 보냈는가"뿐 아니라 "같은 이벤트를 또 보냈는가"를 함께 봐야 효과적이다.
- 백그라운드 콜백 기반 시스템에서는 작은 race-condition도 중복 알림으로 바로 체감되므로, 전송 게이트의 원자성이 핵심이다.
