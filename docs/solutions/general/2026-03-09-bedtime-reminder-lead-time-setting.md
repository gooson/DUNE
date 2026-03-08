---
tags: [sleep, notification, bedtime, reminder, settings, debounce]
category: general
date: 2026-03-09
severity: important
related_files: [DUNE/Data/Services/BedtimeWatchReminderScheduler.swift, DUNE/Domain/Models/BedtimeReminderLeadTime.swift, DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift, DUNETests/BedtimeReminderSchedulerTests.swift, Shared/Resources/Localizable.xcstrings]
related_solutions: [docs/solutions/general/2026-03-08-general-bedtime-reminder.md, docs/solutions/performance/2026-03-08-review-triage-debounce-and-caching.md]
---

# Solution: 취침 알림 리드 타임 설정 추가

## Problem

일반 취침 알림은 최근 평균 취침 시간 2시간 전으로만 고정되어 있었다.
사용자마다 취침 준비를 시작하는 선호 시점이 달라서, 30분 / 1시간 / 2시간 중 하나를 직접 선택할 수 있어야 했다.
또한 기존 scheduler는 foreground 과호출을 막기 위한 30분 debounce를 이미 갖고 있어서, 설정 변경 직후 재스케줄까지 같은 debounce에 묶이면 요구사항을 만족할 수 없었다.

### Symptoms

- Settings에서 bedtime reminder의 리드 타임을 변경할 수 없었다
- 평균 취침 시간은 계산되지만 trigger time이 항상 2시간 전으로 고정되었다
- 설정을 바꾸더라도 즉시 재스케줄되는 전용 경로가 없었다

### Root Cause

- 리드 타임이 scheduler 내부 상수(`120분`)로 하드코딩되어 있었다
- 리드 타임을 표현하는 공용 모델이 없어 UI, persistence, scheduler가 같은 source of truth를 공유하지 못했다
- debounce가 foreground refresh와 explicit user action을 구분하지 않았다

## Solution

`BedtimeReminderLeadTime` enum을 공용 설정 모델로 도입하고, Settings의 picker와 scheduler가 동일한 storage key를 공유하게 했다.
Scheduler에는 `refreshSchedule(force:)`를 추가해 foreground/launch refresh는 기존 debounce를 유지하면서, 사용자가 설정을 바꿀 때는 `force: true`로 즉시 재스케줄되도록 분리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Models/BedtimeReminderLeadTime.swift` | `30m / 1h / 2h` enum과 storage key 추가 | UI/persistence/scheduler 공용 source of truth 확보 |
| `DUNE/Presentation/Shared/Extensions/BedtimeReminderLeadTime+View.swift` | localized `displayName` 추가 | Settings picker 라벨을 enum 기반으로 일관되게 표시 |
| `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift` | 하드코딩 제거, persisted lead time 반영, `refreshSchedule(force:)` 추가 | explicit settings change는 debounce를 우회하고 trigger 계산은 사용자 선택값 사용 |
| `DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift` | lead time picker + `onChange` 재스케줄 연결 | 설정 변경 직후 pending reminder 재예약 |
| `DUNETests/BedtimeReminderSchedulerTests.swift` | parameterized lead time test + force refresh 회귀 테스트 추가 | 선택값별 trigger time과 debounce bypass를 보호 |
| `Shared/Resources/Localizable.xcstrings` | picker label/option 번역 추가 | en/ko/ja localization 완결성 확보 |

### Key Code

```swift
func refreshSchedule(force: Bool = false) async {
    let currentDate = now()
    if !force,
       let last = lastRefreshDate,
       currentDate.timeIntervalSince(last) < 30 * 60 {
        return
    }
    lastRefreshDate = currentDate

    let leadTime = configuredLeadTime()
    let bedtimeMinutes = (bedtime.hour ?? 0) * 60 + (bedtime.minute ?? 0)
    let triggerMinutes = (bedtimeMinutes - leadTime.minutes + (24 * 60)) % (24 * 60)
}
```

## Prevention

사용자 설정에 의해 바뀌는 시간/빈도 로직을 scheduler 내부 상수로 유지하지 말고, 공용 모델로 승격해 UI와 실행 경로가 같은 값을 보도록 해야 한다.
또한 비용이 큰 background/foreground refresh에 debounce가 필요하더라도, 명시적 사용자 액션까지 같은 throttle에 묶이면 UX 요구사항을 깨뜨릴 수 있으므로 `force` 또는 별도 immediate path를 함께 설계해야 한다.

### Checklist Addition

- [ ] scheduler에 debounce를 넣을 때 explicit user action이 우회해야 하는지 함께 판단한다
- [ ] 시간 기반 사용자 설정은 enum/rawValue 기반으로 persistence와 테스트를 함께 설계한다
- [ ] Settings 변경 직후 side effect가 필요하면 `onChange` 경로의 즉시성 테스트를 추가한다

### Rule Addition (if applicable)

신규 rule 추가는 보류한다. 다만 비슷한 notification scheduler가 더 늘어나면 “debounced background refresh + forced user-initiated refresh” 패턴을 공통 rule로 승격할 가치가 있다.

## Lessons Learned

- debounce는 성능 최적화이지만, 명시적 사용자 설정 변경과 같은 high-intent 액션에는 그대로 적용하면 안 된다.
- enum 하나를 source of truth로 두면 Settings UI, UserDefaults, scheduler 계산, 테스트 기대값이 모두 한 축으로 정렬된다.
- scheduler 관련 기능은 “시간 계산”뿐 아니라 “설정 변경 직후 재스케줄”까지 회귀 테스트로 잡아야 실제 UX 요구사항을 보호할 수 있다.
