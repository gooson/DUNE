---
tags: [sleep, bedtime, detail-view, healthkit, average-bedtime]
category: general
date: 2026-03-12
severity: important
related_files:
  - DUNE/Presentation/Shared/Detail/MetricDetailView.swift
  - DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift
  - DUNE/Presentation/Sleep/AverageBedtimeCard.swift
  - DUNETests/MetricDetailViewModelTests.swift
  - Shared/Resources/Localizable.xcstrings
related_solutions:
  - docs/solutions/general/2026-03-08-general-bedtime-reminder.md
  - docs/solutions/healthkit/2026-03-11-sleep-all-data-time-anchor.md
---

# Solution: Add Average Bedtime Card Above Sleep Debt

## Problem

수면 상세 화면에는 `Sleep Debt` 카드만 있어 최근 수면을 몇 시쯤 시작하는지 바로 확인할 수 없었다.
코드베이스에는 이미 평균 취침 시간 계산 use case가 있었지만, detail UI에는 연결되지 않았다.

### Symptoms

- 수면 상세 화면에서 최근 취침 패턴을 시간으로 확인할 방법이 없었다.
- 평균 취침 시간 계산 로직이 알림 스케줄러 쪽에만 사실상 묶여 있었다.
- `fetchSleepStages(for:)`의 날짜 의미를 잘못 쓰면 가장 최근 완료 수면이 평균에서 빠질 수 있었다.

### Root Cause

detail view model이 수면 부채만 별도 로드하고 있었고, 평균 취침 시간 상태를 전혀 노출하지 않았다.
또한 sleep stage 조회는 `calendar.startOfDay(for: date)` 기준 `전날 12시 ~ 당일 12시` window를 사용하므로,
최근 7박 평균을 구할 때 `dayOffset = 1...7`로 시작하면 오늘 아침에 끝난 가장 최근 수면 세션이 누락된다.

## Solution

`MetricDetailViewModel`에 평균 취침 시간 상태를 추가하고, 최근 7박 sleep stage를 병렬 조회해
기존 `CalculateAverageBedtimeUseCase`로 계산한 뒤 `Sleep Debt` 위에 새 카드로 노출했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift` | 평균 취침 시간 상태/조회 로직 추가 | detail 화면에서 기존 bedtime use case를 재사용하기 위해 |
| `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | `Sleep Debt` 위에 카드 삽입 | 최근 취침 패턴을 같은 맥락에서 바로 보이게 하기 위해 |
| `DUNE/Presentation/Sleep/AverageBedtimeCard.swift` | 새 카드 컴포넌트 추가 | 기존 `StandardCard` 시각 언어를 유지하면서 시간 값을 강조하기 위해 |
| `DUNETests/MetricDetailViewModelTests.swift` | 평균 취침 시간 계산 테스트 추가 | 자정 전후 취침 평균 회귀를 막기 위해 |
| `Shared/Resources/Localizable.xcstrings` | `Average Bedtime` 번역 추가 | en/ko/ja localization 누락을 막기 위해 |

### Key Code

```swift
for offset in 0..<SleepDetailConstants.bedtimeLookbackDays {
    guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
    group.addTask {
        let stages = try await sleepService.fetchSleepStages(for: date)
        return stages.isEmpty ? nil : (offset, stages)
    }
}
```

핵심은 최근 7박 평균이 `today`를 포함해야 한다는 점이다.
`fetchSleepStages(for: today)`가 오늘 아침에 끝난 마지막 수면을 의미하므로, offset을 `0`부터 시작해야 최신 취침 시간이 평균에 들어간다.

## Prevention

overnight metric은 “대표 시각”과 “조회 anchor 날짜”가 같아 보이더라도 실제 의미가 다를 수 있다.
sleep 관련 UI에서 `fetchSleepStages(for:)`를 사용할 때는 해당 날짜가 어떤 수면 세션을 대표하는지 먼저 명시적으로 확인해야 한다.

### Checklist Addition

- [ ] `fetchSleepStages(for:)` 사용 시 noon-anchor semantics 때문에 최근 완료 수면이 누락되지 않는지 확인
- [ ] detail/history UI에서 기존 sleep use case를 재사용할 수 있으면 중복 계산 로직을 만들지 않기
- [ ] 새 사용자 대면 카드 추가 시 `xcstrings`와 accessibility identifier/value를 함께 추가하기

### Rule Addition (if applicable)

새 rule 추가까지는 필요 없다. 다만 sleep/overnight metric UI가 더 늘어나면 detail rule로 승격할 가치가 있다.

## Lessons Learned

- 평균 취침 시간처럼 자정 전후에 걸치는 값은 기존 use case를 재사용해야 계산 규칙이 일관된다.
- sleep query의 날짜 anchor를 잘못 해석하면 최신 데이터가 조용히 빠지므로, offset 기준을 구현과 테스트에서 함께 고정해야 한다.
- 작은 카드 추가라도 localization, accessibility, xcodeproj 반영, view model 테스트까지 같이 묶어야 ship 직전 품질이 안정적이다.
