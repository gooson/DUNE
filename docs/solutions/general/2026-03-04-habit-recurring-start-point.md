---
tags: [life-tab, habit, recurring, interval, start-point, swiftdata-migration]
category: general
date: 2026-03-04
severity: important
related_files:
  - DUNE/Data/Persistence/Migration/AppSchemaVersions.swift
  - DUNE/Data/Persistence/Models/HabitDefinition.swift
  - DUNE/Presentation/Life/LifeViewModel.swift
  - DUNE/Presentation/Life/HabitFormSheet.swift
  - DUNE/Presentation/Life/HabitRowView.swift
  - DUNETests/LifeViewModelTests.swift
related_solutions:
  - docs/solutions/general/2026-03-04-life-recurring-checklist-reminders.md
  - docs/solutions/architecture/2026-03-01-swiftdata-schema-model-mismatch.md
---

# Solution: Habit Recurring 시작 지점 + Forward-Only 적용

## Problem

`recurring(interval)` 습관은 생성일 기반 암묵 anchor만 사용해 실제 시작일을 반영하기 어려웠고, 편집 시점 변경 정책이 없어 due 계산이 사용자 기대와 어긋났다.

### Symptoms

- recurring 생성/편집에서 시작 기준(생성일/오늘/직접 날짜/첫 완료일)을 고를 수 없다.
- 미래 시작 케이스를 due/overdue와 구분하지 못한다.
- 편집으로 시작 지점을 바꿔도 과거 로그가 그대로 계산에 섞여 정책 변경 시점 이후 적용이 보장되지 않는다.

### Root Cause

- `HabitDefinition`에 recurring start policy를 저장하는 필드가 없었다.
- cycle snapshot 계산이 `createdAt` + 로그 기반 anchor만 사용했다.
- 스키마 버전 확장 시 V8/V9 체크섬 분리 전략이 없으면 SwiftData lightweight migration에서 `Duplicate version checksums` 크래시가 발생한다.

## Solution

시작 지점 정책을 모델에 명시적으로 저장하고, cycle snapshot 계산에 `configuredAt` cutoff를 도입해 forward-only 동작을 구현했다. 또한 V8 schema에 과거 Habit 모델 스냅샷 타입을 분리해 V9 migration 체크섬 충돌을 해소했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Models/HabitType.swift` | `HabitRecurringStartPoint` enum + `HabitProgress` cycle 상태 확장 | 시작 지점/예정 상태를 도메인에 명시 |
| `DUNE/Data/Persistence/Models/HabitDefinition.swift` | `recurringStartPointRaw`, `recurringCustomStartDate`, `recurringStartConfiguredAt` 추가 | 정책 영속화 |
| `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift` | `AppSchemaV9` 추가 + V8 Habit 모델 스냅샷 내장 | migration 충돌 방지 |
| `DUNE/Presentation/Life/LifeViewModel.swift` | 시작 지점 validation/state + scheduled/cutoff snapshot 계산 | due 계산 정확도/forward-only 보장 |
| `DUNE/Presentation/Life/HabitFormSheet.swift` | recurring 시작 지점 picker/date picker 기본 노출 | 사용자 설정 UX 제공 |
| `DUNE/Presentation/Life/HabitRowView.swift` | scheduled 상태/시작일 표시 추가 | 미래 시작/첫 완료 대기 가시화 |
| `DUNE/Resources/Localizable.xcstrings` | 신규 문자열 en/ko/ja 추가 | localization 누락 방지 |
| `DUNETests/HabitTypeTests.swift`, `DUNETests/LifeViewModelTests.swift` | start point/forward-only/scheduled 테스트 추가 | 회귀 방지 |

### Key Code

```swift
let configuredAt = calendarStartOfDay(habit.recurringStartConfiguredAt ?? habit.createdAt)
let logs = allLogs.filter { calendarStartOfDay($0.date) >= configuredAt }

let startDate: Date?
switch habit.recurringStartPoint {
case .createdAt: startDate = calendarStartOfDay(habit.createdAt)
case .today: startDate = configuredAt
case .customDate: startDate = calendarStartOfDay(habit.recurringCustomStartDate ?? configuredAt)
case .firstCompletion:
    startDate = logs.first(where: { action(for: $0) == .complete }).map { calendarStartOfDay($0.date) }
}
```

## Prevention

### Checklist Addition

- [ ] recurring/cycle 계산 변경 시 `future start`, `first completion pending`, `forward-only cutoff` 테스트를 함께 추가한다.
- [ ] SwiftData schema 버전을 올릴 때 인접 버전 체크섬이 동일하지 않은지 테스트 실행으로 확인한다.
- [ ] 폼에 새 사용자 문구를 추가하면 `Localizable.xcstrings` en/ko/ja를 같은 커밋에 반영한다.

### Rule Addition (if applicable)

이번 변경은 기존 `swiftdata-cloudkit.md`, `localization.md`, `testing-required.md` 범위에서 커버되어 신규 rule 추가는 보류한다.

## Lessons Learned

SwiftData VersionedSchema에서 "모델 목록이 같아도 필드가 변한 버전"은 체크섬 충돌 가능성이 있으므로, 인접 버전 중 하나를 명시 스냅샷 타입으로 고정해 두는 것이 안전하다. 또한 recurring 기능은 anchor 정책만큼이나 "정책 변경 적용 시점"(cutoff)을 명시해야 사용자 기대와 계산 결과가 일치한다.
