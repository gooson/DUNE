---
tags: [life, habits, recurring, weekly, schedule, day-boundary]
date: 2026-10-25
category: solution
status: draft
related_files:
  - DUNE/Presentation/Life/LifeViewModel.swift
  - DUNE/Presentation/Life/LifeView.swift
  - DUNETests/LifeViewModelTests.swift
  - DUNEUITests/Full/LifeRegressionTests.swift
---

# 오늘의 습관과 반복 일정 분리

## Problem

Life 히어로는 모든 수동 활성 습관을 오늘의 분모로 세었다. 주 N회 목표, 아직 예정일이 오지 않은 7일 주기, 미래 시작 일정도 매일 할 일처럼 표시됐다. 반복 습관은 지난 완료 후 다음 예정일까지 완료 상태가 유지되어 오늘 실제로 완료하지 않은 항목도 오늘의 분자에 포함됐다.

## Solution

`calculateProgresses`에서 수동 습관을 Today/Weekly/Upcoming으로 한 번 분류해 저장한다. Today는 daily, due/overdue interval, 실제 referenceDate에 완료한 interval이다. weekly는 목표 일수가 7이어도 날짜를 임의 배정하지 않고 Weekly에 둔다. 나머지 interval은 Upcoming에 둔다. 기존 모든 progress와 자동 연동 배열은 유지해 편집·기록·이력·자동 성취의 호출부를 보존한다.

반복 완료 여부는 `lastAction == .complete`와 `lastCompletedAt`의 당일 비교를 모두 만족해야 한다. 조기 완료하면 당일 Today에 남고, 다음 날 Upcoming으로 이동한다. 빈 오늘 안내는 전체 습관 없음과 구분한다.

각 그룹에 기존 시간대 렌더러와 카테고리 필터를 재사용한다. 선택 카테고리가 사라져도 All 버튼은 유지한다. calendar day/timezone 알림과 foreground 진입에서 동일 재계산 경로를 호출한다. 저장 스키마와 알림 정책, 과거 완료 추세는 변경하지 않는다.

## Prevention

- today, current cycle, weekly target의 기간을 boolean 이름과 테스트에서 구분한다.
- 분자·분모·목록은 같은 Today 배열을 사용한다.
- 고정 날짜로 due/overdue, 미래 시작, 첫 완료 대기, 당일 조기 완료와 다음 날 이동을 검증한다.
- 시간 의존 캐시는 기록 변경뿐 아니라 날짜·시간대·foreground 변경에도 갱신한다.
- 분류를 추가해도 기존 시간대·필터 해제·기록 액션 경로가 남아 있는지 확인한다.

## Verification

관련 단위 테스트는 3 suites / 45개 통과했다. UI 최초 실행은 2개 통과 / 새 fixture 1개 실패였고, fixture는 기존 폼 전용 스크롤 헬퍼로 수정했다. Xcode 결과 정리 정체로 exit 130 종료되어 수정 fixture와 실제 L01 캡처는 미검증이다. 이 문서는 구현 초안이며 merged 결과가 아니다. 상세 근거와 재개 조건은 `docs/reviews/2026-10-25-today-habit-schedule.md`에 기록한다. 테스트 미실행·환경 실패를 통과로 간주하지 않는다.

## Lessons Learned

활성 항목 목록을 오늘 해야 할 일의 분모로 재사용하면 주기와 실제 날짜의 의미가 섞인다. 분류 기준은 presentation 전에 계산하고, 시간 변화에 따른 무효화를 함께 구현해야 한다.
