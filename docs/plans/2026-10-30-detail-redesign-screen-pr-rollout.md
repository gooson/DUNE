---
topic: detail-redesign-screen-pr-rollout
date: 2026-10-30
status: in-progress
confidence: medium
execution: native-implementation-authorized
related_solutions:
  - ../solutions/architecture/2026-02-28-detail-score-hero-unification.md
  - ../solutions/architecture/2026-03-14-score-detail-unification.md
  - ../solutions/testing/2026-10-29-detail-prototype-feature-parity.md
---

# 상세 개편의 화면별 /run·PR 분리

## Context

사용자는 시안 정리가 끝나면 각 화면을 `/run`으로 실행하고 PR을 분리하도록 요청했다. 사용자가 실제 앱 구현과 화면별 PR 생성을 선택했고, L03 습관 템플릿부터 네이티브 구현을 시작했다. 이 문서는 독립적으로 준비한 분리 목록이며 전체 `/run` 완료 증거가 아니다.

시안 보존 당시 기준 작업 폴더는 `/Users/shanks/.codex/worktrees/da96/Health`, 기준 HEAD는 `2b2ace2e`의 detached HEAD다. 로컬 origin/main은 `25ebca1b`이며 이는 초기 보존 기록이며 실제 native base는 각 화면 계획과 PR에 별도로 기록한다. 기존 시안534개 파일과 현재 추적 파일 변경은 원본 위치에 보존한다. 전부 한꺼번에 커밋·stash하거나 서버 경로를 옮기지 않는다.

## Current Execution

