---
tags: [habits, local-notifications, concurrency, lifecycle]
date: 2026-09-27
category: solution
status: implemented
updated: 2026-11-06
---

# 습관 알림 예약 누락과 복구

## Problem

daily/weekly 습관은 cycleSnapshot이 nil인데 scheduler가 nextDueDate를 필수로 요구해 알림 시간을 설정해도 요청이 생성되지 않았다. 조기 완료에서는 취소와 재예약 Task가 경쟁했다. 기존 습관의 앱 진입·권한 허용 후 예약 복구 및 보관·삭제 정리도 없었다.

추가로 daily/weekly 반복 요청은 당일 완료 여부를 반영하지 않아 이미 체크한 습관도 알림 시간에 다시 울렸다. 전역 동기화도 interval 기록만 조회해 일반 습관의 완료·취소·CloudKit 변경을 관찰하지 못했다.

## Solution

- LifeViewModel은 화면과 동일한 `HabitLogResolution`으로 당일 합계를 해석하고 목표 달성 여부를 scheduler에 전달한다. 운동 자동 연동은 당일 `ExerciseRecord` 존재 여부도 반영한다. daily/weekly의 미완료 상태는 시각 기반 반복 요청을 사용한다. 완료 상태는 기존 반복 요청을 제거하고 내일부터 7일분의 날짜별 단발 요청을 예약한다. weekly는 요일 지정이 없는 목표 횟수이므로 당일 목표를 기준으로 억제한다. 로그는 한 번 합치고 빈도에 필요한 계산만 수행한다.
- interval은 기존 사전 offset과 예정일 단발 알림을 유지한다. 지난 시간과 첫 완료 전 미확정 예정일은 예약하지 않는다.
- 공용 MainActor queue가 제거→추가 순서를 직렬화하고 모델 값은 동기적으로 캡처한다.
- ContentView의 HabitReminderSyncView가 앱 진입·복귀·권한 허용·날짜 및 시간대 변경·저장 데이터 변경을 관찰한다. 200ms cancellable task로 연속 이벤트를 병합하고 최근 기록 및 목표값을 감시한다. 시간대 전환을 고려해 초기 조회일 이틀 전부터의 일반 기록을 포함하고 오래된 interval anchor는 날짜 제한 없이 함께 조회한다. 습관별로 기록을 묶어 예약 갱신에 전달한다.
- `HabitReminderSyncState`는 직전 입력과 비교해 일반 데이터 변경 시 해당 습관만 갱신한다. 최초 실행·앱 활성화·권한·날짜·시간대 변경은 전체를 다시 대조하고, 습관 목록 변경 시 orphan을 정리한다. 운동 기록의 날짜 변경·삭제도 자동 연동 완료 여부를 다시 계산한다. 폼 저장의 직접 예약 경로도 당일 운동 여부를 조회해 동일하게 전달한다.
- 예약 ID와 현재 습관 ID를 대조해 삭제된 습관 요청만 제거한다. 보관 습관은 빈 요청으로 기존 예약을 제거한다.
- 예약 공간은 다른 기능의 요청과 기존 반복·interval 기본 예약을 우선 보존한 뒤 총 64개 이내에서 가까운 rolling 알림부터 배분한다. 완료 습관의 임시 알림이 미완료 습관의 반복 예약을 밀어내지 않는다. 제거 단계의 pending snapshot을 재사용해 습관당 중복 조회도 피한다. 이 상한은 Apple의 기존 로컬 알림 제한을 보수적으로 적용한 앱 정책이다.

### 완료일 건너뛰기의 제약

`UNCalendarNotificationTrigger`의 시각 기반 반복 조건에는 특정 하루만 제외하는 시작일/예외일이 없다. 따라서 완료 후에는 최대 7일분을 미리 예약하고 다음 앱 활성화 또는 날짜 변경 이벤트에서 다시 계산한다. 앱을 7일 넘게 열지 않거나 예약 공간이 부족하면 이후 알림은 보장하지 않는다. 백그라운드 실행에 의존하는 무조건적인 재예약은 가정하지 않는다.

참고: [Apple의 calendar trigger 설명](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger), [기존 로컬 알림 예약 제한](https://developer.apple.com/documentation/uikit/uilocalnotification).

## Validation

- 2026-11-06 리뷰 수정 후 관련 단위 테스트 **68개 / 5개 suite 통과**: HabitReminderSchedulerTests, HabitReminderSyncStateTests, HabitReminderOffsetTests, HabitCycleSnapshotTests, LifeViewModelTests. 로그: `/tmp/habit-review-ship-unit-fixed.log`. 변경한 iOS 앱과 테스트 타깃 컴파일도 이 실행에서 통과했다.
- 추가 회귀 범위: daily/weekly 완료일 제외 및 연도 경계, 체크·횟수·시간형 완료, 원격 기록과 inverse 관계 지연, 기존 반복 요청 제거, tombstone 취소, 다음 날 반복 복원, 부분 목표와 중복 기록, 타 기능 및 기본 예약 보존, 당일 운동 자동 완료·취소, 습관별 변경 감지·삭제·강제 갱신, pending snapshot 조회 횟수.
- UI의 배치·문구·표시 상태·내비게이션 변경은 없으며 화면 캡처 갱신 대상은 없다. Watch 및 persistence schema 변경도 없다.

- 2026-10-05 최신 origin/main 통합 후 관련 단위 테스트 **53개 / 4개 suite 통과**: HabitReminderSchedulerTests, HabitReminderOffsetTests, HabitCycleSnapshotTests, LifeViewModelTests. 로그: `/tmp/habit-finish-unit.log`.
- 관련 UI 테스트 **3개 통과**: LifeSmokeTests.testHabitFormOpens, LifeSeededSmokeTests.testHabitActionsMenuOpensEditSheet, testHabitActionsMenuArchivesHabit. 로그: `/tmp/habit-finish-ui.log`.
- iOS 앱 빌드 및 최신 통합 소스의 테스트 빌드 통과. 이번 변경에 모델 스키마·Watch 코드 변경은 없다.
- 보안·데이터 정합성·아키텍처·성능·단순성 및 PR 통합 최종 리뷰: P1=0, P2=0, P3=0. 이전 orphan 정리·이벤트 병합 지적은 해결했다.
- 전체 범위 판정기는 App 파일 때문에 보수적으로 full을 출력하지만, 사용자 지시(필요한 테스트만)에 따라 실제 변경 소비자인 Life 생성·편집·보관과 scheduler/cycle/VM에 검증을 한정했다. 전체 단위/UI 테스트는 재실행하지 않았다.
- 이전 시뮬레이터 장애로 인한 미검증 상태는 위 성공 결과로 해소했다. 실기기의 권한·집중 모드에 따른 실제 수신은 이 테스트가 인증하지 않는다.

## 기존 구현의 Pipeline Proof (2026-10-05)

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

UI에 노출되는 모든 빈도의 요청 생성을 테스트한다. 주기형 전용 nullable 값을 일반 습관의 필수 조건으로 사용하지 않는다. 예약 변경은 단일 queue에서 처리하고 앱 재시작과 원격 삭제도 대조한다. 완료 판정은 화면과 알림에서 동일 resolver를 사용하고 완료·취소·다음 날의 실제 pending request를 테스트한다. 이번 패턴은 문서로 기록하며 공통 규칙 변경은 하지 않는다.

## Lessons Learned

알림 시간 저장 성공과 운영체제 예약 성공은 별개다. 입력 UI뿐 아니라 생성되는 notification request를 검증해야 한다.
