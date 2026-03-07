---
tags: [template-recommendation, level-up, bedtime-notification, body-composition, notification-batching, audit, orphaned-code]
date: 2026-03-08
category: architecture
status: reviewed
---

# 4개 핵심 기능 구현 감사 결과

## Problem

4개 MVP 기능의 구현 완성도를 검증한 결과, 3개 기능에 P1급 gap이 발견됨.

## Findings

### 1. 템플릿 추천 — 알고리즘 orphaned

- `WorkoutTemplateRecommendationService`가 Domain 레이어에 완성되어 있으나 Presentation 레이어에서 **0회 참조**
- ViewModel, UI 카드, 추천→템플릿 변환 경로 모두 부재
- HealthKit WorkoutSummary 기반 알고리즘 ↔ ExerciseDefinition 기반 템플릿 간 데이터 매핑 미존재

### 2. 레벨업 CTA — 삭제됨

- `shouldSuggestLevelUp()` 구현 후 UI에 연결하지 않은 채 dead code로 판정되어 삭제 (commit `2b5598ca`)
- 현재 근력 운동 완료 후 레벨업 안내가 전혀 없음
- 포인트 기반 레벨업(`PersonalRecordStore`)은 HealthKit HKWorkout 전용으로, 앱 내 근력 PR과 무관

### 3. 취침 미착용 알림 — 미착용 감지 없음

- 평균 취침 시간 계산 + 알림 스케줄링은 완성
- 실시간 wrist detection 미구현 → 매일 무조건 발송
- 설정 토글 미존재 → 사용자가 비활성화 불가

### 4. 체성분 알림 통합 — 억제 방식

- 5분 merge window가 `NotificationThrottleStore`에 구현 완성
- 단, "통합(merge)"이 아닌 "억제(suppress)" — 첫 metric만 표시, 나머지 정보 누락

## Solution (향후 작업 방향)

| 기능 | 필요 작업 | 예상 규모 |
|------|----------|----------|
| 템플릿 추천 | ViewModel + UI 카드 생성, WorkoutSummary→ExerciseDefinition 매핑 | F3 |
| 레벨업 CTA | `shouldSuggestLevelUp()` 복원 + `saveWorkout()` 연결 + CTA UI | F2 |
| 취침 미착용 | wrist detection 조사 + 조건부 알림 + 설정 토글 | F3 |
| 체성분 통합 알림 | 5분 윈도우 내 수집 후 단일 통합 알림 포맷 생성 | F2 |

## Prevention

- 새 Service/UseCase 구현 시 **동일 PR에서 최소 1개 UI 연결점** 확보
- dead code 판정 전 brainstorm/plan 문서와 교차 확인
- 알림 기능 구현 시 설정 토글을 같은 PR에 포함

## Lessons Learned

- 알고리즘 구현과 UI 연결을 분리하면 orphaned 코드 위험 증가
- "MVP 필수"로 정의된 기능도 save/complete 흐름에 연결하지 않으면 dead code로 삭제될 수 있음
- 알림 기능에서 "조건 충족 시 발송"과 "무조건 발송 + 설정 토글"은 근본적으로 다른 UX
