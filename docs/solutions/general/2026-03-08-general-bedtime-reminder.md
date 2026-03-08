---
tags: [sleep, notification, bedtime, reminder, migration, localization]
category: general
date: 2026-03-08
severity: important
related_files: [DUNE/Data/Services/BedtimeWatchReminderScheduler.swift, DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift, DUNETests/BedtimeReminderSchedulerTests.swift, Shared/Resources/Localizable.xcstrings, DUNE/App/DUNEApp.swift, DUNE/App/ContentView.swift]
related_solutions: [docs/solutions/architecture/2026-03-07-bedtime-watch-reminder-implementation.md, docs/solutions/performance/2026-03-08-review-triage-debounce-and-caching.md]
---

# Solution: 일반 취침 알림으로 bedtime reminder 전환

## Problem

기존 bedtime reminder는 "Apple Watch를 안 찼을 때만" 동작하는 watch-specific 기능이었다.
이번 제품 요구사항은 워치 착용 여부와 무관하게, 최근 평균 취침 시간보다 2시간 앞서 건강/회복/운동 관점의 일반 취침 알림을 보내는 것이다.
또한 기존 반복 알림 identifier를 새 identifier로 바꾸는 과정에서, 이미 배포된 watch reminder가 업그레이드 사용자 기기에 남아 중복 알림을 만들 수 있었다.

### Symptoms

- 취침 알림이 watch 의존적 메시지와 조건을 계속 사용함
- 리드 타임이 30분으로 고정되어 새 요구사항과 불일치
- 기존 watch reminder pending request가 남으면 일반 취침 알림과 이중 발송 가능

### Root Cause

- scheduler가 watch pairing / wrist temperature 기반으로 설계되어 기능 의미 전환에 바로 맞지 않았음
- scheduled notification identifier를 교체하면서 legacy identifier cleanup 경로를 함께 추가하지 않았음
- scheduler 전용 회귀 테스트가 없어 identifier migration과 gate 조건을 코드로 보호하지 못했음

## Solution

bedtime scheduler를 watch-independent reminder로 단순화하고, 평균 취침 시간 2시간 전 스케줄로 변경했다.
동시에 설정 문구와 로컬라이제이션을 일반 취침 알림 의미로 교체하고, 새 reminder를 예약하거나 제거할 때 legacy watch identifier까지 함께 정리하도록 보강했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift` | watch gate 제거, 2시간 리드 타임 적용, legacy identifier cleanup 추가 | 일반 취침 알림 요구사항 반영 + 업그레이드 중복 알림 방지 |
| `DUNE/App/DUNEApp.swift` | `BedtimeReminderScheduler` 호출로 갱신 | 런타임 시작 시 최신 스케줄 반영 |
| `DUNE/App/ContentView.swift` | foreground refresh 호출 타입명 갱신 | active 진입 시 최신 평균 취침 시간 반영 |
| `DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift` | 토글 라벨/icon을 일반 취침 알림 의미로 변경 | 사용자 설정 의미 일치 |
| `Shared/Resources/Localizable.xcstrings` | 신규 취침 알림 title/body 및 설정 라벨 번역 추가 | en/ko/ja 로컬라이제이션 완결성 확보 |
| `DUNETests/BedtimeReminderSchedulerTests.swift` | 스케줄 시간/disabled/no-data/legacy cleanup 기대값 검증 추가 | 핵심 스케줄링 회귀 방지 |
| `todos/096-ready-p3-bedtime-reminder-lead-time-setting.md` | 리드 타임 사용자 설정 후속 작업 기록 | 범위 밖 요구사항을 안전하게 backlog화 |

### Key Code

```swift
private enum Constants {
    static let legacyNotificationIdentifier = "com.raftel.dune.bedtime-watch-reminder"
    static let notificationIdentifier = "com.raftel.dune.bedtime-reminder"
    static let leadMinutes = 120
}

func removePendingReminder() async {
    notificationScheduler.removePendingReminder(identifier: Constants.notificationIdentifier)
    notificationScheduler.removePendingReminder(identifier: Constants.legacyNotificationIdentifier)
}
```

## Prevention

기존 예약 알림의 의미나 identifier를 바꿀 때는 migration 관점에서 "이미 예약된 pending request를 어떻게 정리할지"를 반드시 함께 설계해야 한다.
또한 시간 기반 개인화 기능은 scheduler 자체를 직접 테스트해 trigger 시간과 cleanup 경로를 함께 보호해야 한다.

### Checklist Addition

- [ ] scheduled notification identifier를 바꾸면 legacy identifier cleanup 경로를 같이 추가한다
- [ ] scheduler/notification migration 변경에는 pending request removal 테스트를 포함한다
- [ ] 사용자 대면 알림 카피 변경 시 xcstrings en/ko/ja 3개 언어를 함께 확인한다

### Rule Addition (if applicable)

신규 rule 추가는 보류한다. 다만 future notification migration 패턴이 반복되면 notification rule로 승격할 가치가 있다.

## Lessons Learned

- 기능 의미가 바뀌면 gate 조건만 바꾸는 것이 아니라 copy, identifier, 테스트까지 함께 갱신해야 한다.
- 반복 로컬 알림은 코드에서 더 이상 쓰지 않는 identifier라도 기기에는 계속 남을 수 있으므로, migration cleanup이 필수다.
- simulator test는 host flake가 간헐적으로 발생하므로, resolve 단계에서는 최소한 build-for-testing과 app build를 함께 확보해두는 것이 안전하다.
