---
tags: [habits, notifications, concurrency]
date: 2026-09-27
category: plan
status: implemented
updated: 2026-10-05
---

# 습관 알림 예약 복구

## Context

daily/weekly 습관은 cycleSnapshot이 nil이므로 시간 설정이 있어도 예약되지 않는다. 조기 완료에서는 취소와 예약 Task가 경쟁한다. 기존 습관의 복구 및 보관/복원 시 예약 일관성도 점검한다.

## Approach

daily/weekly는 지정 요일이 없는 목표 빈도이므로 설정 시각의 매일 반복 reminder를 사용한다. interval은 기존 예정일/사전 알림 의미를 유지한다. 예약 변경을 직렬화하고 저장된 기존 습관도 앱 진입/복귀 시 복구한다. 권한은 기존 앱 시작 권한 흐름을 유지하고 허용 완료 시 재예약한다.

## Affected Files

| File | Change |
|------|--------|
| DUNE/Presentation/Life/LifeViewModel.swift | 빈도별 요청 생성 및 예약 순서 보장 |
| DUNE/Presentation/Life/LifeView.swift | 중복 취소 제거, 기존 예약 복구 |
| DUNE/Presentation/Life/HabitReminderSyncView.swift | 앱 전역 습관 변경 관찰 및 orphan 정리 |
| DUNE/App/ContentView.swift, DUNE/App/DUNEApp.swift | 전역 관찰 및 권한 완료 연결 |
| DUNETests/HabitReminderSchedulerTests.swift | 요청 내용, 날짜, 순서 회귀 테스트 |
| DUNEUITests/Smoke/LifeSmokeTests.swift, DUNEUITests/Helpers/UITestHelpers.swift | 알림 시간 선택기 생성/편집 UI 검증 |
| DUNE/DUNE.xcodeproj/project.pbxproj | 신규 Swift 파일 자동 등록 |

## Implementation Steps

1. 순수 요청 생성 경로로 daily/weekly 반복 및 interval 단발 예약을 구분하고 테스트한다.
2. 동일 습관의 취소/예약 순서를 보장하고 기존 습관 복구와 보관 처리를 연결한다.
3. 빌드, 관련 단위 테스트 및 전체 UI 회귀를 실행하고 리뷰 결과를 반영한다.

## Edge Cases / Risks

- firstCompletion 이전 interval은 알림 없음 유지.
- 지난 시각/예정일에 즉시 알림을 몰아 보내지 않는다.
- 주간 목표는 특정 요일 선택과 다르므로 임의 요일 배정 금지.
- 보관/삭제, 빠른 연속 편집, 시간대 변경 시 stale 요청 방지.
- 실제 기기 알림 권한·집중 모드·요약 설정은 코드만으로 확인할 수 없다.

## Testing Strategy

Swift Testing으로 daily/weekly 요청 존재 및 repeats, interval 미래/과거 경계, 보관 제거, 빠른 연속 작업 순서를 검증한다. scripts/build-ios.sh와 scripts/test-unit.sh 및 scripts/test-ui.sh로 검증한다. 실기기 사용자 데이터 접근 없이 코드 결함과 기기별 전달 상태를 구분한다.

## Research

기존 life-recurring-checklist-reminders 및 habit-early-completion 문서, 관련 brainstorm/plan/todos를 검색했다. Apple Scheduling a notification locally 문서의 calendar trigger 반복 계약을 확인했다.
