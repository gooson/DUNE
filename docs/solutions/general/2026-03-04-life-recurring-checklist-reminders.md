---
tags: [life-tab, recurring-checklist, local-notification, interval-schedule, skip-snooze, history]
category: general
date: 2026-03-04
severity: important
related_files:
  - DUNE/Presentation/Life/LifeViewModel.swift
  - DUNE/Presentation/Life/LifeView.swift
  - DUNE/Presentation/Life/HabitRowView.swift
  - DUNE/Data/Persistence/Models/HabitDefinition.swift
  - DUNE/Domain/Models/HabitType.swift
related_solutions:
  - docs/solutions/architecture/2026-02-28-habit-tab-implementation-patterns.md
---

# Solution: 라이프 탭 주기 체크리스트 + 다음 주기 알림

## Problem

Life 탭은 daily/weekly 목표 달성 중심 구조라서, "완료일 기준으로 다음 주기 재계산"되는 생활 체크리스트(예: 7일/30일/90일) 요구를 직접 처리하지 못했다.

### Symptoms

- 완료 후 다음 주기를 자동 계산해 알림하는 흐름이 없음
- 미루기/건너뛰기 같은 주기 액션을 저장할 구조가 없음
- 주기 액션 히스토리를 확인할 수 없음

### Root Cause

`HabitFrequency`가 daily/weekly만 지원하고, `HabitLog`가 단순 완료 기록 용도로만 사용되어 주기형 상태(다음 예정일, skip/snooze)를 계산할 수 없었다.

## Solution

기존 SwiftData 모델을 유지하면서 interval 주기를 확장하고, `HabitLog.memo` marker로 skip/snooze를 표현해 상태를 계산했다.  
완료/미루기/건너뛰기 후 다음 예정일을 재계산하고, 3일 전/1일 전/당일 알림을 재예약하도록 연결했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Models/HabitType.swift` | `HabitFrequency.interval(days:)`, cycle 상태 필드 추가 | 주기형 체크리스트 표현 |
| `DUNE/Data/Persistence/Models/HabitDefinition.swift` | `frequencyTypeRaw == "interval"` 매핑 추가 | persistence 확장(마이그레이션 최소화) |
| `DUNE/Presentation/Life/LifeViewModel.swift` | cycle snapshot/history/snooze/skip/notification scheduler 추가 | 완료일 기준 next due 계산 + 다중 알림 |
| `DUNE/Presentation/Life/LifeView.swift` | cycle 완료/미루기/건너뛰기 + 히스토리 시트 연결 | 사용자 액션 플로우 제공 |
| `DUNE/Presentation/Life/HabitFormSheet.swift` | recurring(interval day) 입력 UI 추가 | 7/30/90일 등 주기 설정 지원 |
| `DUNE/Presentation/Life/HabitRowView.swift` | due/overdue/next due 상태 표시 | 주기 진행 상태 가시화 |
| `DUNETests/*` | interval/streak/cycle snapshot/history 테스트 추가 | 회귀 방지 |

### Key Code

```swift
private func makeCycleSnapshot(
    for habit: HabitDefinition,
    referenceDate: Date,
    calendar: Calendar
) -> HabitCycleSnapshot? {
    guard let intervalDays = habit.frequency.intervalDays else { return nil }
    // anchor = latest completion/skip, due = anchor + interval, snooze overrides due
    ...
}
```

## Prevention

### Checklist Addition

- [ ] 주기형 기능은 `completedAt`이 아닌 `완료 액션 날짜(anchor)` 기준으로 next due를 계산했는지 확인
- [ ] 알림 재예약 시 기존 pending request를 habit ID prefix로 선삭제하는지 확인
- [ ] skip/snooze 같은 비완료 액션도 히스토리에 기록되는지 확인

### Rule Addition (if applicable)

현재는 기존 규칙 내에서 처리 가능하며, 별도 신규 rule 추가는 보류.

## Lessons Learned

- SwiftData 모델을 추가하지 않고도 memo marker + 계산 스냅샷으로 주기형 상태를 확장할 수 있다.
- 주기형 체크리스트는 "오늘 완료 여부"보다 "다음 예정일 상태"가 핵심이므로 Row/UI 설계도 그 축으로 바꾸어야 한다.
