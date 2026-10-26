---
tags: [ios, ipados, iphone-duo, design-system, screen-inventory]
date: 2026-10-12
category: plan
status: draft
---

# 폰 계열 전체 화면 인벤토리

SwiftUI View와 인라인 프레젠테이션 **108개**를 화면 단위로 대조한다. W17·W18은 소스에 남아 있지만 현재 앱에서 호출하는 곳이 없어 캡처 대상 수에서 제외한다. 차트·카드·버튼 같은 내부 컴포넌트는 별도 화면이 아니다.

## 시작 · 오늘 · 알림 (18)

| ID | 화면 | 진입 | 표시 방식 | 일반 iPhone | iPad | Duo | 코드 |
|---|---|---|---|---|---|---|---|
| T01 | 앱 시작 | 앱 실행 | launch | 앱 시작 · 준비 상태 | 앱 시작 · 준비 상태 | 앱 시작 · 준비 상태 | `DUNE/App/DUNEApp.swift:1121` |
| T02 | iCloud 동기화 동의 | 앱 시작 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Shared/CloudSyncConsentView.swift:3` |
| T03 | 오늘 | 탭 | root | 하단 탭 · 한 열 | 사이드바 · 넓은 콘텐츠 | 외부 한 열 → 내부 확장 | `DUNE/Presentation/Dashboard/DashboardView.swift:4` |
| T04 | 컨디션 상세 | 오늘 점수 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Dashboard/ConditionScoreDetailView.swift:8` |
| T05 | 누적 스트레스 | 오늘 카드 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Dashboard/CumulativeStressDetailView.swift:7` |
| T06 | 건강 지표 상세 | 오늘·웰니스 카드 | Today push · Wellness 기존 경로 | Today 상세 push · 한 열 | Today 상세 push · Wellness 선택 상세 | Today 두 자세 push | `DUNE/Presentation/Shared/Detail/MetricDetailView.swift:5` |
| T07 | 전체 데이터 | 지표 상세 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Shared/Detail/AllDataView.swift:4` |
| T08 | 날씨 상세 | 오늘 브리핑 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Dashboard/WeatherDetailView.swift:5` |
| T09 | 아침 브리핑 | 오늘 카드·자동 표시 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Dashboard/MorningBriefingView.swift:4` |
| T10 | 일간 요약 | 알림·오늘 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Dashboard/DailyDigestNotificationView.swift:4` |
| T11 | 알림함 | 오늘 도구막대 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Dashboard/NotificationHubView.swift:161` |
| T12 | 알림 메시지 | 알림함 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Dashboard/NotificationHubView.swift:562` |
| T13 | 알림 대상 없음 | 알림함 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Dashboard/NotificationHubView.swift:586` |
| T14 | 운동 기록 없음 | 운동 알림 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Shared/NotificationTargetNotFoundView.swift:4` |
| T15 | 수면 알림 상세 | 수면 알림 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/App/ContentView.swift:491` |
| T16 | 기록 알림 상세 | 개인 기록 알림 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Shared/NotificationPersonalRecordsPushView.swift:3` |
| T17 | 건강 데이터 질문 | 오늘 카드 | inspector | 좁은 폭에서는 시트 | 선택 상세 inspector | 닫힘 시트 → 내부 보조 | `DUNE/Presentation/Dashboard/HealthDataQASheet.swift:3` |
| T18 | 고정 지표 편집 | 오늘 지표 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Dashboard/Components/PinnedMetricsEditorView.swift:3` |

## 활동 · 분석 (20)

