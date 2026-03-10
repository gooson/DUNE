---
tags: [sleep, chart, off-by-one, fetchDailySleepDurations, dateComponents]
date: 2026-03-10
category: solution
status: implemented
---

# 수면 주간 차트 오늘 데이터 누락 (Off-by-One)

## Problem

오늘 수면 기록(7시간 30분)이 존재하지만 주간 차트에서 0 min으로 표시됨.
`fillDateGaps`가 누락된 날짜를 0으로 채워서 summary stats(평균/최소/최대)도 왜곡.

## Root Cause

`SleepQueryService.fetchDailySleepDurations(start:end:)` 에서:

```swift
let dayCount = calendar.dateComponents([.day], from: start, to: end).day ?? 7
for dayOffset in 0..<dayCount {  // exclusive — 마지막 날 누락
```

- `end = Date()` (예: 3/10 12:16)는 자정이 아님
- `dateComponents([.day])` = 완전한 24시간 단위만 카운트 (3/4 00:00 → 3/10 12:16 = 6일)
- `0..<6` → offset 0~5 = 3/4~3/9, 오늘(3/10) 제외

## Solution

```swift
// Before
for dayOffset in 0..<dayCount {

// After
for dayOffset in 0...dayCount {
```

`0...dayCount`는 end 날짜가 속한 날까지 포함.
미래 날짜가 추가로 쿼리되더라도 `fetchSleepStages`가 빈 배열 반환 → `guard !sleepStages.isEmpty` → nil → 결과에서 자동 제외.

## Prevention

- `dateComponents([.day])` 기반 일수 계산 후 for 루프에서 exclusive range(`0..<`)를 사용하면 end 날짜가 자정이 아닌 경우 마지막 날이 누락됨
- 날짜 범위 반복 시: `0...dayCount` (inclusive) 사용하거나, end를 `endOfDay`로 올림 후 exclusive 사용
- 방어적으로 한 번 더 쿼리하는 비용은 무시할 수 있음 (빈 데이터 반환 시 자동 필터)

## Affected Components

| 컴포넌트 | 영향 |
|---------|------|
| 주간 수면 차트 | 오늘 0 min → 실제 값 표시 |
| Summary stats (평균/최소/최대) | 0 포함 왜곡 → 정확한 값 |
| `loadDeficitAnalysis` | 이미 `end = today + 1 day` 사용 → 영향 없음 |
