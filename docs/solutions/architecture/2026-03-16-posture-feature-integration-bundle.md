---
tags: [posture, injury-risk, symmetry, pdf-report, notification, integration]
date: 2026-03-16
category: architecture
status: implemented
---

# Posture Feature Integration Bundle

## Problem

기존 자세 분석 시스템(PostureAssessmentRecord, PostureAnalysisService)이 독립적으로 동작하여 앱의 다른 시스템(Injury Risk, Notifications)과 연결되지 않았음. 또한 상세 좌우 비교, PDF 리포트 내보내기 기능이 없었음.

## Solution

### 1. Injury Risk Integration (PostureMetricType → BodyPart 매핑)

자세 이슈를 기존 부상 위험 시스템에 연결:

```swift
// Domain/Models/PostureMetric.swift
extension PostureMetricType {
    var affectedBodyParts: [BodyPart] {
        switch self {
        case .forwardHead: [.neck]
        case .shoulderAsymmetry, .roundedShoulders: [.shoulder]
        // ...
        }
    }
}
```

- `InjuryRiskAssessment.FactorType`에 `.postureIssue` 추가
- `CalculateInjuryRiskUseCase.Input`에 `postureWarningCount`, `postureScore` 추가 (기본값으로 backward-compatible)
- 기존 가중치 재분배: muscleFatigue 25→22.5%, lowRecovery 10→7.5%, postureIssue 5% (합계 100% 유지)

### 2. Left-Right Symmetry View

`PostureAnalysisService.analyzeSymmetryDetails(joints:)` → `[SymmetryDetail]`
- SymmetryDetail: metric, leftValue, rightValue, difference, higherSide, status, unit
- PostureSymmetryView: 좌우 바 차트 비교 UI (GeometryReader + HStack)
- PostureSymmetryViewModel: @Observable, loadSymmetry()

### 3. PDF Report Export

`PostureReportGenerator` (UIGraphicsPDFRenderer 기반):
- 순수 값 파라미터 (date, score, metrics, memo) — @Model 직접 참조 방지 (Sendable 호환)
- Layout enum에 column 상수 집중 (DRY)
- Cache enum에 DateFormatter static 캐싱
- Score 0-100 클램핑, memo 500자 제한
- `Task.detached`로 메인 스레드 차단 방지

### 4. Weekly Posture Reminder

`PostureReminderScheduler` (BedtimeReminderNotificationScheduling 프로토콜 재사용):
- 기본: 일요일 10:00 AM, UNCalendarNotificationTrigger
- AppStorage `isPostureReminderEnabled` (기본 false)
- DUNEApp.swift 앱 시작 시 + 권한 획득 시 refreshSchedule() 호출
- NotificationSettingsSection에 토글 추가

## Prevention

### PDF 생성기 설계 원칙

1. **@Model 파라미터 금지**: PDF 생성은 background thread에서 실행되므로, @Model(non-Sendable)을 직접 전달하지 않음. 필요한 값을 미리 추출하여 plain type으로 전달.
2. **Layout 상수 단일 소스**: column 위치 같은 반복 상수는 Layout enum에 집중. 2곳 이상 사용되면 즉시 추출.
3. **DateFormatter 캐싱**: PDF 생성은 반복 호출될 수 있으므로 static let 캐싱 필수.

### 기존 시스템 통합 체크리스트

새 기능을 기존 시스템에 통합할 때:
- [ ] 스케줄러/서비스가 앱 시작 시 초기화되는지 확인 (DUNEApp.swift)
- [ ] 설정 토글이 onChange로 서비스에 연결되는지 확인
- [ ] 가중치 변경 시 전체 합계 100% 유지 확인
- [ ] Input 구조체 변경 시 기본값으로 backward-compatible 유지
