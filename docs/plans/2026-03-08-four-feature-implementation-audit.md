---
tags: [template, level-up, bedtime, notification, body-composition, audit]
date: 2026-03-08
category: plan
status: reviewed
---

# 4개 기능 구현 현황 감사

## 요약

4개 핵심 기능의 구현 현황을 조사하고 문제점을 파악하는 감사 보고서.

## 기능별 현황

### 1. 자주 하는 운동 모아서 템플릿 만들도록 추천하는 기능

**구현 상태**: 알고리즘 완성, UI 미연결

| 구성 요소 | 파일 | 상태 |
|-----------|------|------|
| `WorkoutTemplate` 모델 | `Data/Persistence/Models/WorkoutTemplate.swift` | 완성 |
| `WorkoutTemplateRecommendationService` | `Domain/UseCases/WorkoutTemplateRecommendationService.swift` | 완성 (orphaned) |
| 수동 템플릿 생성 UI | `Presentation/Exercise/Components/CreateTemplateView.swift` | 완성 |
| 템플릿 리스트/실행 UI | `Presentation/Exercise/Components/WorkoutTemplateListView.swift` | 완성 |
| **추천 UI (카드/배너)** | 없음 | **미구현** |
| **추천 ViewModel** | 없음 | **미구현** |
| 테스트 | `DUNETests/WorkoutTemplateRecommendationServiceTests.swift` | 3개 통과 |

**알고리즘**: 42일 lookback → HealthKit WorkoutSummary 기반 → 인접 운동 세션 그룹화(10분 gap) → 빈도/최신성/완료율 가중 점수 → top K 추천

**문제점**:
1. **P1**: `WorkoutTemplateRecommendationService`가 Presentation 레이어에서 **한 번도 호출되지 않음**. 알고리즘은 존재하지만 사용자에게 노출되지 않는 orphaned 코드
2. **P2**: 추천 서비스가 HealthKit `WorkoutSummary`(활동 유형: running, coreTraining 등) 기반인데, 앱의 템플릿은 `ExerciseDefinition` ID 기반. `WorkoutTemplateRecommendation` → `WorkoutTemplate` 변환 경로 미존재
3. **P3**: Watch 캐러셀 UX(brainstorm `2026-02-28`) 미구현 — Popular + Recent + Routine 통합 뷰 없음

---

### 2. 운동 절차 기억 + 레벨업 + 무게 증가 로직

**구현 상태**: 절차 기억 + 무게 증가 완성, 레벨업 CTA 제거됨

| 구성 요소 | 파일 | 상태 |
|-----------|------|------|
| 이전 세션 재현 (`loadPreviousSets`) | `Presentation/Exercise/WorkoutSessionViewModel.swift` | 완성 |
| 프로그레시브 오버로드 (`applyProgressiveOverloadForNextSet`) | `Presentation/Exercise/WorkoutSessionViewModel.swift` | 완성 |
| 레벨업 판정 (`shouldSuggestLevelUp`) | 삭제됨 (commit `2b5598ca`) | **삭제됨** |
| 포인트 기반 레벨업 (HealthKit) | `Data/Persistence/PersonalRecordStore.swift` | 완성 |
| 레벨업 알림 → 랜딩 페이지 | `App/ContentView.swift` + `PersonalRecordsDetailView` | 완성 |
| 운동 진행 차트 | `Presentation/Exercise/ExerciseHistoryViewModel.swift` | 완성 |
| 테스트 | `DUNETests/WorkoutSessionViewModelTests.swift` | 통과 |

**운동 절차 기억**: `loadPreviousSets(from:weightUnit:)` — 마지막 세션의 세트/무게/렙을 찾아 새 세션에 자동 프리필

**무게 증가 로직**:
- 세트 완료 시 목표 렙 달성 여부 확인
- 달성 시 다음 세트 무게 자동 증가:
  - 하체 컴파운드(quads/hamstrings/glutes): +5.0kg
  - 덤벨/케틀벨/밴드/맨몸: +1.0kg
  - 기타(바벨 벤치 등): +2.5kg
- 안전 캡: 현재 무게의 10% 초과 금지

**문제점**:
1. **P1**: `shouldSuggestLevelUp()` 메서드가 **dead code로 판정되어 삭제됨**. brainstorm 문서에서 MVP 필수 기능으로 정의했으나, `saveWorkout()` 흐름에 한 번도 연결되지 않은 채 구현 → 삭제. 현재 근력 운동 완료 후 레벨업 CTA가 **없음**
2. **P2**: 무게 증가는 **세션 내** 세트→세트 간만 적용됨. 세션→세션 간 자동 증가 없음 (이전 세션 무게를 프리필하지만 +2.5kg 적용하지 않음)
3. **P2**: 포인트 기반 레벨업 시스템은 HealthKit HKWorkout 기반으로만 작동. 앱 내부 `ExerciseRecord`의 근력 PR은 `StrengthPRService`가 별도 처리하며 포인트 시스템과 연결되지 않음

