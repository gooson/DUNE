---
tags: [template-recommendation, level-up, bedtime-notification, body-composition, progressive-overload, notification, audit-fix]
date: 2026-03-08
category: plan
status: reviewed
---

# 4개 기능 감사 결과 수정 계획

## 요약

감사(`docs/plans/2026-03-08-four-feature-implementation-audit.md`)에서 발견된 P1 3건, P2 3건 총 6개 문제를 수정한다.

## 수정 항목

| ID | 우선순위 | 기능 | 문제 | 수정 방향 |
|----|---------|------|------|----------|
| P1-1 | Critical | 템플릿 추천 | UI 미연결 (orphaned) | ActivityViewModel → SuggestedWorkoutSection 연결 |
| P1-2 | Critical | 레벨업 CTA | 삭제됨 | shouldSuggestLevelUp 복원 + allSetsDoneSheet 연결 |
| P1-3 | Critical | 취침 알림 | 미착용 감지 없음 | wrist temperature proxy 조건부 발송 |
| P2-1 | Important | 체성분 알림 | 억제 방식 | 5분 윈도우 수집 후 통합 알림 |
| P2-2 | Important | 프로그레시브 오버로드 | 세션간 미적용 | loadPreviousSets에서 첫 세트 increment |
| P2-3 | Important | 취침 알림 | 설정 토글 없음 | NotificationSettingsSection에 토글 추가 |

## Implementation Steps

### Step 1: P1-1 — 템플릿 추천 UI 연결

**영향 파일:**

| 파일 | 변경 |
|------|------|
| `Presentation/Activity/ActivityViewModel.swift` | `templateRecommendations` property 추가, `loadActivityData()`에서 서비스 호출 |
| `Presentation/Activity/Components/SuggestedWorkoutSection.swift` | recommendations 파라미터 추가, 추천 strip UI 렌더 |
| `Presentation/Activity/ActivityView.swift` | recommendations를 SuggestedWorkoutSection에 전달 |

**구현:**
1. `ActivityViewModel`에 `templateRecommendations: [WorkoutTemplateRecommendation] = []` 추가
2. `loadActivityData()` 끝에서 `recentWorkouts`를 사용해 `WorkoutTemplateRecommendationService.recommendTemplates` 호출
3. `SuggestedWorkoutSection`에 `recommendations` 파라미터 추가
4. 추천이 있을 때 기존 템플릿 strip 위에 "Suggested Routines" 섹션 렌더

**검증:** 42일 이상 운동 기록이 있으면 추천 카드가 표시됨

### Step 2: P1-2 — 레벨업 CTA 복원

**영향 파일:**

| 파일 | 변경 |
|------|------|
| `Presentation/Exercise/WorkoutSessionViewModel.swift` | `shouldSuggestLevelUp()` 복원 |
| `Presentation/Exercise/WorkoutSessionView.swift` | allSetsDoneSheet에 레벨업 배너 추가 |

**구현:**
1. `WorkoutSessionViewModel`에 `shouldSuggestLevelUp() -> Bool` 복원 (삭제된 코드 기반)
   - 모든 세트 완료 + 90% 이상 목표 렙 달성 → true
2. `allSetsDoneSheet`에서 `viewModel.shouldSuggestLevelUp()`이 true일 때 레벨업 배너 표시
   - `"star.circle.fill"` + `.mint` 패턴 (기존 PR 카드와 동일)
   - 텍스트: "Great progress! Consider increasing weight next time."

**검증:** 모든 세트에서 목표 렙 이상 달성 시 레벨업 배너 표시

### Step 3: P1-3 + P2-3 — 취침 알림 wrist detection + 설정 토글

**영향 파일:**

| 파일 | 변경 |
|------|------|
| `Data/Services/BedtimeWatchReminderScheduler.swift` | 설정 토글 확인 + wrist temp 쿼리 추가 |
| `Presentation/Settings/Components/NotificationSettingsSection.swift` | bedtime watch reminder 토글 추가 |

**구현:**
1. `BedtimeWatchReminderScheduler.refreshSchedule()`에서:
   - UserDefaults `isBedtimeWatchReminderEnabled` 체크 (기본값 true)
   - 알림 스케줄링 시 전날 밤 `appleSleepingWristTemperature` 샘플 존재 확인
   - 샘플 있으면 (워치 착용 중) → 알림 스킵
   - 샘플 없으면 (미착용) → 알림 발송
