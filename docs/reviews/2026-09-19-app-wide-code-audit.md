---
tags: [review, app-quality, watch, healthkit, statistics]
date: 2026-09-19
category: general
status: reviewed
---

# 앱 전반 코드 검토

- 기준: HEAD `89fb8455`, detached HEAD. 시작 시 변경 파일 및 main 대비 diff 없음.
- 범위: iOS 갱신·HealthKit 알림·통계·차트·Life 습관, Watch 운동 저장 및 iPhone 수신 경로를 중심으로 정적 검토. 모든 파일과 모든 화면을 실행 검증한 전수 감사는 아님.
- 특정 AI 모델의 작성 여부는 커밋 정보만으로 확정하지 않음. 현재 코드의 동작 결함을 기준으로 선정.
- 결과: P1 1건, P2 10건. 앱 소스 수정 없음.
- 검증: `scripts/build-ios.sh --no-regen` 성공. 전체 unit/UI test는 실행하지 않음.
- 별도 재현: 동일 AsyncStream의 소비자 간 이벤트 분산, 습관 완료 통계 불일치.
- 보안/성능/구조/데이터 무결성/단순성 및 앱 품질 관점 적용. 설정 변경이 없으므로 Agent-Native 검토 제외. 번역 변경 diff가 없어 localization 변경 게이트는 비대상.

## 발견 목록

### 1. [P1] 앱 새로고침 이벤트가 일부 소비자에게만 전달됨

- 위치: [DUNE/Data/Services/ScoreRefreshService.swift:46](/Users/shanks/.codex/worktrees/e854/Health/DUNE/Data/Services/ScoreRefreshService.swift:46)
- 문제·발생 조건: HealthKit 변경 또는 포그라운드 복귀 시 ScoreRefreshService와 ContentView가 동일 AsyncStream을 소비한다. 스트림은 broadcast가 아니므로 서비스가 소비한 이벤트는 화면 refreshSignal을 증가시키지 않는다.
- 근거·검증: AppRefreshCoordinatorImpl.swift의 단일 stream 생성, ContentView.swift:295, DUNEApp.swift:655. 별도 Swift 재현에서 8개 이벤트가 두 소비자에 4개씩 분산됨.
- 수정 방향: 구독별 스트림을 제공하거나 단일 소비자가 화면 및 sparkline 갱신을 함께 호출한다.
- 상태: Resolved — 4fa168f6. 독립 구독 및 broadcast 적용, iOS 회귀 테스트 22개 통과.

### 2. [P2] 주간 상세에서 동일 운동을 중복 합산

- 위치: [DUNE/Presentation/Activity/WeeklyStats/WeeklyStatsDetailView.swift:34](/Users/shanks/.codex/worktrees/e854/Health/DUNE/Presentation/Activity/WeeklyStats/WeeklyStatsDetailView.swift:34)
- 문제·발생 조건: HealthKit 쓰기에 성공한 앱 운동을 조회하면 로컬 기록과 HealthKit 운동이 모두 합산된다. 30분 운동 한 건이 60분/2세션으로 계산될 수 있다. snapshot 변환 과정에서 HealthKit 연결 ID도 사라진다.
- 근거·검증: WeeklyStatsDetailViewModel.loadData → TrainingVolumeAnalysisService.buildSummary:84–119의 두 합산 루프. 일반 Activity 화면은 연결 ID로 중복 제거.
- 수정 방향: 연결 ID를 보존해 중복 운동의 시간·칼로리·횟수를 제외하고 세트 볼륨은 유지한다.
- 상태: Resolved — d2052724. 2026-09-20 수정 및 회귀 검증.

### 3. [P2] Watch 종목별 전송에 전체 세션 시간이 들어감

- 위치: [DUNEWatch/Views/SessionSummaryView.swift:623](/Users/shanks/.codex/worktrees/e854/Health/DUNEWatch/Views/SessionSummaryView.swift:623)
- 문제·발생 조건: 3종목을 30분 운동하면 로컬은 종목당 10분으로 저장하지만 WC는 각 종목에 같은 시작/종료 시각을 전송한다. WC가 먼저 도착한 iPhone은 종목당 30분으로 저장한다.
- 근거·검증: 동일 파일:520 allocation.duration, DUNEApp.swift:758 및 773 수신 duration 계산.
- 수정 방향: DTO에 종목별 실제 duration을 전달하고 로컬 및 수신 경로에서 동일하게 사용한다.
- 상태: Resolved — 2026-09-19, WatchWorkoutRecordBuilder로 저장·전송 경로 통일. 앱 빌드 및 macOS SwiftData 회귀 테스트 통과.

