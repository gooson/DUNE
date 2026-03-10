---
tags: [sleep, chart, fetchDailySleepDurations, off-by-one, weekly]
date: 2026-03-10
category: plan
status: approved
---

# Plan: 수면 주간 차트 오늘 데이터 누락 수정

## Problem

오늘 7시간 30분 수면 기록이 있지만 주간 차트에서 0 min으로 표시됨.

## Root Cause

`SleepQueryService.fetchDailySleepDurations(start:end:)`의 off-by-one 버그.

```swift
let dayCount = calendar.dateComponents([.day], from: start, to: end).day ?? 7
for dayOffset in 0..<dayCount {  // exclusive range — 마지막 날 누락
```

- `end = Date()` (예: 3/10 12:16)는 자정이 아님
- `dateComponents([.day])` = 완전한 일수만 카운트
- `0..<dayCount` → 마지막 날(오늘) 제외
- `fillDateGaps`가 빠진 날을 0으로 채움

## Affected Files

| File | Change | Impact |
|------|--------|--------|
| `DUNE/Data/HealthKit/SleepQueryService.swift` | `0..<dayCount` → `0...dayCount` | 핵심 수정 |
| `DUNE/DUNETests/SleepQueryServiceTests.swift` | 기존 테스트 확인 + 엣지 케이스 추가 | 검증 |

## Implementation Steps

### Step 1: `fetchDailySleepDurations` 수정

Line 265: `for dayOffset in 0..<dayCount` → `for dayOffset in 0...dayCount`

**이유**: `0...dayCount`는 end 날짜가 속한 날까지 포함. 미래 날짜 쿼리는 빈 데이터 반환 (harmless).

### Step 2: 테스트 확인

기존 `SleepQueryServiceTests`의 interval 헬퍼 테스트는 영향 없음.
새 테스트: 오늘 날짜가 포함되는 시나리오 (mock 기반).

## Test Strategy

- `fetchDailySleepDurations`의 dayCount 계산이 오늘을 포함하는지 확인
- 경계 조건: start=end 같은 날, end가 자정인 경우

## Risks / Edge Cases

| Risk | Mitigation |
|------|-----------|
| 미래 날짜 쿼리 | `fetchSleepStages`가 빈 배열 반환 → TaskGroup에서 nil → 결과에서 제외 |
| `loadDeficitAnalysis`의 end=today+1 | 기존에도 동작. `0...dayCount`면 1일 더 쿼리하지만 harmless |
| 다른 서비스도 같은 패턴 사용? | Steps/Exercise는 HealthKit collection query 사용, 이 패턴 미사용 |

## Summary Stats Impact

차트 데이터에 오늘이 포함되면 `currentPeriodValues()`도 오늘 값 포함 → 평균/최소/최대 정확해짐.
