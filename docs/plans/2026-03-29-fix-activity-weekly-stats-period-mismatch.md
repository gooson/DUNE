---
tags: [activity, weekly-stats, date-range, period, bug-fix]
date: 2026-03-29
category: plan
status: approved
---

# Fix: Activity Tab Weekly Stats Period Mismatch

## Problem

Activity 탭의 "이번 주" 섹션(카드)에 표시되는 수치와 상세 화면(WeeklyStatsDetailView)의 수치가 다르게 나옴.

### Root Cause

날짜 범위 계산이 카드와 상세 화면에서 서로 다름:

| 위치 | 기간 계산 | 결과 (3/29 기준) |
|------|----------|-----------------|
| **카드** (`ActivityViewModel.rebuildWeeklyStats`) | `Date() - 7일` (rolling time) | 3/22 14:00 ~ 3/29 14:00 |
| **상세** (`TrainingVolumeAnalysisService.analyze`) | `startOfDay(today) - (7-1)일` | 3/23 00:00 ~ 3/29 now |

상세 화면이 **하루 적게** 집계하여 카드보다 낮은 수치가 표시됨.

## Solution

`TrainingVolumeAnalysisService.analyze`의 `currentStart` 계산을 `-(days - 1)`에서 `-days`로 변경.
동시에 `ActivityViewModel.rebuildWeeklyStats`도 `startOfDay` 기반으로 정렬하여 두 곳이 동일한 기간을 사용하도록 함.

## Affected Files

| 파일 | 변경 |
|------|------|
| `DUNE/Domain/UseCases/TrainingVolumeAnalysisService.swift` | `currentStart`/`previousStart` 계산 수정 |
| `DUNE/Presentation/Activity/ActivityViewModel.swift` | `rebuildWeeklyStats` 날짜 계산을 startOfDay 기반으로 정렬 |

## Implementation Steps

### Step 1: TrainingVolumeAnalysisService 기간 수정

`analyze` 함수에서:
- `currentStart = -(days - 1)` → `-(days)`
- `previousStart = -(days * 2 - 1)` → `-(days * 2)`
- `previousEnd`는 기존대로 `currentStart - 1`

이렇게 하면:
- week: current = [today-7, now], previous = [today-14, today-8]
- month: current = [today-30, now], previous = [today-60, today-31]

### Step 2: ActivityViewModel.rebuildWeeklyStats 정렬

카드도 동일한 `startOfDay` 기반 7일 범위 사용:
```swift
let today = calendar.startOfDay(for: Date())
let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
```

## Test Strategy

- `TrainingVolumeAnalysisService` 유닛 테스트 추가: currentStart/currentEnd 범위가 정확히 `days`일을 포함하는지 검증
- 기존 테스트가 있으면 기간 변경에 맞게 수정

## Risks & Edge Cases

- 다른 `TrainingVolumeAnalysisService.analyze` 호출자(TrainingVolumeViewModel, ExerciseTypeDetailViewModel)도 영향받음 → 모두 같은 기간 문제를 갖고 있었으므로 함께 수정됨
- `previousEnd`가 `currentStart - 1 day`이므로 현재/이전 기간 gap/overlap 없음 ✓
