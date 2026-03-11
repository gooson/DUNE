---
tags: [notifications, sleep-debt, background-evaluator, date-guard, testing]
category: general
date: 2026-03-11
severity: important
related_files:
  - DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift
  - DUNE/Domain/UseCases/EvaluateHealthInsightUseCase.swift
  - DUNETests/EvaluateHealthInsightUseCaseTests.swift
related_solutions:
  - docs/solutions/architecture/sleep-deficit-personal-average.md
  - docs/solutions/healthkit/background-notification-system.md
---

# Solution: Sleep debt alert today-only applicability

## Problem

`Sleep Debt Alert` 로컬 알림이 오늘 수면 deficit과 무관하게, 과거 며칠의 누적 수면 부채만으로도 오늘 알림으로 생성될 수 있었다.

### Symptoms

- 오늘 수면이 평균 이상이라 당일 deficit이 0이어도 `Sleep Debt Alert`가 발생할 수 있었다.
- background evaluator는 `SleepDeficitAnalysis`를 계산한 뒤 `weeklyDeficit`와 `level`만 보고 알림을 만들었다.
- 테스트도 `Date()` / `Calendar.current`에 기대고 있어 자정 경계에서 불안정해질 여지가 있었다.

### Root Cause

알림 applicability rule이 "오늘자 deficit이 실제로 존재하는가"를 확인하지 않았다. `EvaluateHealthInsightUseCase.evaluateSleepDebt`가 주간 누적치만 입력으로 받아, 현재 날짜와 일별 deficit 관계를 전혀 검사하지 못했다.

## Solution

`SleepDeficitAnalysis` 전체를 use case로 전달하고, `dailyDeficits` 안에 today와 같은 날의 양수 deficit이 있을 때만 alert를 생성하도록 바꿨다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/UseCases/EvaluateHealthInsightUseCase.swift` | `evaluateSleepDebt`가 `SleepDeficitAnalysis`와 `now`/`calendar`를 받아 today-only guard를 수행하도록 변경 | alert 생성 규칙을 Domain에 유지 |
| `DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift` | sleep deficit call site를 `analysis` 기반 호출로 단순화 | Data layer는 분석 결과 전달만 담당 |
| `DUNETests/EvaluateHealthInsightUseCaseTests.swift` | today deficit 존재/0/prior-day-only 분기와 fixed clock 검증 추가 | 회귀 방지 + 테스트 결정성 확보 |

### Key Code

```swift
guard analysis.dailyDeficits.contains(where: {
    calendar.isDate($0.date, inSameDayAs: now) && $0.deficitMinutes.isFinite && $0.deficitMinutes > 0
}) else { return nil }
```

## Prevention

rolling aggregate 기반 알림은 총합 수치만 보지 말고, **현재 사용자에게 보여줄 날짜의 applicability**를 함께 확인한다.

### Checklist Addition

- [ ] 누적/주간/월간 지표 알림은 현재 day/week 범위에 실제로 해당하는 entry가 있는지 확인했는가
- [ ] 날짜 기반 분기 테스트는 `Date()` / `Calendar.current`를 그대로 쓰지 않고 fixed clock을 주입했는가

### Rule Addition (if applicable)

새 전역 rule까지는 필요하지 않지만, background/local notification 버그를 다룰 때는 "aggregate threshold + current-date applicability"를 함께 검토하는 것이 안전하다.

## Lessons Learned

수면 부채처럼 누적 지표는 UI 설명에는 aggregate가 적합해도, 알림 트리거는 현재 시점 applicability를 별도로 확인해야 false positive를 줄일 수 있다. 또한 날짜 분기 테스트는 fixed clock을 함께 넣어야 실제 회귀를 안정적으로 잡을 수 있다.