- L03 습관 템플릿: 네이티브 구현, iPhone 2/2·iPad 1/1·Duo 접힘 1/1·펼침 1/1 UI와 새 네 기기 캡처, 리뷰, CI 완료. [PR #858](https://github.com/gooson/DUNE/pull/858) MERGED, merge commit `60bd7c4b`. 화면별 첫 `/run`의 Ship 후 정리까지 완료했다.
- 실행 worktree: `/Users/shanks/.codex/worktrees/detail-redesign-l03/Health`, branch `codex/score-history-window-foundation`.
- T04 컨디션 상세: [PR #862](https://github.com/gooson/DUNE/pull/862) MERGED, merge `9fa10e46`. 단위32·기기별UI15·새4기기원본·리뷰·Compound·CI·Ship·브랜치정리·표준regen/build까지 완료.
- 공통 기간 계산 선행: [PR #863](https://github.com/gooson/DUNE/pull/863). 동일 함수2개 추출, 관련26단위·선택UI2·리뷰·Compound 완료. Ship 점검 중이며 T05 화면 PR과 분리한다.
- 다음 화면은 T05 누적 스트레스다. 코드·검토 시안·가중치 재배분·기존 캡처의 READ-ONLY 조사를 완료했다. 원본 시안은 da96에 유지하고 실행 목록은 native 저장소에도 보존한다.

## Requirements

- 159개 시안 분기를 106개 화면 ID로 매핑한다. T06/T07의16지표, L02의유형/주기 등 같은 화면의 분기는 해당 화면 PR에 포함한다.
- 독립적으로 출시 가능한 공통 시각 기반은 별도 선행 PR로 구현한다. 화면 구현에 필요한 작은 추출은 기본 동작을 유지한 채 해당 화면 PR에 포함할 수 있다. 소비 화면은 각각 분리하고 전체 탭을 한 PR로 합치지 않는다.
- 네이티브 구현이면 iPhone·iPad·Duo만 대상으로 한다. 3D 근육 지도는 코드를 유지하고 메뉴만 비활성화한다. 현재 진입 없는 W17/W18을 임의로 활성화하지 않는다.
- 예시 점수·측정값·비교 평균을 앱에 하드코딩하지 않는다. 기존 계산·모델·CRUD 권한·Health 읽기 전용·기간 선택·상태를 유지한다.
- 각 화면 PR에서 Plan→Work→UI Test→Review→Quality→Resolve→Compound→Pre-Ship→Ship의 증거를 독립적으로 기록한다. 필요한 게이트가 미완료인 PR은 완료·머지로 표시하지 않는다.

## Approach

1. 사용자 범위 답변은 실제 앱 구현으로 확정됐다. 검토된 L03부터 기존 디자인 시스템을 재사용해 화면별 실행을 시작한다.
2. 원본 시안은 그대로 보존하고 native 화면 작업은 최신 실제 base의 격리된 `codex/` 브랜치/worktree에서 수행한다.
3. 공통 기반(링/히어로, 아이콘 포함 지표 행, 기간/통계, 여백/버튼)을 하나씩 독립 검증 가능한 선행 PR로 나눈다. 기존 DetailScoreHero·ScoreDetailSummaryStats·ScoreCompositionCard를 우선 재사용한다.
4. 아래 목록에서 한 화면의 계획·구현·검증·리뷰·문서화·Ship를 끝낸 뒤 다음 화면으로 이동한다. 같은 Swift 파일을 쓰는 S05/S06, W06/W31/W32 등은 순차 적용하여 기능별 diff를 유지한다.
5. H07은 P06 상세를 공유하므로 P06의 공통 상세 변경 이후 조회 경로만 별도로 확인한다. 동일 코드를 복제하지 않는다.
6. 시안 파일만 분리하는 범위라면 native 구현 단계 대신 gallery 공통 기반·화면별 source 정의·generated 산출물의 빌드 의존성을 먼저 분리한다. 현재 untracked 전체를 하나의 화면 PR에 싣거나 의미 없는 빈 후속 PR을 만들지 않는다.

## Affected Files

- 시안 기준: `docs/design/detail-redesign-map/manifest.json`, 관련 화면별 시안 모듈과 data 정의.
- 네이티브 화면의 현재 진입 파일: 아래 전체 목록에 표시.
- 공통 컴포넌트: `DUNE/Presentation/Shared/Components/` 및 기존 디자인 시스템. 정확한 목록은 각 선행 PR Plan에서 호출부를 확인하여 확정.
- 각 화면 계획/증거: `docs/plans/`, `docs/solutions/`, 영향받는 `docs/design/phone-design-map/actual/`의 새 캡처 및 맵.

## Testing Strategy

각 PR에서 `scripts/plan-ui-tests.py`를 실제 PR base에 적용하고 변경 symbol의 소비자를 조사한다. 앱 변경이면 표준 build/unit/UI 실행기와 해당 worktree 소유 기기를 사용한다. 영향 화면의 iPhone/iPad/Duo 상태를 실제 캡처하고 맵을 갱신한다. 브라우저 시안 검증을 네이티브 검증으로 재사용하지 않는다. 문서/시안만 변경하면 Codex adapter에 따른 범위 판정과 Python/JS 계약·브라우저 검증 근거를 기록하고 native UI 통과라고 보고하지 않는다.

## Risks / Edge Cases

| 경우 | 처리 |
|---|---|
| 같은 컴포넌트가 여러 화면에 영향 | 공통 선행 PR과 소비자 검증을 분리하고 영향 경로를 기록 |
| 같은 Swift 파일에 여러 화면 | 파일 전체 복사 대신 해당 화면 diff만 순차 적용 |
| 3D/현재 비활성 경로 | 코드 보존, 승인된 메뉴 비활성만 반영 |
| fixture/도식/미디어 | 실제 데이터·실제 사진으로 가장하지 않음; 앱에서는 모델/사진/라이선스 확인된 자산 사용 |
| 원본 PNG와 다른 기능/모드 | 해당 상태를 새로 캡처하고 출처와 화면 ID를 갱신 |
| 기존 dirty 상태·오래된 detached base | 원본 보존, 최신 base의 별도 작업 범위에서 시작 |
| 필요한 실행 환경 실패 | 같은 원인 재시도 한도와 재개 조건을 기록하고 미완료 게이트를 통과시키지 않음 |

## Execution State

실제 앱 구현 범위가 확정됐다. 화면별 실행 상태는 각 화면 계획/파이프라인 증거에서 관리한다. 아래 표는 전체 rollout의 초기 기준 상태다.

| Phase | 상태 | 현재 근거 |
|---|---|---|
| 0 Init | 준비 / 범위 답변 대기 | 브랜치·dirty 상태·교정사항·run/adapter 확인 |
| 1 Plan | 미실행 | 현재 문서는 PR 분리 초안; 화면별 계획은 실행 때 생성 |
| 2 Work | 미실행 | 네이티브/시안 PR 범위 답변 대기 |
| 2.5 UI | 미실행 | 앱 변경·기기·selector 미확정 |
| 3 Review | 미실행 | PR별 diff가 아직 없음 |
| 3.5 Quality | 미실행 | 구현 범위 확정 후 역할 배정 |
| 4 Resolve | 미실행 | 리뷰 결과 없음 |
| 5 Compound | 미실행 | 화면별 실행 후 문서 생성 |
| 5.5 Pre-Ship | 미실행 | 브랜치 생성/commit/push 하지 않음 |
| 6 Ship | 미실행 | PR 생성/머지 하지 않음 |

## Screen / PR Inventory

이 목록은 PR 분리의 검토 단위이며, 시안의 모든 화면이 최종적으로 변경되어야 한다는 의미는 아니다. 구현 단계에서 현행과 이미 동등한 화면은 근거와 함께 별도로 판정한다.

| ID | 화면 | 분기 | 네이티브 진입 파일 | 추가 조건 |
|---|---|---:|---|---|
| T04 | 컨디션 상세 | 1 | `DUNE/Presentation/Dashboard/ConditionScoreDetailView.swift` | — |
| T02 | iCloud 동기화 동의 | 1 | `DUNE/Presentation/Shared/CloudSyncConsentView.swift` | — |
| T05 | 누적 스트레스 | 1 | `DUNE/Presentation/Dashboard/CumulativeStressDetailView.swift` | — |
| T06 | 건강 지표 상세 · HRV | 16 | `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | 16개 지표 포함 |
| T07 | 전체 데이터 · HRV | 16 | `DUNE/Presentation/Shared/Detail/AllDataView.swift` | 16개 지표 포함 |
| T08 | 날씨 상세 | 1 | `DUNE/Presentation/Dashboard/WeatherDetailView.swift` | — |
| T09 | 아침 브리핑 | 1 | `DUNE/Presentation/Dashboard/MorningBriefingView.swift` | — |
| T10 | 일간 요약 | 1 | `DUNE/Presentation/Dashboard/DailyDigestNotificationView.swift` | — |
| T11 | 알림함 | 1 | `DUNE/Presentation/Dashboard/NotificationHubView.swift` | — |
| T12 | 알림 메시지 | 1 | `DUNE/Presentation/Dashboard/NotificationHubView.swift` | — |
| T13 | 알림 대상 없음 | 1 | `DUNE/Presentation/Dashboard/NotificationHubView.swift` | — |
| T14 | 운동 기록 없음 | 1 | `DUNE/Presentation/Shared/NotificationTargetNotFoundView.swift` | — |
| T15 | 수면 알림 상세 | 1 | `DUNE/App/ContentView.swift` | — |
| T16 | 기록 알림 상세 | 1 | `DUNE/Presentation/Shared/NotificationPersonalRecordsPushView.swift` | — |
| T17 | 건강 데이터 질문 | 1 | `DUNE/Presentation/Dashboard/HealthDataQASheet.swift` | — |
| T18 | 고정 지표 편집 | 1 | `DUNE/Presentation/Dashboard/Components/PinnedMetricsEditorView.swift` | — |
| A02 | 운동 준비도 | 1 | `DUNE/Presentation/Activity/TrainingReadiness/TrainingReadinessDetailView.swift` | — |
| A03 | 근육 회복 지도 | 1 | `DUNE/Presentation/Activity/MuscleMap/MuscleMapDetailView.swift` | — |
| A04 | 3D 근육 지도 | 1 | `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift` | 코드 보존·메뉴 비활성 |
| A05 | 주간 운동 통계 | 1 | `DUNE/Presentation/Activity/WeeklyStats/WeeklyStatsDetailView.swift` | — |
| A06 | 훈련 볼륨 | 1 | `DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeDetailView.swift` | — |
| A07 | 운동 종류 상세 | 1 | `DUNE/Presentation/Activity/TrainingVolume/ExerciseTypeDetailView.swift` | — |
| A08 | 부상 위험 상세 | 1 | `DUNE/Presentation/Activity/InjuryRiskDetail/InjuryRiskDetailView.swift` | — |
| A09 | 주간 운동 리포트 | 1 | `DUNE/Presentation/Activity/WorkoutReportDetail/WorkoutReportDetailView.swift` | — |
| A10 | 개인 기록 | 1 | `DUNE/Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift` | — |
| A11 | 운동 일관성 | 1 | `DUNE/Presentation/Activity/Consistency/ConsistencyDetailView.swift` | — |
| A12 | 운동 구성 | 1 | `DUNE/Presentation/Activity/ExerciseMix/ExerciseMixDetailView.swift` | — |
| A13 | 근육 상세 팝오버 | 1 | `DUNE/Presentation/Activity/Components/MuscleDetailPopover.swift` | — |
| A14 | 피로도 설명 | 1 | `DUNE/Presentation/Activity/Components/FatigueInfoSheet.swift` | — |
| A15 | 피로도 계산 설명 | 1 | `DUNE/Presentation/Activity/Components/FatigueAlgorithmSheet.swift` | — |
| A16 | 볼륨 계산 설명 | 1 | `DUNE/Presentation/Activity/Components/VolumeAlgorithmSheet.swift` | — |
| A17 | 개인 기록 설명 | 1 | `DUNE/Presentation/Activity/Components/PersonalRecordsInfoSheet.swift` | — |
| A18 | 일관성 설명 | 1 | `DUNE/Presentation/Activity/Components/ConsistencyInfoSheet.swift` | — |
| A19 | 운동 구성 설명 | 1 | `DUNE/Presentation/Activity/Components/ExerciseMixInfoSheet.swift` | — |
| A20 | 추천 장비 정보 | 1 | `DUNE/Presentation/Activity/Components/SuggestedWorkoutSection.swift` | — |
| W01 | 운동 목록 | 1 | `DUNE/Presentation/Exercise/ExerciseView.swift` | — |
| W02 | 운동 선택 | 1 | `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift` | — |
| W03 | 운동 정보 | 1 | `DUNE/Presentation/Exercise/Components/ExerciseDetailSheet.swift` | — |
| W04 | 맞춤 운동 생성 | 1 | `DUNE/Presentation/Exercise/Components/CreateCustomExerciseView.swift` | — |
| W05 | 운동 시작 설정 | 1 | `DUNE/Presentation/Exercise/ExerciseStartView.swift` | — |
| W06 | 근력 운동 중 | 1 | `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | — |
| W07 | 세트 휴식 | 1 | `DUNE/Presentation/Exercise/Components/RestTimerView.swift` | — |
| W08 | 세트 RPE | 1 | `DUNE/Presentation/Exercise/Components/SetRPEPickerView.swift` | — |
| W09 | RPE 도움말 | 1 | `DUNE/Presentation/Exercise/Components/RPEHelpSheet.swift` | — |
| W10 | 운동 완료 | 1 | `DUNE/Presentation/Exercise/Components/WorkoutCompletionSheet.swift` | — |
| W11 | 운동 공유 | 1 | `DUNE/Presentation/Exercise/Components/ShareImageSheet.swift` | — |
| W12 | 운동 템플릿 목록 | 1 | `DUNE/Presentation/Exercise/Components/WorkoutTemplateListView.swift` | — |
| W13 | 운동 템플릿 · 새로 만들기 | 3 | `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift` | — |
| W14 | 템플릿 운동 선택 | 1 | `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift` | — |
| W15 | 주간 운동 계획 | 1 | `DUNE/Presentation/Exercise/WeeklyWorkoutPlanView.swift` | — |
| W16 | 템플릿 운동 세션 | 1 | `DUNE/Presentation/Exercise/TemplateWorkoutContainerView.swift` | — |
| W17 | 템플릿 운동 | 1 | `DUNE/Presentation/Exercise/TemplateWorkoutView.swift` | 현재 진입 없음 보존 |
| W18 | 운동 순서 변경 | 1 | `DUNE/Presentation/Exercise/Components/ExerciseReorderSheet.swift` | 현재 진입 없음 보존 |
| W19 | 복합 운동 설정 | 1 | `DUNE/Presentation/Exercise/Components/CompoundWorkoutSetupView.swift` | — |
| W20 | 복합 운동 선택 | 1 | `DUNE/Presentation/Exercise/Components/CompoundWorkoutSetupView.swift` | — |
| W21 | 복합 운동 중 | 1 | `DUNE/Presentation/Exercise/CompoundWorkoutView.swift` | — |
| W22 | 다음 운동 전환 | 1 | `DUNE/Presentation/Exercise/Components/ExerciseTransitionView.swift` | — |
| W23 | 유산소 시작 설정 | 1 | `DUNE/Presentation/Exercise/CardioSession/CardioStartSheet.swift` | — |
| W24 | 유산소 운동 중 | 1 | `DUNE/Presentation/Exercise/CardioSession/CardioSessionView.swift` | — |
| W25 | 유산소 완료 | 4 | `DUNE/Presentation/Exercise/CardioSession/CardioSessionSummaryView.swift` | — |
| W26 | 운동 기록 목록 | 1 | `DUNE/Presentation/Exercise/ExerciseHistoryView.swift` | — |
| W27 | 근력 기록 상세 | 1 | `DUNE/Presentation/Exercise/ExerciseSessionDetailView.swift` | — |
| W28 | HealthKit 운동 상세 | 1 | `DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift` | — |
| W29 | 운동 분류 관리 | 1 | `DUNE/Presentation/Exercise/Components/UserCategoryManagementView.swift` | — |
| W30 | 운동 분류 추가 | 2 | `DUNE/Presentation/Exercise/Components/UserCategoryManagementView.swift` | — |
| H02 | 웰니스 점수 상세 | 1 | `DUNE/Presentation/Wellness/WellnessScoreDetailView.swift` | — |
| H03 | 수면 예측 | 1 | `DUNE/Presentation/Wellness/SleepPredictionDetail/SleepPredictionDetailView.swift` | — |
| H04 | 지표 비교 | 1 | `DUNE/Presentation/Wellness/MetricComparisonView.swift` | — |
| H05 | 신체 기록 추가 | 2 | `DUNE/Presentation/BodyComposition/BodyCompositionFormSheet.swift` | — |
| H06 | 신체 기록 이력 | 1 | `DUNE/Presentation/Wellness/BodyHistoryDetailView.swift` | — |
| H07 | 자세 기록 열기 | 1 | `DUNE/Presentation/Wellness/WellnessView.swift` | P06 상세 공유; P06 이후 |
| H08 | 부상 기록 추가 | 3 | `DUNE/Presentation/Injury/InjuryFormSheet.swift` | — |
| H09 | 부상 이력 | 1 | `DUNE/Presentation/Injury/InjuryHistoryView.swift` | — |
| H10 | 부상 기록 상세 | 1 | `DUNE/Presentation/Injury/InjuryHistoryView.swift` | — |
| H11 | 부상 통계 | 1 | `DUNE/Presentation/Injury/InjuryStatisticsView.swift` | — |
| H12 | 수면 부족 설명 | 1 | `DUNE/Presentation/Sleep/SleepDebtInfoSheet.swift` | — |
| H13 | 중간 각성 설명 | 1 | `DUNE/Presentation/Sleep/Components/WASOInfoSheet.swift` | — |
| H14 | 심박 회복 설명 | 1 | `DUNE/Presentation/Shared/Extensions/HeartRateRecovery+View.swift` | — |
| P01 | 자세 촬영 | 1 | `DUNE/Presentation/Posture/PostureCaptureView.swift` | — |
| P02 | 실시간 자세 분석 | 1 | `DUNE/Presentation/Posture/RealtimePostureView.swift` | — |
| P03 | 교정 운동 선택 | 1 | `DUNE/Presentation/Posture/Components/ExercisePickerSheet.swift` | — |
| P04 | 자세 분석 결과 | 1 | `DUNE/Presentation/Posture/PostureResultView.swift` | — |
| P05 | 자세 이력 | 1 | `DUNE/Presentation/Posture/PostureHistoryView.swift` | — |
| P06 | 자세 기록 상세 | 1 | `DUNE/Presentation/Posture/PostureDetailView.swift` | H07 조회 경로 영향 확인 |
| P07 | 자세 대칭 상세 | 1 | `DUNE/Presentation/Posture/PostureSymmetryView.swift` | — |
| P08 | 자세 전후 비교 | 1 | `DUNE/Presentation/Posture/PostureComparisonView.swift` | — |
| L02 | 습관 추가 | 11 | `DUNE/Presentation/Life/HabitFormSheet.swift` | — |
| L03 | 습관 템플릿 | 1 | `DUNE/Presentation/Life/HabitTemplateSheet.swift` | — |
| L04 | 습관 관리 | 1 | `DUNE/Presentation/Life/HabitManagementView.swift` | — |
| L05 | 습관 이력 | 1 | `DUNE/Presentation/Life/LifeView.swift` | — |
| L06 | 관리 중 습관 이력 | 1 | `DUNE/Presentation/Life/HabitManagementView.swift` | — |
| L07 | 습관 히트맵 상세 | 1 | `DUNE/Presentation/Life/HabitHeatmapDetailView.swift` | — |
| L08 | 주간 습관 리포트 | 1 | `DUNE/Presentation/Life/WeeklyHabitReportView.swift` | — |
| L09 | 지난 날짜 습관 기록 | 5 | `DUNE/Presentation/Life/HabitPastRecordSheet.swift` | — |
| S01 | 설정 | 1 | `DUNE/Presentation/Settings/SettingsView.swift` | — |
| S02 | 운동 기본값 목록 | 1 | `DUNE/Presentation/Settings/Components/ExerciseDefaultsListView.swift` | — |
| S03 | 운동 기본값 편집 | 1 | `DUNE/Presentation/Settings/Components/ExerciseDefaultEditView.swift` | — |
| S04 | 선호 운동 | 1 | `DUNE/Presentation/Settings/Components/PreferredExercisesListView.swift` | — |
| S05 | 새 소식 | 1 | `DUNE/Presentation/WhatsNew/WhatsNewView.swift` | S06과 같은 파일; 화면별 순차 diff |
| S06 | 새 기능 상세 | 1 | `DUNE/Presentation/WhatsNew/WhatsNewView.swift` | S05와 같은 파일; 화면별 순차 diff |
| S07 | 운동 분석 별도 창 | 1 | `DUNE/App/DUNEApp.swift` | — |
| W31 | 마지막 세트 선택 | 1 | `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | — |
| W32 | 운동 분석 시트 | 1 | `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | — |
| W33 | 운동 이름 편집 | 1 | `DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift` | — |
| A21 | 보상 안내 | 1 | `DUNE/Presentation/Activity/PersonalRecords/Components/RewardProgressSection.swift` | — |
| W34 | AI 운동 빌더 | 1 | `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift` | — |