2. 단, 스케줄링은 UNCalendarNotificationTrigger 기반이라 발송 시점 판단 불가 → 대안:
   - 매일 반복 알림 유지하되, pending notification 유지/제거 방식으로 전환
   - `.task` 또는 앱 진입 시 오늘 wrist temp 확인 → 있으면 pending 알림 제거
3. `NotificationSettingsSection`에 bedtime watch reminder 토글 추가
   - `@AppStorage("isBedtimeWatchReminderEnabled") private var isBedtimeReminderEnabled = true`

**검증:** 워치 미착용 시에만 알림 도착, 설정에서 토글로 비활성화 가능

### Step 4: P2-1 — 체성분 알림 통합

**영향 파일:**

| 파일 | 변경 |
|------|------|
| `Data/HealthKit/BackgroundNotificationEvaluator.swift` | 체성분 수집 후 통합 알림 발송 |
| `Data/Persistence/NotificationThrottleStore.swift` | 체성분 수집 버퍼 추가 |

**구현:**
1. `NotificationThrottleStore`에 체성분 수집 버퍼 추가:
   - `recordBodyCompositionValue(type:value:)` — 값을 UserDefaults에 임시 저장
   - `pendingBodyCompositionValues() -> [InsightType: Double]` — 수집된 값 반환
   - `clearBodyCompositionBuffer()` — 버퍼 초기화
2. `BackgroundNotificationEvaluator.evaluateAndNotify()`에서 체성분 타입일 때:
   - 값을 버퍼에 저장
   - 5분 윈도우 내 첫 번째이면 지연 발송 (DispatchQueue.asyncAfter 5분 후)
   - 5분 후 버퍼에서 모든 값을 모아 통합 알림 생성
   - 통합 알림: "Weight 73.2kg, Body Fat 18.4%, BMI 23.1" 형식

**대안 (더 단순):**
- 첫 체성분 알림 발송 시 notification identifier를 고정
- 후속 체성분 도착 시 동일 identifier로 알림 교체 (UNNotificationRequest replace)
- 마지막 알림이 모든 수집된 값을 포함

**선택: 대안 채택** — 복잡한 타이머 없이 notification replace로 구현

**검증:** 체중+체지방+BMI 동시 기록 시 통합 알림 1개만 표시

### Step 5: P2-2 — 세션간 프로그레시브 오버로드

**영향 파일:**

| 파일 | 변경 |
|------|------|
| `Presentation/Exercise/WorkoutSessionViewModel.swift` | loadPreviousSets 끝에서 첫 세트 weight increment |

**구현:**
1. `loadPreviousSets` 끝에서, 이전 세션의 모든 세트가 목표 렙을 달성했는지 확인
2. 달성했으면 첫 세트의 weight에 `progressionIncrementKg` 적용
3. 안전 캡 (10%) 유지
4. 나머지 세트는 기존 이전 세션 값 유지 (세션 내 오버로드가 처리)

**검증:** 이전 세션에서 모든 렙 달성 시 첫 세트 무게가 증가되어 프리필

## 테스트 전략

| 수정 | 테스트 |
|------|--------|
| P1-1 | WorkoutTemplateRecommendationService 기존 테스트 유지 (UI 연결은 View 레벨) |
| P1-2 | WorkoutSessionViewModelTests에 shouldSuggestLevelUp 테스트 추가 |
| P1-3 | BedtimeWatchReminderScheduler 설정 토글 테스트 |
| P2-1 | NotificationThrottleStoreTests에 통합 알림 버퍼 테스트 추가 |
| P2-2 | WorkoutSessionViewModelTests에 inter-session overload 테스트 추가 |
| P2-3 | 설정 UI 변경 (View 레벨, 테스트 면제) |

## 리스크

- P1-3: wrist temperature는 sleep 세션에서만 기록되므로 "어제 밤 착용 여부"만 판단 가능. 실시간 감지 불가 → 이 한계를 명시
- P2-1: background delivery는 `.hourly` 배치이므로 foreground에서만 통합 효과 발생 → 알려진 제약
- P1-1: WorkoutSummary→ExerciseDefinition 매핑은 현재 미구현이므로 추천 표시만 (템플릿 자동 생성 미포함)
