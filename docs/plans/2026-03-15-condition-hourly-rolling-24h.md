---
tags: [condition-score, hourly-chart, rolling-window, intraday, bug-fix]
date: 2026-03-15
category: plan
status: approved
---

# Plan: Condition Detail 일간 차트에 Rolling 24h Window 적용

## Problem

Condition Score Detail 화면에서 `일(Day)` 탭 선택 시:
1. **차트에 데이터 포인트가 거의 없음**: `loadHourlyData()`가 `startOfDay`~`now`만 사용하므로 새벽(03:01 등)에는 1-2개 점만 표시
2. **기간 요약이 의미 없음**: 1개 데이터 포인트로 평균=최소=최대=동일값 → 카드가 축소됨
3. **Hero sparkline과 불일치**: Hero sparkline은 `ScoreRefreshService`의 rolling 24h window를 사용하여 풍부한 데이터를 보여주지만, 상세 차트는 today-only

### Root Cause

`ConditionScoreDetailViewModel.loadHourlyData()` (line 298-346)이 `calendar.startOfDay(for: now)`부터 HRV 샘플을 필터링하여 시간별 점수를 계산. `scoreRefreshService`는 init에서 받지만 어디서도 사용하지 않음.

### 원인 커밋

`ab40552d fix(dashboard): stabilize intraday condition chart` — raw HRV 기반 재계산으로 전환 시 rolling window를 적용하지 않고 today-only로 구현.

## Solution

### Approach

`loadHourlyData()`의 HRV 샘플 필터 범위를 `startOfDay`→`now - 24h`로 변경. `executeIntraday`는 이미 evaluation date 기반이라 window 변경만으로 충분.

### Affected Files

| File | Change | Risk |
|------|--------|------|
| `DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift` | `loadHourlyData()` 필터 범위를 rolling 24h로 변경 | Low — 계산 로직 변경 없음, 입력 범위만 확장 |
| `DUNETests/ConditionScoreDetailViewModelTests.swift` | rolling 24h 테스트 추가 | None |

### Implementation Steps

#### Step 1: loadHourlyData() rolling 24h window

`startOfDay` 대신 `now - 24h`를 사용하여 HRV 샘플 필터링 범위 확장.

```swift
// Before
let startOfDay = calendar.startOfDay(for: now)
// ...
samples.filter { $0.date >= startOfDay && $0.date <= now }

// After
let twentyFourHoursAgo = now.addingTimeInterval(-24 * 60 * 60)
// ...
samples.filter { $0.date >= twentyFourHoursAgo && $0.date <= now }
```

scroll domain도 24h window에 맞게 조정.

#### Step 2: 테스트 업데이트

기존 day-period 테스트에 "3am에 어제 데이터도 포함되는지" 검증 추가.

### Test Strategy

- 시간을 새벽 3시로 고정한 mock으로 어제+오늘 HRV 데이터 제공 → chartData가 24h 분의 포인트를 생성하는지 확인
- summaryStats가 여러 포인트를 반영하는지 확인

### Risks & Edge Cases

- **자정 직후**: 어제 데이터 24시간치가 모두 포함되어 충분한 차트 표시
- **늦은 저녁**: 오늘 데이터만으로도 충분하므로 변화 없음
- **scroll domain**: `.day` period의 visible domain이 24h이므로 정확히 일치