### 4. [P2] Watch 종료 기록에 일시정지 시간이 포함됨

- 위치: [DUNEWatch/Views/SessionSummaryView.swift:554](/Users/shanks/.codex/worktrees/e854/Health/DUNEWatch/Views/SessionSummaryView.swift:554)
- 문제·발생 조건: 10분 운동 + 20분 일시정지 + 10분 운동을 40분으로 저장한다. 근력운동 배분과 MET 추정도 wall-clock 시간을 사용한다.
- 근거·검증: WorkoutManager.activeElapsedTime은 pause를 제외하지만 SessionSummaryView:413, 450, 554는 종료-시작 시간을 사용.
- 수정 방향: 종료 시 active elapsed를 캡처하여 요약·저장·칼로리 추정에 공유한다.
- 상태: Resolved — 8cf581b2. 2026-09-20 수정 및 회귀 검증.

### 5. [P2] Watch 영구 저장에서 세트 휴식시간 누락

- 위치: [DUNEWatch/Views/SessionSummaryView.swift:533](/Users/shanks/.codex/worktrees/e854/Health/DUNEWatch/Views/SessionSummaryView.swift:533)
- 문제·발생 조건: 타이머로 수집한 restDuration이 WorkoutSet 생성 시 전달되지 않아 nil로 저장된다. 즉시 WC에는 값이 있지만 CloudKit 및 후속 bulk sync에는 없어진다.
- 근거·검증: WorkoutManager.recordRestDuration, SessionSummaryView:613 WC payload, WatchConnectivityManager bulk sync의 로컬 set 읽기.
- 수정 방향: WorkoutSet 생성에 restDuration: setData.restDuration을 추가한다.
- 상태: Resolved — 2026-09-19, WatchWorkoutRecordBuilder로 저장·전송 경로 통일. 앱 빌드 및 macOS SwiftData 회귀 테스트 통과.

### 6. [P2] 사용자가 선택한 운동 강도가 세트 평균으로 덮어써짐

- 위치: [DUNEWatch/Views/SessionSummaryView.swift:548](/Users/shanks/.codex/worktrees/e854/Health/DUNEWatch/Views/SessionSummaryView.swift:548)
- 문제·발생 조건: 세트 RPE가 있는 근력운동에서 완료 화면의 강도를 직접 수정해도 applySetBasedRPE가 로컬 저장값을 평균으로 변경한다. WC에는 사용자가 선택한 effort를 전송한다.
- 근거·검증: ExerciseRecord+SetRPE.swift:12 재할당, SessionSummaryView:526 초기 rpe 및 626 전송 rpe.
- 수정 방향: 세트 평균은 초기 제안으로만 사용하고 명시적으로 선택한 effort를 최종값으로 유지한다.
- 상태: Resolved — 2026-09-19, WatchWorkoutRecordBuilder로 저장·전송 경로 통일. 앱 빌드 및 macOS SwiftData 회귀 테스트 통과.

### 7. [P2] HealthKit 완료 콜백을 비동기 처리 전에 호출

- 위치: [DUNE/Data/HealthKit/HealthKitObserverManager.swift:76](/Users/shanks/.codex/worktrees/e854/Health/DUNE/Data/HealthKit/HealthKitObserverManager.swift:76)
- 문제·발생 조건: Task를 시작한 직후 바깥 defer에서 completionHandler를 호출한다. 백그라운드 앱이 이후 중단되면 조회·알림·재예약이 누락될 수 있다.
- 근거·검증: 같은 파일:86 Task. 로컬 SDK HKObserverQuery.h는 데이터 처리 완료 후 completion 호출을 요구. 실기기 suspension 재현은 미실시.
- 수정 방향: 완료 콜백을 실제 비동기 처리의 종료 경로로 옮기고 오류 경로에서도 정확히 한 번 호출한다.
- 상태: Resolved — e34624c9. 2026-09-20 수정 및 회귀 검증.

### 8. [P2] 수면 알림이 증분 샘플을 밤 전체 수면으로 계산

- 위치: [DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift:236](/Users/shanks/.codex/worktrees/e854/Health/DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift:236)
- 문제·발생 조건: query가 자정 이후 시작한 샘플 및 anchor 이후 추가분만 반환하는데 이를 합산해 오늘의 전체 수면으로 저장한다. 분할 동기화의 마지막 20분만 전체 수면이 될 수 있다.
- 근거·검증: 동일 파일:133 strictStartDate, 139 anchor, 256 일별 수면 캐시 갱신. 실제 HealthKit 동기화 재현은 미실시.
- 수정 방향: 관찰 이벤트는 재조회 신호로 쓰고 SleepQueryService의 전체 수면 조회·중복 제거 결과로 알림을 계산한다.
- 상태: Resolved — b4638644 / 474b37b9. 최신 요청 검증, 스크롤 추세선 재계산, 밤 전체 수면 요약 적용. 관련 단위 테스트 43개(53회 실행) 통과.

