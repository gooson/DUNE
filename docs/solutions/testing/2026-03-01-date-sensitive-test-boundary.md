---
tags: [unit-test, date-boundary, calendar, month-boundary, flaky-test, workout-streak]
category: testing
date: 2026-03-01
severity: minor
related_files: [DUNETests/WorkoutStreakServiceTests.swift, DUNE/Domain/UseCases/WorkoutStreakService.swift]
related_solutions: []
---

# Solution: 월 경계에서 실패하는 날짜 민감 테스트 수정

## Problem

### Symptoms

- `WorkoutStreakServiceTests` > "Monthly count only includes current month" 테스트가 매월 1일에 실패
- `(result.monthlyCount → 1) == 2` 에러 발생
- 2일~말일에는 정상 통과하는 flaky test

### Root Cause

테스트가 `workoutDay(daysAgo: 1)`로 "어제" 날짜를 생성하여 "이번 달" 운동으로 기대했지만, 매월 1일에 실행하면 `daysAgo: 1` = 전달 말일이 되어 `monthlyCount` 필터에서 제외됨.

```swift
// 3월 1일 실행 시:
// workoutDay(daysAgo: 0) = 3월 1일 ✓ (이번 달)
// workoutDay(daysAgo: 1) = 2월 28일 ✗ (지난 달!)
```

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNETests/WorkoutStreakServiceTests.swift` | 고정 참조 날짜(2026-06-15) 사용 | 월초 경계 문제 제거 |

### Key Code

```swift
// BEFORE: Date()-relative → 매월 1일 실패
let today = Date()
let thisMonth = [
    workoutDay(daysAgo: 0),
    workoutDay(daysAgo: 1),  // 월 1일에 전달로 넘어감
]
let result = WorkoutStreakService.calculate(from: thisMonth + [lastMonth], referenceDate: today)

// AFTER: 고정 mid-month 날짜 → 항상 안정
let refDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
let day1 = refDate
let day2 = calendar.date(byAdding: .day, value: -1, to: refDate)!
let result = WorkoutStreakService.calculate(from: thisMonth + [lastMonth], referenceDate: refDate)
```

## Prevention

### Checklist Addition

- [ ] 월별 집계 테스트에서 `daysAgo` 대신 고정 날짜 사용 여부 확인
- [ ] 날짜 경계 민감 테스트는 1일, 28일, 말일 시나리오 고려

### Pattern: 날짜 테스트 안정화

| 테스트 유형 | 권장 패턴 | 피해야 할 패턴 |
|------------|----------|---------------|
| 월별 집계 | 고정 mid-month `referenceDate` | `Date()` + `daysAgo` |
| 연도 경계 | 고정 mid-year 날짜 | `Date()` 기반 연도 계산 |
| streak 연속성 | `daysAgo` 허용 (월 경계 무관) | - |

## Lessons Learned

- `daysAgo` 헬퍼는 streak 테스트(연속일 판정)에는 적합하지만, **월/연 경계 필터링** 테스트에는 부적합
- 날짜 집계 테스트는 `referenceDate` 파라미터를 활용하여 고정 날짜로 제어하면 flaky test 방지 가능
- CI에서 매월 1일에만 실패하는 테스트는 발견이 어려우므로, 작성 시점에 경계 조건을 고려해야 함
