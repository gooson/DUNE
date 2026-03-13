---
tags: [sparkline, rolling-window, hourly-tracking, chart, ux, time-series]
date: 2026-03-14
category: solution
status: implemented
---

# Sparkline Rolling 24-Hour Window

## Problem

Sparkline이 `startOfDay` 이후 데이터만 표시하여 새벽(01:17 등) 시점에 데이터 포인트 1-2개로 의미있는 추세선을 그릴 수 없었음. 사용자가 하루 시작 시 어제→오늘의 연속적인 컨디션 흐름을 확인 불가.

### Root Cause

`loadTodaySparklines()`가 `Calendar.startOfDay(for: Date())`부터 fetch하여, 자정 직후에는 거의 빈 데이터를 반환.

## Solution

### Approach: Rolling 24-Hour Window

`startOfDay` 대신 `now - 24h`부터 fetch하여 항상 최대 24시간의 데이터를 확보.

### Key Changes

1. **Fetch 범위**: `startOfDay` → `now.addingTimeInterval(-24 * 60 * 60)` + `fetchLimit: 48`
2. **Sequential Index**: `HourlyPoint`에 `index: Int` 추가. Clock hour가 자정에서 wrap-around(22→23→0→1)하면 chart의 x축 순서가 깨지므로, 시간순 배열의 `enumerated()` index를 chart x값으로 사용.
3. **`includesYesterday` Flag**: 라벨을 "Today" vs "24h"로 동적 전환.
4. **O(1) Yesterday Detection**: 스냅샷이 date 정렬이므로 `snapshots.first?.date < startOfDay`로 판정 (O(N) `contains` 불필요).

### Chart X-Axis

```
Before: .chartXScale(domain: 0...23)        // clock hour, wraps at midnight
After:  .chartXScale(domain: 0...count-1)   // sequential index, always ordered
```

## Prevention

### 시계열 차트에서 시간 wrap-around

- Clock hour (0-23)를 차트 x축으로 직접 사용하면 midnight 경계에서 순서가 깨짐
- 대안: sequential index, Unix timestamp offset, 또는 `Date` 타입 직접 사용
- `chartXAxis(.hidden)`이면 어차피 시각적 차이 없으므로 sequential index가 가장 단순

### Sorted 데이터에서 조건 검사

- 정렬된 배열의 첫/마지막 원소로 범위 검사 가능 → O(N) `contains` 대신 O(1) first/last 활용

## Related Files

| 파일 | 역할 |
|------|------|
| `Data/Services/ScoreRefreshService.swift` | 24h fetch + sequential index 빌드 |
| `Domain/Models/HourlySparklineData.swift` | `index`, `includesYesterday` 추가 |
| `Presentation/Shared/Components/HourlySparklineView.swift` | 동적 x-axis domain |
| `Presentation/Dashboard/Components/ConditionHeroView.swift` | Today/24h 라벨 |
| `Presentation/Shared/Components/HeroScoreCard.swift` | Today/24h 라벨 |

## Lessons Learned

1. Sparkline처럼 "오늘"만 보여주는 UI는 하루 시작 시 비어 보이는 cold start 문제를 항상 고려해야 함
2. Chart x축에 clock hour를 직접 사용하면 midnight 경계에서 문제 발생 — hidden axis라면 sequential index가 최선