### 9. [P2] 취소된 이전 기간 조회가 새 점수 차트를 덮어씀

- 위치: [DUNE/Presentation/Wellness/WellnessScoreDetailViewModel.swift:208](/Users/shanks/.codex/worktrees/e854/Health/DUNE/Presentation/Wellness/WellnessScoreDetailViewModel.swift:208)
- 문제·발생 조건: 기간을 빠르게 전환할 때 이전 HealthKit 요청이 늦게 돌아오면 chartData 및 하위 점수를 먼저 변경한 뒤 바깥 loadData에서 취소를 검사한다. 이전 범위와 새 selectedPeriod도 혼합될 수 있다.
- 근거·검증: 같은 파일:79 취소 검사와 208–225 상태 변경. TrainingReadinessDetailViewModel:196–217도 동일. 정적 호출 경로 확인; UI 경합 실행 재현은 미실시.
- 수정 방향: 요청 시작 시 period를 캡처하고 모든 상태 반영 전에 요청 ID/취소 상태를 검증한다.
- 상태: Resolved — b4638644 / 474b37b9. 최신 요청 검증, 스크롤 추세선 재계산, 밤 전체 수면 요약 적용. 관련 단위 테스트 43개(53회 실행) 통과.

### 10. [P2] 과거로 스크롤할 때 추세선이 갱신되지 않음

- 위치: [DUNE/Presentation/Wellness/WellnessScoreDetailViewModel.swift:19](/Users/shanks/.codex/worktrees/e854/Health/DUNE/Presentation/Wellness/WellnessScoreDetailViewModel.swift:19)
- 문제·발생 조건: 추세선을 켜고 과거 구간으로 이동해도 scrollPosition 변경이 추세선 재계산으로 이어지지 않는다. 이전 날짜에 선이 남거나 화면 밖으로 사라지며 토글을 다시 해야 갱신된다.
- 근거·검증: ConditionScore 및 TrainingReadiness에도 동일. computeTrendLine은 scrollPosition의 visible window만 사용. View에 별도 변경 observer 없음. UI 실행 재현은 미실시.
- 수정 방향: 스크롤 창 변경 시 추세선 캐시를 재계산한다.
- 상태: Resolved — b4638644 / 474b37b9. 최신 요청 검증, 스크롤 추세선 재계산, 밤 전체 수면 요약 적용. 관련 단위 테스트 43개(53회 실행) 통과.

### 11. [P2] 목표 미달 습관도 달성·연속 기록으로 계산

- 위치: [DUNE/Domain/UseCases/HabitStreakService.swift:52](/Users/shanks/.codex/worktrees/e854/Health/DUNE/Domain/UseCases/HabitStreakService.swift:52)
- 문제·발생 조건: 10회 목표에 매일 1회씩 3일 기록하면 totalCompletions=3, longestStreak=3이다. weeklyReport는 같은 입력을 달성 0회로 계산한다. LifeViewModel.streakDates도 값과 목표를 비교하지 않는다.
- 근거·검증: 실제 HabitAnalyticsService/HabitStreakService를 임시 Swift harness에서 실행하여 3/3/0 불일치 확인. LifeViewModel.swift:498 및 HabitManagementView.swift:83–84 호출.
- 수정 방향: 일별 합계가 goalValue를 충족한 날짜만 완료로 판정하는 공통 계산을 사용한다.
- 상태: Resolved — c960cc7d. 2026-09-20 수정 및 회귀 검증.

## 후속 수정 (2026-09-19)

- watch-001, watch-003, watch-004 해결. 현재 Open: P1 1건, P2 7건.
- 수정 커밋: `53484096`. 기존 위치 및 문제 설명은 최초 검토 시점 기준이다.

- 추가 수정: refresh-001 해결 (`4fa168f6`). 현재 Open: P1 0건, P2 7건.

- 추가 수정: chart-001, chart-002, sleep-001 해결 (`b4638644`, `474b37b9`). 현재 Open: P1 0건, P2 4건.

- 추가 수정 (2026-09-20): stats-001, background-001, watch-002, habit-001 해결. 최초 검토 11건 모두 해결, 현재 Open: P1 0건, P2 0건.
