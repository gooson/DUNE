---
tags: [habits, local-notifications, concurrency, lifecycle]
date: 2026-09-27
category: solution
status: draft
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

## Validation / Remaining Work

- 최종 iOS/포함 Watch 빌드 통과: `/tmp/habit-reminder-build-verified.log`.
- 알림 회귀 테스트 6개 작성: 빈도별 요청, 시간 경계, 보관, 직렬 실행, orphan 정리. **실행 통과는 미확인**.
- 전체 단위 테스트가 기존 DashboardViewModel Fallback 테스트에서 진행되지 않아 종료했다. 사용자의 후속 지시로 검증을 관련 테스트로 제한했다.
- 관련 4개 suite 실행은 시뮬레이터 destination 인식 실패(exit 70), 재시도는 런너 무응답으로 종료(exit 143). `/tmp/habit-reminder-targeted-tests.log`.
- UI 전체 실행은 사용자 범위 축소에 따라 종료했다. 생성/편집 picker 확인을 추가했으나 실행 결과는 미확인이다.
- Work 단계 SwiftUI/UX/종합 품질 검토에서 orphan 정리와 이벤트 병합을 반영했다. 정식 Review/Resolve/Ship 게이트는 미진입, PR/머지 없음.
- 후속 실행: HabitReminderSchedulerTests, HabitReminderOffsetTests, HabitCycleSnapshotTests, LifeViewModelTests 및 Life 생성/편집 UI 테스트만 검증한다.

## Prevention

UI에 노출되는 모든 빈도의 요청 생성을 테스트한다. 주기형 전용 nullable 값을 일반 습관의 필수 조건으로 사용하지 않는다. 예약 변경은 단일 queue에서 처리하고 앱 재시작과 원격 삭제도 대조한다. 이번 패턴은 문서로 기록하며 공통 규칙 변경은 하지 않는다.

## Lessons Learned

알림 시간 저장 성공과 운영체제 예약 성공은 별개다. 입력 UI뿐 아니라 생성되는 notification request를 검증해야 한다.
