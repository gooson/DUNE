---
tags: [healthkit, notifications, background-delivery, observer-query, anchored-query]
date: 2026-03-03
category: solution
status: implemented
---

# HealthKit Background Notification System

## Problem

백그라운드 상태에서 HealthKit에 새 데이터가 기록되면 사용자에게 알림을 전송해야 한다.
실행 시간 제한(~30초), 기준선 계산 비용, 중복 알림 방지 등의 제약이 있다.

## Solution

### Architecture

```
HKObserverQuery (background delivery)
    ↓
BackgroundNotificationEvaluator
    ├─ NotificationSettingsStore (per-type on/off)
    ├─ NotificationThrottleStore (once per day)
    ├─ HealthKitAnchorStore (incremental samples)
    ├─ EvaluateHealthInsightUseCase (pure domain logic)
    └─ NotificationServiceImpl (UNUserNotificationCenter)
```

### Key Design Decisions

1. **Foreground caching strategy**: 기준선(7일 평균)은 포그라운드에서 계산하여 UserDefaults에 캐시. 백그라운드에서는 캐시만 읽음 (30초 제한 내 안전).

2. **Anchored query**: `HKAnchoredObjectQuery`로 마지막 확인 이후의 새 샘플만 처리. 앵커는 `HealthKitAnchorStore`에 `NSKeyedArchiver`로 영속화.

3. **Step goal 누적 패턴**: 각 background delivery는 델타만 반환하므로, 일일 누적 총량을 캐시에 저장. **자정 리셋 필수** — 날짜와 함께 저장하고 `isDateInToday` 검증.

4. **Throttle**: 건강 데이터는 `Calendar.isDate(_:inSameDayAs:)`로 하루 1회 제한. 운동 PR은 제한 없음.

5. **Layer boundary**: `BackgroundNotificationEvaluator`는 Data 레이어. Presentation 레이어의 `displayName`에 접근 불가 → `typeName` (Domain) + `String(localized:)` (Foundation) 사용.

### Pitfalls Discovered

| 문제 | 원인 | 해결 |
|------|------|------|
| Step goal 알림 미발동 | `cacheStepTotal()` 미호출 | 평가 후 누적 총량 저장 |
| Step goal false positive | 자정 후 어제 캐시 사용 | 날짜 기반 캐시 무효화 |
| Weight delta 미표시 | `cachePreviousWeight()` 미호출 | 평가 후 체중 저장 |
| `.defaultCritical` DND 무시 | celebration에 critical sound 사용 | `.default` 통일 |
| Layer violation | Presentation `displayName` 참조 | Domain `typeName` + `String(localized:)` |

### Files Created

| File | Layer | Purpose |
|------|-------|---------|
| `Domain/Models/HealthInsight.swift` | Domain | 알림 인사이트 모델 |
| `Domain/Services/NotificationService.swift` | Domain | 알림 서비스 프로토콜 |
| `Domain/UseCases/EvaluateHealthInsightUseCase.swift` | Domain | 평가 로직 (8종) |
| `Data/Services/NotificationServiceImpl.swift` | Data | UNUserNotificationCenter 래퍼 |
| `Data/Persistence/NotificationSettingsStore.swift` | Data | 알림 타입별 on/off 설정 |
| `Data/Persistence/NotificationThrottleStore.swift` | Data | 일일 1회 제한 |
| `Data/HealthKit/HealthKitAnchorStore.swift` | Data | HKQueryAnchor 영속화 |
| `Data/HealthKit/BackgroundNotificationEvaluator.swift` | Data | 핵심 평가 브릿지 |
| `Presentation/Settings/Components/NotificationSettingsSection.swift` | Presentation | 설정 UI |

## Prevention

- **캐시 기반 누적 값은 반드시 평가 후 저장**: "read-only" 캐시 패턴에서 write-back 누락 주의
- **일 단위 캐시는 날짜 검증 필수**: `isDateInToday()` 패턴으로 stale 데이터 방지
- **`.defaultCritical`은 의료/안전 알림만**: DND 무시 사운드는 극히 예외적으로만 사용
- **Background evaluator에서 Presentation import 금지**: `typeName` + `String(localized:)` 패턴
