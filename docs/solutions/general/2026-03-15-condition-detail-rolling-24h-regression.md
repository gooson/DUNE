---
tags: [condition-score, rolling-window, intraday, regression, hourly-chart]
date: 2026-03-15
category: general
status: implemented
---

# Condition Detail: Day Period Rolling 24h Regression

## Problem

Condition Score 상세 화면에서 "일(Day)" 기간 선택 시 차트에 데이터가 1-2개만 표시됨.
특히 새벽(예: 03:00 AM)에는 당일 HRV 샘플이 거의 없어 의미 있는 차트가 불가능.

## Root Cause

`ab40552d` 커밋에서 `HourlyScoreSnapshot` → 원시 HRV 재계산 방식으로 전환하면서
`loadHourlyData()`의 필터가 `calendar.startOfDay(for: now)` 기준으로 설정됨.

- 새벽 시간대: `startOfDay`부터 `now`까지 시간이 짧아 샘플 부족
- `ScoreRefreshService`(히어로 카드 스파크라인)는 이미 rolling 24h를 사용 중이었으나, 상세 화면에는 미적용

## Solution

1. **Rolling 24h 필터**: `now - 24h` ~ `now` 범위로 HRV 샘플 필터 변경
2. **Scroll position**: Day 기간 선택 시 `scrollPosition = now - 24h`로 설정하여 어제 데이터가 즉시 보이도록
3. **Fetch 범위 확장**: `conditionWindowDays + 2`로 변경 (rolling 24h가 두 캘린더 날에 걸침)
4. **Range label**: 두 캘린더 날에 걸치는 경우 범위 표시 (예: "Mar 14, Fri – Mar 15, Sat")

## Key Files

| File | Change |
|------|--------|
| `ConditionScoreDetailViewModel.swift` | `loadHourlyData()` rolling 24h 필터, `resetScrollPosition()` 24h offset |
| `TimePeriod+View.swift` | `visibleRangeLabel` day 기간 범위 표시 |
| `ConditionScoreDetailViewModelTests.swift` | Rolling 24h 테스트 2건 추가 (noon, 3am 시나리오) |

## Prevention

- **Detail 화면과 Hero 카드의 시간 윈도우를 일치시킬 것**: `ScoreRefreshService`가 rolling 24h를 사용하면 detail도 동일해야 함
- **새벽 시간대 테스트 필수**: 시간 기반 필터 변경 시 03:00 AM 등 경계 케이스 테스트 포함
- `rollingWindowSeconds` 상수를 통해 중복 매직 넘버 방지
