---
tags: [audit, wiring, template-recommendation, progressive-overload, bedtime-reminder, notification-merge]
date: 2026-03-08
category: general
status: implemented
---

# 미연결 기능 감사 및 수정

## Problem

4개 기능의 구현 상태를 감사한 결과 6개 문제점 발견:

| ID | 심각도 | 문제 |
|----|--------|------|
| P1-1 | Critical | `WorkoutTemplateRecommendationService` Domain 서비스가 UI에 미연결 |
| P1-2 | Critical | `shouldSuggestLevelUp` 로직이 존재하나 UI CTA와 `saveWorkout` 호출 누락 |
| P1-3 | Critical | 취침 알림이 워치 미착용 감지 없이 항상 발송 |
| P2-1 | Important | 체성분 알림이 억제(throttle)만 하고 실제 병합(merge) 알림 미발송 |
| P2-2 | Important | 프로그레시브 오버로드가 세트 간(intra-session)만 적용, 세션 간(inter-session) 미적용 |
| P2-3 | Important | 취침 알림 설정 토글 UI 미존재 |

## Solution

### P1-1: 템플릿 추천 UI 연결
- `ActivityViewModel`에 `templateRecommendations` 프로퍼티 추가
- `loadData()`에서 `WorkoutTemplateRecommendationService.recommendTemplates()` 호출
- `SuggestedWorkoutSection`에 `recommendationStrip` + `recommendationCard` 뷰 추가

### P1-2: 레벨업 CTA 복원
- `WorkoutSessionViewModel`에 `shouldSuggestLevelUp` computed var 구현
- `WorkoutSessionView` last-set 완료 영역에 레벨업 배너 UI 추가

### P1-3: 워치 미착용 감지
- `BedtimeWatchReminderScheduler`에 `VitalsQuerying` 주입
- `appleSleepingWristTemperature` 2일 이내 조회로 착용 여부 판정
- 착용 감지 시 리마인더 제거

### P2-1: 체성분 알림 병합
- `NotificationThrottleStore`에 body composition buffer 시스템 추가
- `BackgroundNotificationEvaluator`에서 체성분 타입 감지 → 원자적 buffer → 병합 알림 발송
- `NotificationServiceImpl`에 `replacingIdentifier` 지원 추가 (동일 ID로 알림 교체)

### P2-2: 세션 간 프로그레시브 오버로드
- `applyInterSessionOverload()` 메서드 추가
- 이전 세션 모든 세트가 target reps 달성 시 첫 세트 무게 자동 증가
- 기존 `applyProgressiveOverloadForNextSet()`과 공유 헬퍼 `incrementedWeightDisplay()` 추출

### P2-3: 취침 알림 설정 토글
- `NotificationSettingsSection`에 `@AppStorage("isBedtimeWatchReminderEnabled")` 토글 추가
- `BedtimeWatchReminderScheduler.refreshSchedule()`에서 설정 확인 후 비활성 시 리마인더 제거

## Prevention

- 새 Domain 서비스 추가 시 반드시 Presentation 연결까지 완료 (서비스만 구현하고 방치 금지)
- 기능 감사 체크리스트: "Domain 서비스 → ViewModel 호출 → View 표시" 3단계 연결 확인
- 알림 관련 기능은 설정 토글 + 발송 조건 + 실제 발송을 함께 구현