| ID | 화면 | 진입 | 표시 방식 | 일반 iPhone | iPad | Duo | 코드 |
|---|---|---|---|---|---|---|---|
| A01 | 활동 | 탭 | root | 하단 탭 · 한 열 | 사이드바 · 넓은 콘텐츠 | 외부 한 열 → 내부 확장 | `DUNE/Presentation/Activity/ActivityView.swift:83` |
| A02 | 운동 준비도 | 활동 점수 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Activity/TrainingReadiness/TrainingReadinessDetailView.swift:8` |
| A03 | 근육 회복 지도 | 활동 회복 카드 | push | 상세 push · 한 열 | 적응형 두 pane | 접힘 후 pane 재배치 | `DUNE/Presentation/Activity/MuscleMap/MuscleMapDetailView.swift:5` |
| A04 | 3D 근육 지도 | 활동·근육 상세 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift:5` |
| A05 | 주간 운동 통계 | 활동 통계 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Activity/WeeklyStats/WeeklyStatsDetailView.swift:5` |
| A06 | 훈련 볼륨 | 활동 볼륨 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeDetailView.swift:6` |
| A07 | 운동 종류 상세 | 훈련 볼륨 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Activity/TrainingVolume/ExerciseTypeDetailView.swift:7` |
| A08 | 부상 위험 상세 | 활동 위험 카드 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Activity/InjuryRiskDetail/InjuryRiskDetailView.swift:4` |
| A09 | 주간 운동 리포트 | 활동 리포트 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Activity/WorkoutReportDetail/WorkoutReportDetailView.swift:4` |
| A10 | 개인 기록 | 활동 기록 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift:5` |
| A11 | 운동 일관성 | 활동 카드 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Activity/Consistency/ConsistencyDetailView.swift:16` |
| A12 | 운동 구성 | 활동 카드 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Activity/ExerciseMix/ExerciseMixDetailView.swift:6` |
| A13 | 근육 상세 팝오버 | 근육 지도 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Activity/Components/MuscleDetailPopover.swift:6` |
| A14 | 피로도 설명 | 근육 상세 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Activity/Components/FatigueInfoSheet.swift:4` |
| A15 | 피로도 계산 설명 | 회복 지도 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Activity/Components/FatigueAlgorithmSheet.swift:5` |
| A16 | 볼륨 계산 설명 | 회복 지도 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Activity/Components/VolumeAlgorithmSheet.swift:5` |
| A17 | 개인 기록 설명 | 활동 기록 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Activity/Components/PersonalRecordsInfoSheet.swift:4` |
| A18 | 일관성 설명 | 활동 카드 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Activity/Components/ConsistencyInfoSheet.swift:4` |
| A19 | 운동 구성 설명 | 활동 카드 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Activity/Components/ExerciseMixInfoSheet.swift:4` |
| A20 | 추천 장비 정보 | 추천 운동 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Activity/Components/SuggestedWorkoutSection.swift:603` |

## 운동 · 계획 · 기록 (33)

| ID | 화면 | 진입 | 표시 방식 | 일반 iPhone | iPad | Duo | 코드 |
|---|---|---|---|---|---|---|---|
| W01 | 운동 목록 | 활동 최근 운동 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Exercise/ExerciseView.swift:10` |
| W02 | 운동 선택 | 활동 추가·운동 시작 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift:9` |
| W03 | 운동 정보 | 운동 선택·추천 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Exercise/Components/ExerciseDetailSheet.swift:3` |
| W04 | 맞춤 운동 생성 | 운동 선택 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Exercise/Components/CreateCustomExerciseView.swift:4` |
| W05 | 운동 시작 설정 | 운동 선택 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Exercise/ExerciseStartView.swift:6` |
| W06 | 근력 운동 중 | 운동 시작 | push | 상세 push · 한 열 | 넓은 폭: 기록 + 입력 병렬 | 닫힘 한 열 → 내부 병렬 | `DUNE/Presentation/Exercise/WorkoutSessionView.swift:9` |
| W07 | 세트 휴식 | 운동 중 | state | 현재 흐름 내부 | 세션 내부 | 초안·타이머 유지 | `DUNE/Presentation/Exercise/Components/RestTimerView.swift:3` |
| W08 | 세트 RPE | 운동 중 | state | 현재 흐름 내부 | 세션 내부 | 초안·타이머 유지 | `DUNE/Presentation/Exercise/Components/SetRPEPickerView.swift:4` |
| W09 | RPE 도움말 | 강도 입력 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Exercise/Components/RPEHelpSheet.swift:4` |
| W10 | 운동 완료 | 근력·복합 운동 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Exercise/Components/WorkoutCompletionSheet.swift:13` |
| W11 | 운동 공유 | 운동 완료·기록 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Exercise/Components/ShareImageSheet.swift:10` |
| W12 | 운동 템플릿 목록 | 운동 도구막대 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Exercise/Components/WorkoutTemplateListView.swift:4` |
| W13 | 템플릿 편집 | 템플릿·추천 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift:13` |
| W14 | 템플릿 운동 선택 | 템플릿 편집 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift:549` |
| W15 | 주간 운동 계획 | 템플릿 목록 | push | 상세 push · 한 열 | 적응형 두 pane | 접힘 후 pane 재배치 | `DUNE/Presentation/Exercise/WeeklyWorkoutPlanView.swift:4` |
| W16 | 템플릿 운동 세션 | 템플릿 시작 | cover | 전체 화면 흐름 | 전체 화면 흐름 | 촬영·세션 상태 유지 | `DUNE/Presentation/Exercise/TemplateWorkoutContainerView.swift:16` |
| W17 | 템플릿 운동 (현재 진입 경로 없음) | 템플릿 세션 | state | 현재 흐름 내부 | 세션 내부 | 초안·타이머 유지 | `DUNE/Presentation/Exercise/TemplateWorkoutView.swift:6` |
| W18 | 운동 순서 변경 (현재 진입 경로 없음) | 템플릿 운동 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Exercise/Components/ExerciseReorderSheet.swift:5` |
| W19 | 복합 운동 설정 | 운동 추가 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Exercise/Components/CompoundWorkoutSetupView.swift:12` |
| W20 | 복합 운동 선택 | 복합 운동 설정 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Exercise/Components/CompoundWorkoutSetupView.swift:151` |
| W21 | 복합 운동 중 | 복합 운동 설정 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Exercise/CompoundWorkoutView.swift:4` |
| W22 | 다음 운동 전환 | 복합·템플릿 운동 | state | 현재 흐름 내부 | 세션 내부 | 초안·타이머 유지 | `DUNE/Presentation/Exercise/Components/ExerciseTransitionView.swift:5` |
| W23 | 유산소 시작 설정 | 운동 선택 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Exercise/CardioSession/CardioStartSheet.swift:5` |
| W24 | 유산소 운동 중 | 유산소 시작 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Exercise/CardioSession/CardioSessionView.swift:5` |
| W25 | 유산소 완료 | 유산소 운동 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Exercise/CardioSession/CardioSessionSummaryView.swift:5` |
| W26 | 운동 기록 목록 | 운동 목록·활동 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Exercise/ExerciseHistoryView.swift:5` |
| W27 | 근력 기록 상세 | 운동 기록 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Exercise/ExerciseSessionDetailView.swift:5` |
| W28 | HealthKit 운동 상세 | 활동 최근 운동 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift:5` |
| W29 | 운동 분류 관리 | 운동 목록 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Exercise/Components/UserCategoryManagementView.swift:5` |
| W30 | 운동 분류 편집 | 분류 관리 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Exercise/Components/UserCategoryManagementView.swift:113` |
| W31 | 마지막 세트 선택 | 운동 중 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Exercise/WorkoutSessionView.swift` |
| W32 | 운동 분석 시트 | 운동 중 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Exercise/WorkoutSessionView.swift` |
| W33 | 운동 이름 편집 | 운동 기록 상세 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift` |

