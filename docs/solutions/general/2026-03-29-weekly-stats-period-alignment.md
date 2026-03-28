---
tags: [date-range, period, weekly-stats, activity, off-by-one, startOfDay]
date: 2026-03-29
category: solution
status: implemented
---

# Weekly Stats Period Alignment (Card vs Detail)

## Problem

Activity 탭의 "이번 주" 카드와 상세 화면(WeeklyStatsDetailView)의 수치가 다르게 표시됨.

**증상**: 카드에는 7일치 데이터가 표시되지만, 상세 화면에서는 6일치만 집계됨.

**근본 원인**: 두 곳이 서로 다른 날짜 범위 계산을 사용:
- 카드 (`ActivityViewModel.rebuildWeeklyStats`): `Date() - 7일` (rolling time-based)
- 상세 (`TrainingVolumeAnalysisService.analyze`): `startOfDay(today) - (days - 1)` = 6일

`-(days - 1)`는 "7 calendar days including today" 의미이지만, 카드는 `Date() - 7 days`로 7일 전부터 집계하여 하루 차이 발생.

## Solution

1. `TrainingVolumeAnalysisService.analyze`: `-(days - 1)` → `-days` 변경
2. `ActivityViewModel.rebuildWeeklyStats`: `Date()` → `startOfDay(for: Date())` 기반으로 정렬
3. `partitionSnapshotsByWeek`: 동일 `startOfDay` 기반으로 통일
4. Previous period filter: `<= previousEnd` → `< currentStart` (boundary gap 제거)

## Prevention

- **동일 metric의 summary/detail은 같은 날짜 범위 계산을 사용해야 함** (Correction #213 참조)
- 날짜 범위는 `startOfDay` 기반으로 통일: rolling `Date()` 사용 지양
- Previous period 상한은 `< currentStart` (exclusive)로 통일하여 boundary gap 방지
- 날짜 범위 변경 시 `dailyBreakdown.count` 등 파생 테스트도 함께 검증

## Lessons Learned

- `-(days - 1)` vs `-days` 같은 off-by-one은 각각 다른 "N일"의 의미를 내포하므로, 주석으로 semantic을 명시해야 함
- Summary 카드와 detail 화면이 독립 계산을 할 때 기간 불일치가 가장 흔한 버그 원인
