---
tags: [notification, atomicity, layer-boundary, body-composition, domain-protocol]
date: 2026-03-08
category: architecture
status: implemented
---

# 알림 시스템 원자성 및 레이어 경계 수정

## Problem

### 1. 체성분 알림 병합 레이스 컨디션
`BackgroundNotificationEvaluator`가 체성분(weight/bodyFat/BMI) 알림 병합 시 비원자적 시퀀스를 사용:
- buffer 기록 → buffer 조회 → 병합 빌드 → throttle 기록 → 알림 발송
- HealthKit background delivery가 동시에 여러 체성분 값을 전달할 때 중간 상태 노출 가능

### 2. Domain 프로토콜 레이어 누수
`NotificationService` 프로토콜(Domain)에 `send(_:replacingIdentifier:)` 메서드가 있었는데, `replacingIdentifier`는 `UNNotificationRequest`의 identifier 교체 개념으로 Data 레이어 구현 상세.

### 3. Presentation → Data 참조
`NotificationSettingsSection`(Presentation)이 `BedtimeWatchReminderScheduler.settingsKey`(Data)를 `@AppStorage` 키로 참조.

## Solution

### 1. 원자적 buffer+throttle 메서드
`NotificationThrottleStore`에 `bufferAndBuildMergedBody()` 단일 메서드 생성. 모든 동작이 `queue.sync` 블록 안에서 수행:

```swift
func bufferAndBuildMergedBody(
    type: HealthInsight.InsightType,
    formattedValue: String,
    now: Date = Date()
) -> String? {
    queue.sync {
        // 1. buffer에 값 기록
        // 2. merge window 내 pending 수집
        // 3. throttle 기록 (bodyComp + general)
        // 4. 병합 문자열 반환
    }
}
```

기존 3개 public 메서드(`recordBodyCompositionValue`, `pendingBodyCompositionValues`, `clearBodyCompositionBuffer`)를 이 단일 메서드로 대체.

### 2. Protocol에서 replacingIdentifier 제거
- `NotificationService` 프로토콜에서 `send(_:replacingIdentifier:)` 제거
- `NotificationServiceImpl`에 concrete 메서드로 유지
- `BackgroundNotificationEvaluator`의 `notificationService` 타입을 `NotificationServiceImpl`로 변경 (둘 다 Data 레이어이므로 허용)

### 3. 문자열 리터럴 인라인
```swift
// Before: Presentation → Data 참조
@AppStorage(BedtimeWatchReminderScheduler.settingsKey)

// After: 리터럴 직접 사용
@AppStorage("isBedtimeWatchReminderEnabled")
```

## Prevention

- Domain 프로토콜에 메서드 추가 시 구현 상세(identifier, UNNotification 등)가 시그니처에 노출되는지 확인
- 동시 호출 가능한 상태 변이는 읽기-수정-쓰기 전체를 단일 동기화 블록으로 래핑
- Presentation → Data 정적 참조는 `@AppStorage` 문자열 키를 리터럴로 인라인하여 차단
