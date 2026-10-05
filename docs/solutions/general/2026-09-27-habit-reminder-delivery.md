---
tags: [habits, local-notifications, concurrency, lifecycle]
date: 2026-09-27
category: solution
status: implemented
updated: 2026-10-05
---

# 습관 알림 예약 누락과 복구

## Problem

daily/weekly 습관은 cycleSnapshot이 nil인데 scheduler가 nextDueDate를 필수로 요구해 알림 시간을 설정해도 요청이 생성되지 않았다. 조기 완료에서는 취소와 재예약 Task가 경쟁했다. 기존 습관의 앱 진입·권한 허용 후 예약 복구 및 보관·삭제 정리도 없었다.

## Solution

- LifeViewModel의 HabitReminderScheduler가 daily/weekly에 시각 기반 반복 요청을 생성한다. weekly는 요일 지정이 없는 목표 횟수이므로 매일 알림을 사용한다. 완료 목표에 따른 당일 알림 억제는 이번 범위에 포함하지 않는다.
- interval은 기존 사전 offset과 예정일 단발 알림을 유지한다. 지난 시간과 첫 완료 전 미확정 예정일은 예약하지 않는다.
- 공용 MainActor queue가 제거→추가 순서를 직렬화하고 모델 값은 동기적으로 캡처한다.
- ContentView의 HabitReminderSyncView가 앱 진입·복귀·권한 허용·저장 데이터 변경을 관찰한다. 200ms cancellable task로 연속 이벤트를 병합하고 interval 기록만 조회한다. 오래된 anchor 보존을 위해 날짜 제한은 두지 않는다.
- 예약 ID와 현재 습관 ID를 대조해 삭제된 습관 요청만 제거한다. 보관 습관은 빈 요청으로 기존 예약을 제거한다.

## Validation

- 2026-10-05 최신 origin/main 통합 후 관련 단위 테스트 **53개 / 4개 suite 통과**: HabitReminderSchedulerTests, HabitReminderOffsetTests, HabitCycleSnapshotTests, LifeViewModelTests. 로그: `/tmp/habit-finish-unit.log`.
- 관련 UI 테스트 **3개 통과**: LifeSmokeTests.testHabitFormOpens, LifeSeededSmokeTests.testHabitActionsMenuOpensEditSheet, testHabitActionsMenuArchivesHabit. 로그: `/tmp/habit-finish-ui.log`.
- iOS 앱 빌드 및 최신 통합 소스의 테스트 빌드 통과. 이번 변경에 모델 스키마·Watch 코드 변경은 없다.
- 보안·데이터 정합성·아키텍처·성능·단순성 및 PR 통합 최종 리뷰: P1=0, P2=0, P3=0. 이전 orphan 정리·이벤트 병합 지적은 해결했다.
- 전체 범위 판정기는 App 파일 때문에 보수적으로 full을 출력하지만, 사용자 지시(필요한 테스트만)에 따라 실제 변경 소비자인 Life 생성·편집·보관과 scheduler/cycle/VM에 검증을 한정했다. 전체 단위/UI 테스트는 재실행하지 않았다.
- 이전 시뮬레이터 장애로 인한 미검증 상태는 위 성공 결과로 해소했다. 실기기의 권한·집중 모드에 따른 실제 수신은 이 테스트가 인증하지 않는다.

## Pipeline Proof

| 단계 | 결과 |
|------|------|
| Init / Plan | 작업 브랜치 및 영향 파일·경계 조건 계획 기록 |
| Work / UI | 구현 커밋, 관련 단위 53개 및 UI 3개 통과 |
| Review / Quality / Resolve | 최종 diff 리뷰 5관점+통합, 미해결 finding 0건 |
| Compound / Pre-Ship | 최종 구현 문서 동기화, 최신 main 통합, clean 상태 확인 |
| Ship | 검증 완료 커밋을 PR로 생성하고 GitHub merge 전략으로 통합 |

## Change Verification Guide

Life에서 매일 또는 매주 습관의 알림 시간을 가까운 미래로 지정한 뒤 저장한다. 시스템 알림을 허용하고 앱을 백그라운드로 보낸 뒤 수신을 확인한다. 기존 습관은 앱을 다시 열면 예약이 복구되며, 보관한 습관의 예정 알림은 제거된다.

## Prevention

UI에 노출되는 모든 빈도의 요청 생성을 테스트한다. 주기형 전용 nullable 값을 일반 습관의 필수 조건으로 사용하지 않는다. 예약 변경은 단일 queue에서 처리하고 앱 재시작과 원격 삭제도 대조한다. 이번 패턴은 문서로 기록하며 공통 규칙 변경은 하지 않는다.

## Lessons Learned

알림 시간 저장 성공과 운영체제 예약 성공은 별개다. 입력 UI뿐 아니라 생성되는 notification request를 검증해야 한다.