---

### 3. 평균 취침 시간 -30분 전에 애플워치 미착용 시 알림

**구현 상태**: 스케줄링 완성, 미착용 감지 미구현

| 구성 요소 | 파일 | 상태 |
|-----------|------|------|
| 평균 취침 시간 계산 | `Domain/UseCases/CalculateAverageBedtimeUseCase.swift` | 완성 |
| 알림 스케줄러 | `Data/Services/BedtimeWatchReminderScheduler.swift` | 완성 |
| 앱 생명주기 연동 | `App/DUNEApp.swift`, `App/ContentView.swift` | 완성 |
| 수면 쿼리 인프라 | `Data/HealthKit/SleepQueryService.swift` | 완성 |
| **실시간 미착용 감지** | 없음 | **미구현** |
| **설정 토글** | 없음 | **미구현** |
| 테스트 | `DUNETests/CalculateAverageBedtimeUseCaseTests.swift` | 통과 |

**현재 동작**: 7일간 수면 데이터 → 평균 취침 시간 계산 → (취침 시간 - 30분)에 **매일 반복** 알림 예약. 워치 착용 여부 **무관**하게 매일 발송.

**문제점**:
1. **P1**: **워치 미착용 판별 로직이 없음**. 현재 Watch paired + app installed 체크만 수행하며, 실시간 wrist detection 미구현. 매일 같은 시간에 무조건 알림 발송 → "미착용 시 알림" 기능이 아닌 "매일 취침 전 알림"으로 동작
2. **P2**: 설정 화면에 이 기능의 On/Off 토글이 없음. `NotificationSettingsSection`에 HRV/RHR/수면/걸음 토글은 있으나 bedtime watch reminder 토글 미존재
3. **P3**: 알림 카테고리 `sleepBedtimeReminder`가 `UNNotificationCategory`로 등록되지 않아 커스텀 액션 불가
4. **P3**: 알림 제목이 영어로 과도하게 길음 (iOS 알림 제목 truncation)

---

### 4. 5분 이내 기록된 체성분 기록 알림 통합

**구현 상태**: 완성

| 구성 요소 | 파일 | 상태 |
|-----------|------|------|
| HealthKit Observer 등록 | `Data/HealthKit/HealthKitObserverManager.swift` | 완성 |
| 알림 평가/발송 | `Data/HealthKit/BackgroundNotificationEvaluator.swift` | 완성 |
| 5분 병합 게이트 | `Data/Persistence/NotificationThrottleStore.swift` | 완성 |
| 앱 연동 | `App/DUNEApp.swift` | 완성 |
| 테스트 | `DUNETests/NotificationThrottleStoreTests.swift` | 2개 통과 |

**동작 방식**: `NotificationThrottleStore`에서 체성분 3종(weight/bodyFat/BMI)을 그룹으로 취급. 첫 번째 알림 발송 시 timestamp 기록 → 5분 이내 후속 알림 억제. UserDefaults에 `bodyCompositionLastSent` 키로 공유.

**문제점**:
1. **P2**: "합쳐서 보내기"가 아닌 "첫 번째만 보내고 나머지 억제" 방식. 체중+체지방+BMI 동시 기록 시 "체중 73.2kg" 알림만 표시되고 체지방/BMI 정보는 누락. 진정한 의미의 통합 알림("체중 73.2kg, 체지방 18.4%, BMI 23.1")이 아님
2. **P3**: HealthKit background delivery가 `.hourly`이므로 백그라운드에서는 iOS가 이미 배치 처리. 5분 병합 윈도우는 포그라운드에서만 실질적 효과
3. **P3**: 어떤 metric이 첫 번째로 도착하는지 비결정적(race condition). 사용자 경험이 일관되지 않을 수 있음

---

## 종합 우선순위

| 우선순위 | 기능 | 문제 | 설명 |
|----------|------|------|------|
| P1 | 템플릿 추천 | UI 미연결 | 알고리즘 orphaned — 사용자에게 전혀 노출 안 됨 |
| P1 | 레벨업 | CTA 삭제됨 | 근력 운동 완료 후 레벨업 안내 없음 |
| P1 | 취침 알림 | 미착용 감지 없음 | 워치 착용 무관 매일 발송 |
| P2 | 체성분 알림 | 억제 방식 | 통합이 아닌 억제 — 후속 metric 정보 누락 |
| P2 | 레벨업 | 세션간 미적용 | 프로그레시브 오버로드가 세션 내에서만 동작 |
| P2 | 취침 알림 | 설정 토글 없음 | 사용자가 기능 비활성화 불가 |

## 테스트 전략

이번 감사는 코드 변경이 아닌 조사 작업이므로 별도 테스트 불필요.

## 리스크

- 템플릿 추천과 레벨업 CTA는 별도 구현 작업이 필요한 대규모 기능
- 취침 미착용 감지는 HealthKit/WatchConnectivity API 제약으로 완벽한 실시간 감지가 어려울 수 있음
