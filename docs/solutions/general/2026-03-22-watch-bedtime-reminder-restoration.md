---
tags: [sleep, apple-watch, notification, reminder, bedtime, healthkit]
category: general
date: 2026-03-22
severity: important
related_files: [DUNE/Data/Services/BedtimeWatchReminderScheduler.swift, DUNE/Data/HealthKit/HeartRateQueryService.swift, DUNE/Data/HealthKit/HealthKitObserverManager.swift, DUNE/Domain/Models/BedtimeReminderLeadTime.swift, DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift, DUNETests/BedtimeReminderSchedulerTests.swift, Shared/Resources/Localizable.xcstrings]
related_solutions: [docs/solutions/architecture/2026-03-07-bedtime-watch-reminder-implementation.md, docs/solutions/general/2026-03-08-general-bedtime-reminder.md, docs/solutions/general/2026-03-09-bedtime-reminder-lead-time-setting.md]
---

# Solution: Apple Watch 취침 리마인더 복원

## Problem

평균 취침 시간 기준 bedtime reminder는 한 차례 일반 취침 알림으로 전환되면서,
"취침 1시간 전에 Apple Watch를 안 차고 있으면 알려주기"라는 현재 요구사항과 어긋나 있었다.

### Symptoms

- 설정 라벨과 알림 카피가 일반 bedtime reminder 의미로 남아 있었다.
- 기본 리드타임이 현재 요구사항보다 긴 값으로 동작해 사용자가 기대하는 1시간 전 알림과 맞지 않았다.
- Apple Watch 미착용 조건이 빠져 있어, 실제로는 "워치를 자기 전에 착용하라"는 목적에 맞는 알림이 아니었다.

### Root Cause

- 2026-03-08 일반 bedtime reminder 전환 때 watch-specific 조건과 카피가 의도적으로 제거되었다.
- 이후 lead time 설정은 추가되었지만, 현재 제품 요구사항과 기본값이 다시 맞춰지지 않았다.
- watch-specific 동작을 복원하는 과정에서 companion app 설치 여부까지 게이트로 묶으면, paired watch 사용자 일부가 기능에서 제외되는 추가 리스크가 있었다.

## Solution

watch-specific reminder 의미를 다시 복원하되, iPhone이 직접 wrist-state를 알 수 없는 제약을 고려해
"취침 직전 90분 내 Apple Watch 출처 심박 샘플이 있으면 이미 착용 중으로 간주"하는 best-effort 휴리스틱을 적용했다.
동시에 기본 리드타임을 1시간으로 조정하고, Settings/알림 문구/로컬라이즈 문자열을 Apple Watch bedtime reminder 의미로 다시 연결했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift` | Apple Watch bedtime copy 복원, one-shot 스케줄링, paired watch gate, recent watch HR 기반 skip 조건 추가 | 현재 요구사항 반영 + 과도한 companion-install gate 제거 |
| `DUNE/Data/HealthKit/HeartRateQueryService.swift` | recent watch heart-rate sample 조회 API 추가 | 취침 직전 watch 착용 추정 근거 확보 |
| `DUNE/Data/HealthKit/SleepQueryService.swift` | watch source 판별 helper 공용화 | sleep/heart-rate 양쪽에서 동일한 watch source 식별 사용 |
| `DUNE/Data/HealthKit/HealthKitObserverManager.swift` | sleep observer 시 bedtime scheduler `force` refresh 연결 | one-shot reminder를 최신 수면 데이터 기준으로 재무장 |
| `DUNE/Domain/Models/BedtimeReminderLeadTime.swift` | default lead time을 `.oneHour`로 변경 | 현재 요구사항의 기본값 반영 |
| `DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift` | Apple Watch 전용 라벨/설명 문구 추가 | 설정 의미를 사용자 기대와 일치 |
| `DUNETests/BedtimeReminderSchedulerTests.swift` | watch 착용 추정, paired-only gate, 1시간 기본값 회귀 테스트 보강 | 스케줄러 동작과 review 수정사항 보호 |
| `Shared/Resources/Localizable.xcstrings` | 신규 설정/알림 문자열 추가 | en/ko/ja 리소스 연결 |

### Key Code

```swift
guard watchAvailabilityProvider.isPaired else {
    await removePendingReminder()
    return
}

let evaluationWindowStart = triggerDate.addingTimeInterval(-Constants.watchWearLookbackInterval)
guard currentDate >= evaluationWindowStart, currentDate < triggerDate else {
    return false
}

return await watchWearStateService.hasRecentWatchHeartRateSample(
    startingAt: sampleWindowStart,
    endingAt: currentDate
)
```

## Prevention

watch 관련 기능이라도 실제 요구사항이 "paired Apple Watch 사용자" 기준인지, "우리 companion app 설치 사용자" 기준인지 먼저 구분해야 한다.
또한 iPhone 단독으로 직접 측정할 수 없는 디바이스 상태는 휴리스틱임을 코드/문서/테스트에서 명확히 드러내야 오탐 기대치를 관리할 수 있다.

### Checklist Addition

- [ ] Watch 전용 UX를 추가할 때 `isPaired`와 `isWatchAppInstalled`를 혼용하지 말고, 제품 요구사항에 맞는 게이트만 남긴다.
- [ ] 시간 기반 one-shot notification은 재무장 트리거(app active, observer refresh 등)가 있는지 함께 확인한다.
- [ ] 직접 측정 불가능한 디바이스 상태를 휴리스틱으로 대체할 때는 회피 조건과 한계를 테스트/문서에 함께 남긴다.

### Rule Addition (if applicable)

신규 rule 추가는 보류한다. 다만 Watch 의존 기능이 늘어나면 "paired watch vs companion-installed watch" 게이트 구분을 watch rule로 승격할 가치가 있다.

## Lessons Learned

- 제품 요구사항이 되돌아오면 단순히 copy만 복원할 게 아니라, scheduler gate와 default setting까지 다시 맞춰야 한다.
- Apple Watch 착용 상태는 iPhone에서 직접 얻기 어려워도, watch-origin biometrics를 제한된 시간 창에서 조회하면 실용적인 best-effort 판정은 가능하다.
- review 단계에서 제품 요구사항과 무관한 추가 게이트를 걷어내는 작업이 실제 사용자 도달률에 큰 영향을 준다.
