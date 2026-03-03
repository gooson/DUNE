---
tags: [healthkit, notification, background, smart-alert, PR]
date: 2026-03-03
category: plan
status: approved
---

# Plan: 백그라운드 HealthKit 감지 → 스마트 알림

## Summary

기존 `HealthKitObserverManager` 인프라를 활용하여, 백그라운드에서 새 건강/운동 데이터 감지 시 **스마트 로컬 알림**을 전송한다.

## Architecture

```
HKObserverQuery callback (existing)
    │
    ├─▶ coordinator.requestRefresh() (existing, UI refresh)
    │
    └─▶ BackgroundNotificationEvaluator (NEW)
            ├─ fetchNewSamples (HKAnchoredObjectQuery)
            ├─ evaluateHealthInsight (baseline comparison)
            ├─ evaluateWorkoutPR (PersonalRecordStore hook)
            └─ NotificationService.send() (if criteria met)
```

## Affected Files

### 새 파일 (11개)

| # | 파일 | 레이어 | 역할 |
|---|------|--------|------|
| 1 | `Domain/Services/NotificationService.swift` | Domain | 알림 서비스 protocol |
| 2 | `Domain/Models/HealthInsight.swift` | Domain | 인사이트 타입 + 메시지 모델 |
| 3 | `Domain/UseCases/EvaluateHealthInsightUseCase.swift` | Domain | 건강 데이터 baseline 비교 |
| 4 | `Data/Services/NotificationServiceImpl.swift` | Data | UNUserNotificationCenter 래핑 |
| 5 | `Data/Persistence/NotificationSettingsStore.swift` | Data | 알림 설정 (타입별 on/off) |
| 6 | `Data/Persistence/NotificationThrottleStore.swift` | Data | 마지막 알림 일시 추적 |
| 7 | `Data/HealthKit/BackgroundNotificationEvaluator.swift` | Data | Observer → 알림 브릿지 |
| 8 | `Data/HealthKit/HealthKitAnchorStore.swift` | Data | 타입별 anchor 영속 |
| 9 | `Presentation/Settings/Components/NotificationSettingsSection.swift` | Presentation | 알림 설정 UI |
| 10 | `DUNETests/EvaluateHealthInsightUseCaseTests.swift` | Tests | 인사이트 평가 테스트 |
| 11 | `DUNETests/NotificationThrottleStoreTests.swift` | Tests | 쓰로틀 로직 테스트 |

### 수정 파일 (5개)

| # | 파일 | 변경 내용 |
|---|------|----------|
| 1 | `App/DUNEApp.swift` | UNUserNotificationCenter delegate + evaluator 초기화 |
| 2 | `Data/HealthKit/HealthKitObserverManager.swift` | observer callback에 evaluator 호출 추가 |
| 3 | `Presentation/Settings/SettingsView.swift` | Notifications 섹션 추가 |
| 4 | `DUNE/project.yml` | 새 파일 등록 (xcodegen) |
| 5 | `Resources/Localizable.xcstrings` | 알림 메시지 en/ko/ja |

## Implementation Steps

### Step 1: Domain 모델 + Protocol (3개 파일)

**1.1 `HealthInsight` 모델**

```swift
// Domain/Models/HealthInsight.swift
struct HealthInsight: Sendable {
    enum InsightType: String, Sendable, CaseIterable {
        case hrvAnomaly
        case rhrAnomaly
        case sleepComplete
        case stepGoal
        case weightUpdate
        case bodyFatUpdate
        case bmiUpdate
        case workoutPR
    }

    let type: InsightType
    let title: String     // String(localized:) 사용
    let body: String
    let date: Date
}
```

**1.2 `NotificationService` protocol**

```swift
// Domain/Services/NotificationService.swift
protocol NotificationService: Sendable {
    func requestAuthorization() async -> Bool
    func sendLocalNotification(_ insight: HealthInsight) async
    func isAuthorized() async -> Bool
}
```

**1.3 `EvaluateHealthInsightUseCase`**

- HRV: 7일 평균 대비 ±20% → 알림
- RHR: 7일 평균 대비 ±15% → 알림
- Sleep: 기록 완료 시 항상 → 총 수면시간 포함
- Steps: 목표(10,000) 달성 시 → 알림
- Weight/BodyFat/BMI: 새 기록 시 항상 → 값 + 이전 대비 변화량
- Workout PR: `PersonalRecordService.detectNewRecords()` 결과 활용

### Step 2: Data 레이어 (5개 파일)

**2.1 `NotificationServiceImpl`**

- `UNUserNotificationCenter` 래핑
- `UNMutableNotificationContent` 생성 (title, body, sound)
- categoryIdentifier로 타입 구분

**2.2 `NotificationSettingsStore`**

- UserDefaults 기반 (bundle prefix)
- 타입별 Bool 토글 (기본값: 전부 on)
- `isEnabled(for: InsightType) -> Bool`

**2.3 `NotificationThrottleStore`**

- 타입별 마지막 알림 Date 저장
- 건강 데이터: 같은 calendar day 내 중복 차단
- 운동 PR: throttle 없음 (매번 발송)

**2.4 `HealthKitAnchorStore`**

- `HKQueryAnchor`를 Data로 인코딩 → UserDefaults 저장
- 타입별 독립 anchor 관리
- 앱 재설치 시 nil → 초기 fetch는 당일만 (predicate로 제한)

**2.5 `BackgroundNotificationEvaluator`**

- `HealthKitObserverManager`에서 호출
- Anchor query로 새 샘플 추출
- `EvaluateHealthInsightUseCase` + `NotificationService` 조합
- 30초 백그라운드 제약 내에서 동작

### Step 3: Observer 연결

`HealthKitObserverManager.registerObserver(for:)` 내 callback에서:

```swift
// 기존: coordinator.requestRefresh()
// 추가:
Task {
    await backgroundEvaluator.evaluateAndNotify(sampleType: sampleType)
}
```

### Step 4: 앱 진입점 설정

`DUNEApp.init()`:
- `BackgroundNotificationEvaluator` 초기화
- `HealthKitObserverManager`에 evaluator 주입

`DUNEApp.runPostSplashSetupIfNeeded()`:
- `UNUserNotificationCenter.current().delegate = ...`
- 알림 권한 요청 (첫 실행 시)

### Step 5: 설정 UI

`SettingsView`에 "Notifications" 섹션 추가:

```
Section("Notifications") {
    NavigationLink → NotificationSettingsSection
}
```

`NotificationSettingsSection`:
- 마스터 토글 (알림 허용)
- 건강 데이터 8개 타입별 토글
- 시스템 설정 딥링크 (권한 거부 시)

### Step 6: Localization

알림 메시지 en/ko/ja 번역:
- 총 8개 타입 × (title + body template) = ~16개 문자열
- `Localizable.xcstrings`에 추가

### Step 7: 테스트

- `EvaluateHealthInsightUseCaseTests`: baseline 비교 로직 전체 분기
- `NotificationThrottleStoreTests`: throttle 동작 검증
