---
tags: [life-tab, habit, healthkit, auto-achievement, weekly-goal, streak]
category: architecture
date: 2026-03-04
severity: important
related_files:
  - DUNE/Domain/UseCases/LifeAutoAchievementService.swift
  - DUNE/Presentation/Life/LifeViewModel.swift
  - DUNE/Presentation/Life/LifeView.swift
  - DUNETests/LifeAutoAchievementServiceTests.swift
related_solutions:
  - docs/solutions/architecture/2026-02-28-habit-tab-implementation-patterns.md
---

# Solution: Life 탭 HealthKit 주간 자동 달성 시스템

## Problem

Life 탭은 `New Habit` 중심의 수동 기록 흐름만 제공되어, 운동 기록 기반 주간 목표(주 5/7회, 근력/부위별, 러닝 거리)를 자동으로 반영하지 못했다.

### Symptoms

- 사용자가 운동을 기록해도 Life 탭에서 주간 달성 상태가 자동 반영되지 않음
- 수동 habit 입력과 운동 목표 추적이 섞여 `자동 시스템` 요구를 충족하지 못함
- 과거 운동 기록을 기반으로 한 소급 달성(streak) 확인이 어려움

### Root Cause

- Life 탭의 기존 자동 연동은 `todayExerciseExists` 기반 일일 완료 표시만 지원
- 주간 규칙/부위별 집계/거리 누적/주간 streak 계산을 담당하는 전용 도메인 로직이 부재
- UI에서 수동 habit과 자동 달성 영역이 분리되지 않음

## Solution

주간 자동 달성 규칙을 `LifeAutoAchievementService`로 분리하고, `LifeViewModel`에서 운동 레코드를 도메인 엔트리로 변환해 계산하도록 확장했다.  
UI는 `Auto Workout Achievements` 섹션을 별도로 추가하여 수동 habit과 분리된 자동 시스템을 제공한다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/UseCases/LifeAutoAchievementService.swift` | 신규 규칙 엔진 추가 | 주간 5/7회, 근력 3회, 부위별 3회, 러닝 15km, 월요일 시작, dedup, 소급 streak 계산 |
| `DUNE/Presentation/Life/LifeViewModel.swift` | `autoExerciseProgresses` 상태 + 계산 메서드 추가 | View가 전달한 ExerciseRecord를 규칙 엔진 입력으로 변환 |
| `DUNE/Presentation/Life/LifeView.swift` | 자동 달성 섹션 UI 추가 + recalculate 연동 | `New Habit`과 분리된 자동 목표 표시 |
| `DUNETests/LifeAutoAchievementServiceTests.swift` | 신규 유닛 테스트 추가 | 규칙/경계/소급/dedup 핵심 로직 검증 |
| `DUNETests/LifeViewModelTests.swift` | 연동 테스트 추가 | ViewModel에서 자동 달성 상태 갱신 회귀 방지 |

### Key Code

```swift
autoExerciseProgresses = LifeAutoAchievementService.calculateProgresses(
    from: entries,
    referenceDate: referenceDate
)
```

```swift
if isStrength {
    metrics.strengthWorkoutCount += 1
    for area in bodyAreas {
        metrics.strengthBodyAreaCount[area, default: 0] += 1
    }
}
```

```swift
var calendar = Calendar(identifier: .gregorian)
calendar.firstWeekday = 2 // Monday start
calendar.minimumDaysInFirstWeek = 4
```

## Prevention

### Checklist Addition

- [ ] 주간 목표 기능 추가 시 주 시작 요일(월요일/사용자 로캘)을 명시적으로 결정했는가
- [ ] HealthKit 연동 기반 집계에서 dedup 키(Workout ID)가 반영되었는가
- [ ] 자동 계산 신호(onChange)가 count-only 관찰로 누락되지 않는가
- [ ] 주간 규칙 로직은 View가 아닌 서비스 계층에서 테스트 가능한가

### Rule Addition (if applicable)

신규 rule 파일 추가는 보류.  
향후 유사 요구가 반복되면 Life/Habit 전용 rule(자동 달성 계산 분리 + 주간 기준 고정)을 승격한다.

## Lessons Learned

- 일일 auto-link(`todayExerciseExists`)와 주간 achievement 규칙은 목적이 달라 별도 계산 축으로 분리해야 유지보수가 쉬워진다.
- 스키마 변경 없이도 도메인 계산 서비스 + 표시 분리만으로 자동 시스템 요구를 충족할 수 있다.
- 주간 규칙 기능은 날짜 경계(월요일 시작), 중복 제거, 단위 정규화(거리 km/m) 테스트가 품질의 핵심이다.