## 웰니스 · 수면 · 신체 (14)

| ID | 화면 | 진입 | 표시 방식 | 일반 iPhone | iPad | Duo | 코드 |
|---|---|---|---|---|---|---|---|
| H01 | 웰니스 | 탭 | root | 하단 탭 · 한 열 | 사이드바 · 넓은 콘텐츠 | 외부 한 열 → 내부 확장 | `DUNE/Presentation/Wellness/WellnessView.swift:4` |
| H02 | 웰니스 점수 상세 | 웰니스 점수 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Wellness/WellnessScoreDetailView.swift:8` |
| H03 | 수면 예측 | 웰니스 수면 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Wellness/SleepPredictionDetail/SleepPredictionDetailView.swift:4` |
| H04 | 지표 비교 | 웰니스 도구막대 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Wellness/MetricComparisonView.swift:5` |
| H05 | 신체 기록 입력·수정 | 웰니스 추가·이력 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/BodyComposition/BodyCompositionFormSheet.swift:3` |
| H06 | 신체 기록 이력 | 웰니스 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Wellness/BodyHistoryDetailView.swift:4` |
| H07 | 자세 기록 열기 | 웰니스 최근 자세 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Wellness/WellnessView.swift:702` |
| H08 | 부상 기록 입력·수정 | 웰니스 추가·이력 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Injury/InjuryFormSheet.swift:3` |
| H09 | 부상 이력 | 웰니스 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Injury/InjuryHistoryView.swift:5` |
| H10 | 부상 기록 상세 | 부상 이력 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Injury/InjuryHistoryView.swift:238` |
| H11 | 부상 통계 | 부상 이력 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Injury/InjuryStatisticsView.swift:5` |
| H12 | 수면 부족 설명 | 수면 카드 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Sleep/SleepDebtInfoSheet.swift:4` |
| H13 | 중간 각성 설명 | 수면 상세 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Sleep/Components/WASOInfoSheet.swift:4` |
| H14 | 심박 회복 설명 | 운동·웰니스 지표 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Shared/Extensions/HeartRateRecovery+View.swift:67` |

## 자세 · 촬영 (8)

| ID | 화면 | 진입 | 표시 방식 | 일반 iPhone | iPad | Duo | 코드 |
|---|---|---|---|---|---|---|---|
| P01 | 자세 촬영 | 웰니스·자세 이력 | cover | 전체 화면 흐름 | 전체 화면 흐름 | 촬영·세션 상태 유지 | `DUNE/Presentation/Posture/PostureCaptureView.swift:6` |
| P02 | 실시간 자세 분석 | 웰니스 추가 | cover | 전체 화면 흐름 | 전체 화면 흐름 | 촬영·세션 상태 유지 | `DUNE/Presentation/Posture/RealtimePostureView.swift:6` |
| P03 | 교정 운동 선택 | 실시간 자세 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Posture/Components/ExercisePickerSheet.swift:5` |
| P04 | 자세 분석 결과 | 자세 촬영 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Posture/PostureResultView.swift:5` |
| P05 | 자세 이력 | 웰니스 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Posture/PostureHistoryView.swift:4` |
| P06 | 자세 기록 상세 | 자세 이력 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Posture/PostureDetailView.swift:4` |
| P07 | 자세 대칭 상세 | 자세 기록 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Posture/PostureSymmetryView.swift:4` |
| P08 | 자세 전후 비교 | 자세 이력 | push | 상세 push · 한 열 | 적응형 두 pane | 접힘 후 pane 재배치 | `DUNE/Presentation/Posture/PostureComparisonView.swift:3` |

