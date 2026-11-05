---
tags: [detail-redesign, habits, l09]
date: 2026-11-06
category: plan
status: approved
---

# L09 지난 날짜 습관 기록 개편

[통합 계획](2026-11-06-detail-redesign-habit-management-batch03.md)의 보존·검증·머지 기준을 따른다. [전용 배치](../design/layout-map/life-habit-l09.html)와 테마를 앱보다 먼저 등록했다.

앱 대상: `DUNE/Presentation/Life/HabitPastRecordSheet.swift`. 기존 데이터·유효성·저장 동작은 유지하고 히어로와 원래 아이콘을 강조한다.

정상 네 프로필: `LifeFlowUITests/testOpeningPastRecordMenuDoesNotMutateToday()`, `LifeFlowUITests/testPastReadTotalReplacesYesterdayAndLeavesTodayUnchanged()`. 접힌 Duo MAX: `LifeFlowUITests/testPastRecordKindsAtMaximumAccessibilitySize()`. 현재 SDK·실제 PNG/AX·품질 게이트는 미완료이며 통합 실행의 해당 메서드만 이 화면 증거로 사용한다.
