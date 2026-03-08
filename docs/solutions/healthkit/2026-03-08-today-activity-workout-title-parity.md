---
tags: [healthkit, today-tab, dashboard, workout-title, title-parity]
category: healthkit
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
  - DUNETests/DashboardViewModelTests.swift
related_solutions:
  - docs/solutions/healthkit/2026-03-07-healthkit-workout-title-roundtrip.md
---

# Solution: Today Activity Workout Title Parity

## Problem

투데이탭 활동 섹션의 운동 카드가 앱에서 기록된 개별 운동명을 표시하지 않고, `Weight Training` 같은 generic activity label로 보였다.

### Symptoms

- Today 탭 활동 카드에서 앱 기록 strength workout이 대부분 `Weight Training`으로 표시됨
- 같은 카드를 눌러 상세 화면으로 들어가면 `Bench Press` 같은 실제 운동명이 정상 표시됨
- 리스트/상세와 Today 카드 간 제목 우선순위가 달라 보이는 일관성 문제가 생김

### Root Cause

`DashboardViewModel`의 activity card 생성 로직만 `WorkoutSummary.localizedTitle`을 쓰지 않고 `activityType.displayName`을 직접 사용하고 있었다. 그 결과, 이미 HealthKit metadata round-trip을 복구한 다른 화면들과 달리 Today 카드만 generic strength label로 되돌아갔다.

## Solution

Today activity card 이름도 Exercise list/detail과 동일하게 `WorkoutSummary.localizedTitle`을 우선 사용하도록 맞췄다. 그리고 strength workout custom title이 유지되는 회귀 테스트를 `DashboardViewModelTests`에 추가했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | per-type activity card의 `name`을 `localizedTitle` 우선으로 변경 | Today 카드와 상세/리스트 간 제목 우선순위 통일 |
| `DUNETests/DashboardViewModelTests.swift` | stored HealthKit title 회귀 테스트 추가 | `Weight Training` 회귀 방지 |

### Key Code

```swift
name: relevantWorkouts.first?.localizedTitle
    ?? relevantWorkouts.first?.activityType.displayName
    ?? type
```

## Prevention

### Checklist Addition

- [ ] HealthKit workout title 관련 수정 시 Today card, workout list, detail view가 같은 title resolution 경로를 쓰는지 확인한다
- [ ] `activityType.displayName` 직접 사용 전, `WorkoutSummary.localizedTitle` 재사용 가능 여부를 먼저 확인한다

### Rule Addition (if applicable)

이번에는 별도 rule 추가 없이 solution 문서로 남긴다. 같은 유형이 반복되면 HealthKit title parity 규칙으로 승격한다.

## Lessons Learned

1. HealthKit metadata round-trip을 복구해도 소비 지점 하나가 legacy fallback을 직접 쓰면 사용자는 여전히 generic label을 보게 된다.
2. workout title 표시는 `WorkoutSummary.localizedTitle` 같은 single source of truth를 통과시켜야 화면 간 일관성이 유지된다.
3. Today/Dashboard처럼 요약 카드가 있는 화면은 상세 화면과 별도 DTO를 쓰더라도 title resolution parity를 테스트로 고정하는 편이 안전하다.