## 라이프 · 습관 (8)

| ID | 화면 | 진입 | 표시 방식 | 일반 iPhone | iPad | Duo | 코드 |
|---|---|---|---|---|---|---|---|
| L01 | 라이프 | 탭 | root | 하단 탭 · 한 열 | 사이드바 · 넓은 콘텐츠 | 외부 한 열 → 내부 확장 | `DUNE/Presentation/Life/LifeView.swift:27` |
| L02 | 습관 추가·수정 | 라이프·관리 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Life/HabitFormSheet.swift:3` |
| L03 | 습관 템플릿 | 라이프 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Life/HabitTemplateSheet.swift:3` |
| L04 | 습관 관리 | 라이프 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Life/HabitManagementView.swift:4` |
| L05 | 습관 이력 | 라이프 카드 | inspector | 좁은 폭에서는 시트 | 선택 상세 inspector | 닫힘 시트 → 내부 보조 | `DUNE/Presentation/Life/LifeView.swift:1224` |
| L06 | 관리 중 습관 이력 | 습관 관리 | sheet | 화면 내 시트 | 시트 · 보조 패널 | 닫힘/내부 시트 | `DUNE/Presentation/Life/HabitManagementView.swift:264` |
| L07 | 습관 히트맵 상세 | 라이프 분석 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Life/HabitHeatmapDetailView.swift:3` |
| L08 | 주간 습관 리포트 | 라이프 분석 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Life/WeeklyHabitReportView.swift:3` |

## 설정 · 기타 (7)

| ID | 화면 | 진입 | 표시 방식 | 일반 iPhone | iPad | Duo | 코드 |
|---|---|---|---|---|---|---|---|
| S01 | 설정 | 오늘 도구막대 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Settings/SettingsView.swift:5` |
| S02 | 운동 기본값 목록 | 설정 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Settings/Components/ExerciseDefaultsListView.swift:6` |
| S03 | 운동 기본값 편집 | 운동 기본값 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Settings/Components/ExerciseDefaultEditView.swift:6` |
| S04 | 선호 운동 | 설정 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/Settings/Components/PreferredExercisesListView.swift:5` |
| S05 | 새 소식 | 오늘·설정·앱 시작 | push/sheet | 상세 push 또는 시트 | 상세 push 또는 시트 | push 또는 시트 · 상태 유지 | `DUNE/Presentation/WhatsNew/WhatsNewView.swift:8` |
| S06 | 새 기능 상세 | 새 소식 | push | 상세 push · 한 열 | 상세 콘텐츠 | 선택·스크롤 유지 | `DUNE/Presentation/WhatsNew/WhatsNewView.swift:151` |
| S07 | 운동 분석 별도 창 | iPad 운동 중 | window | 운동 분석 시트로 대체 | 별도 읽기 전용 창 | 운동 분석 시트로 대체 | `DUNE/App/DUNEApp.swift:1074` |

## 앱 밖의 시스템 표면

이 표면은 위 108개 앱 화면 수에 포함하지 않는다. 캡처 출처도 앱 내부 화면과 별도로 관리한다.

| ID | 표면 | 진입 | 상태 | 실제 화면 맵 |
|---|---|---|---|---|
| WLA01 | Watch 운동 Live Activity | Watch 운동 미러링 → ActivityKit | iPhone 알림 센터 진행·일시 정지·연결 대기, Dynamic Island compact·expanded 진행·일시 정지 | [WLA01 실제 화면](actual/live-activity/index.html) |
