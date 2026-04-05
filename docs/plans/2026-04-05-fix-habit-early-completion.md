---
tags: [life-tab, habit, cycle, interval, early-completion, bug-fix]
date: 2026-04-05
category: plan
status: draft
---

# Plan: 습관 조기 완료(early completion) 불가 버그 수정

## Problem

interval 기반 습관의 다음 예정일(nextDueDate)이 내일(4월 6일)인데 오늘(4월 5일) 체크할 수 없음.

### Root Cause

`LifeViewModel.makeCycleSnapshot()`에서 `canComplete` 판정 로직:

```swift
let isCompletedThisCycle = lastAction == .complete && !isDue
let canComplete = !isCompletedThisCycle
```

`isDue = today >= dueDate`이므로, 예정일 전날(`today < dueDate`)이면 `!isDue = true`.
이전 사이클에서 complete 했으면 `lastAction == .complete`이 유지되므로,
`isCompletedThisCycle = true`가 되어 `canComplete = false` → 조기 완료 불가.

**의도**: "현재 사이클에서 이미 완료했으면 중복 체크 방지"
**실제 동작**: "이전 사이클 완료 후 다음 예정일 전까지 모든 날에 완료 불가"

### UI 흐름

1. `HabitRowView.isToggleDisabled` = `!progress.canCompleteCycle` → true (비활성)
2. `LifeView.toggleCheck()` 내 `guard progress.canCompleteCycle` → early return

## Solution

`isCompletedThisCycle` 판정을 **같은 날 완료 여부**로 변경:

```swift
let isCompletedToday: Bool
if lastAction == .complete, let completedAt = lastCompletedAt {
    isCompletedToday = calendar.isDate(completedAt, inSameDayAs: today)
} else {
    isCompletedToday = false
}
let canComplete = !isCompletedToday
```

### 시나리오 검증

| 시나리오 | 기존 | 수정 후 | 기대 |
|---------|------|---------|------|
| 3/30 완료, 4/5 오늘, 4/6 예정 | canComplete=false | canComplete=true | 조기 완료 허용 |
| 4/5 오늘 완료 직후 재탭 | canComplete=false | canComplete=false | 당일 중복 방지 |
| 첫 사이클, 미완료 | canComplete=true | canComplete=true | 정상 |
| 4/6 예정일 당일, 4/5 완료 | canComplete=true | canComplete=true | 예정일 완료 허용 |
| 4/6 예정일 당일, 4/6 완료 | canComplete=false | canComplete=false | 당일 중복 방지 |

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Presentation/Life/LifeViewModel.swift` | `makeCycleSnapshot()` 내 `isCompletedThisCycle` → 같은 날 체크로 변경 |
| `DUNE/DUNETests/` (새 파일 또는 기존) | 조기 완료 시나리오 유닛 테스트 |

## Implementation Steps

1. `LifeViewModel.makeCycleSnapshot()` 수정 — `isCompletedThisCycle` 로직 변경
2. 유닛 테스트 작성 — 위 5개 시나리오 검증

## Test Strategy

- `makeCycleSnapshot()`이 internal 메서드이므로 `cycleSnapshot(for:referenceDate:)` 경유 테스트
- Mock `HabitDefinition` + `HabitLog` 설정으로 각 시나리오 재현
- 기존 `LifeViewModelTests.swift` 확인 후 테스트 추가

## Risks & Edge Cases

- **snooze 후 조기 완료**: lastAction이 .snooze일 때는 isCompletedToday가 false → canComplete=true (정상)
- **skip 후 같은 날 완료**: lastAction이 .skip → isCompletedToday=false → canComplete=true (정상 — skip 후 완료 허용)
- **같은 날 skip → complete → 재탭**: lastAction=.complete, completedAt=today → canComplete=false (중복 방지)
