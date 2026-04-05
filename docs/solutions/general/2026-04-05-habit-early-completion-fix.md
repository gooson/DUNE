---
tags: [life-tab, habit, interval, cycle, canComplete, early-completion, boolean-logic]
category: general
date: 2026-04-05
severity: important
related_files:
  - DUNE/Presentation/Life/LifeViewModel.swift
  - DUNETests/HabitCycleSnapshotTests.swift
  - DUNETests/LifeViewModelTests.swift
---

# Solution: Interval Habit Early Completion Blocked Before Due Date

## Problem

Interval 습관의 다음 예정일이 내일(4/6)인데 오늘(4/5) 체크할 수 없었다.

### Symptoms

- 이전 사이클에서 완료된 interval 습관이 다음 예정일 전까지 탭 불가 상태로 표시됨
- `HabitRowView`에서 `isToggleDisabled = !progress.canCompleteCycle` → true

### Root Cause

`LifeViewModel.makeCycleSnapshot()`의 `canComplete` 판정 로직:

```swift
let isCompletedThisCycle = lastAction == .complete && !isDue
let canComplete = !isCompletedThisCycle
```

`!isDue`는 "예정일이 아직 안 왔다"를 의미. 이전 사이클에서 `lastAction == .complete`이 유지되므로, 예정일 전날까지 `canComplete = false`가 되어 조기 완료가 차단됨.

**의도**: 같은 사이클 내 중복 완료 방지
**실제**: 예정일 전까지 모든 날에 완료 불가

## Solution

`isCompletedThisCycle`을 **같은 날 완료 여부** 체크로 변경:

```swift
let isCompletedToday: Bool
if lastAction == .complete, let completedAt = lastCompletedAt {
    isCompletedToday = calendar.isDate(completedAt, inSameDayAs: today)
} else {
    isCompletedToday = false
}
let canComplete = !isCompletedToday
```

`lastCompletedAt`은 이미 `calendarStartOfDay(log.date)`로 정규화된 값이므로 `isDate(_:inSameDayAs:)` 비교가 정확.

## Prevention

- cycle-based boolean guard를 작성할 때 "어떤 날짜에 대해 true인가"를 명시적으로 테스트로 고정
- interval 습관 로직 변경 시 최소 5개 시나리오 검증: 조기 완료, 당일 중복, 첫 사이클, 예정일 당일, 예정일 같은 날 완료

## Lessons Learned

`lastAction == .complete && !isDue`처럼 "최신 액션 + 시간 조건" 조합으로 상태를 추론하면 의도와 다른 시간대에서 잘못된 결과가 나올 수 있다. 실제 이벤트 날짜(`lastCompletedAt`)를 직접 비교하는 것이 더 정확하고 의도를 명확히 전달한다.
