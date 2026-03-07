---
tags: [life-tab, habit, swiftdata, query, relationship-sync, regression-test]
category: general
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Life/LifeView.swift
  - DUNE/Presentation/Life/HabitRowView.swift
  - DUNETests/LifeViewModelTests.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
related_solutions:
  - docs/solutions/architecture/2026-02-28-habit-tab-implementation-patterns.md
  - docs/solutions/architecture/2026-03-04-life-tab-ux-consistency-sectiongroup-refresh.md
---

# Solution: Life Habit Toggle Immediate Sync

## Problem

Life 탭 `My Habits`에서 체크형 습관을 눌러도 완료 상태와 hero progress가 즉시 바뀌지 않았다.

### Symptoms

- check habit을 탭해도 row 아이콘이 그대로 남아 있는 경우가 있었다.
- hero progress가 토글 직후 갱신되지 않고 새로고침이나 화면 재진입 후에만 바뀌었다.
- count/duration/interval action도 같은 구조라 SwiftData 반영 타이밍에 따라 비슷한 지연 위험이 있었다.

### Root Cause

`HabitListQueryView`는 `HabitDefinition`만 관찰하면서 토글 직후 `habit.logs` relationship을 다시 읽어 진행률을 계산하고 있었다. 하지만 새 `HabitLog`를 insert/delete한 직후에는 inverse relationship 컬렉션이 같은 UI 이벤트 안에서 아직 최신 상태가 아닐 수 있어, `recalculate()`가 stale relationship을 기준으로 실행되었다.

## Solution

Life 탭에서 habit log를 별도 `@Query`로 관찰하고, row action에서는 relationship 컬렉션을 즉시 동기화한 뒤 `modelContext` insert/delete를 수행하도록 바꿨다. 동시에 이 sync 로직을 `LifeHabitLogSync`로 분리해 unit test로 고정했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Life/LifeView.swift` | `HabitLog` query 추가 + `LifeHabitLogSync` 도입 + toggle/update/cycle action을 sync helper 경유로 통일 | 토글 직후 stale relationship 참조 방지 |
| `DUNE/Presentation/Life/LifeView.swift` | `habitLogSignature` 기반 `recalculate()` trigger 추가 | 외부 log 변경도 Life progress 재계산에 반영 |
| `DUNE/Presentation/Life/LifeView.swift` | habits section accessibility identifier 추가 | Life UI regression selector 고정 |
| `DUNE/Presentation/Life/HabitRowView.swift` | check/cycle toggle accessibility identifier 추가 | habit toggle UI selector 확보 |
| `DUNETests/LifeViewModelTests.swift` | `LifeHabitLogSync` insert/delete 테스트 추가 | immediate sync 회귀 방지 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | title fallback tab navigation + Life AXID 추가 | Life seeded smoke에서 탭 진입 경로 강화 |

### Key Code

```swift
enum LifeHabitLogSync {
    static func insert(_ log: HabitLog, into habit: HabitDefinition) {
        if habit.logs == nil {
            habit.logs = []
        }
        log.habitDefinition = habit
        if habit.logs?.contains(where: { $0.id == log.id }) != true {
            habit.logs?.append(log)
        }
    }
}
```

```swift
private func insertLog(_ log: HabitLog, into habit: HabitDefinition) {
    LifeHabitLogSync.insert(log, into: habit)
    modelContext.insert(log)
}
```

## Prevention

### Checklist Addition

- [ ] SwiftData relationship을 mutate한 직후 파생 UI 상태를 다시 계산한다면, inverse collection이 즉시 최신인지 확인한다.
- [ ] `@Query` observation 대상과 실제 파생 상태 계산 입력이 어긋나지 않는지 리뷰한다.
- [ ] UI bug를 고칠 때 selector를 함께 고정해 이후 smoke/E2E 회귀 테스트를 쉽게 만든다.

### Rule Addition (if applicable)

기존 `swiftdata-cloudkit.md`, `testing-required.md` 범위로 커버 가능해서 새 rule 추가는 보류했다.

## Lessons Learned

SwiftData에서는 `modelContext.insert/delete` 자체보다, 그 직후 어떤 컬렉션을 기준으로 UI를 재계산하는지가 더 중요하다. 특히 relationship inverse를 즉시 신뢰하는 코드는 화면상 "눌렸는데 안 바뀌는" 버그로 보이기 쉬우므로, action 경로의 로컬 동기화와 query observation 범위를 함께 설계해야 한다.
