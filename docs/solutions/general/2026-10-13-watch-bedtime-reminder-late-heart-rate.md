---
tags: [apple-watch, bedtime, notification, healthkit, heart-rate, stale-state]
category: general
date: 2026-10-13
status: implemented
severity: important
related_files: [DUNE/Data/Services/BedtimeWatchReminderScheduler.swift, DUNE/Data/HealthKit/HealthKitObserverManager.swift, DUNETests/BedtimeReminderSchedulerTests.swift, DUNETests/HealthKitObserverManagerTests.swift, Shared/Resources/Localizable.xcstrings]
related_solutions: [docs/solutions/general/2026-03-22-watch-bedtime-reminder-restoration.md]
---

# Solution: 착용 중 도착하는 Apple Watch 취침 알림 줄이기

## Problem

### Symptoms

- 사용자가 Apple Watch를 차고 있는데도 “잠들기 전에 Apple Watch를 착용하세요”라는 알림을 받았다.
- 앱을 낮에 열어 취침 알림을 예약한 뒤, 밤에 워치를 착용하는 경우를 기존 테스트가 다루지 않았다.

### Root Cause

스케줄러는 알림을 **예약할 때**만 최근 90분 이내 Watch 출처 심박 샘플을 조회했다. 낮에 예약하면 취침 알림 시각까지 시간이 남아 있어 착용 확인을 건너뛰었고, 이후 들어온 심박 데이터는 예약된 알림을 취소하지 않았다. 일반 `refreshSchedule()`의 30분 제한 안에 다시 앱을 열어도 착용 상태를 확인하지 않았다.

[로컬 알림](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter)은 예약 후 전달 시점에 HealthKit 상태를 조건으로 다시 평가하지 않는다. [Notification Service Extension](https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension)은 원격 알림용이므로 이 로컬 알림의 전달 직전 검사에 사용할 수 없다.

## Solution

HealthKit 심박 샘플 업데이트를 `.immediate`로 관찰한다. 업데이트가 들어오면 전체 건강 데이터 새로 고침 없이 Apple Watch 취침 알림을 재확인한다. 저장된 알림 시각을 먼저 확인해 발송 90분 전부터만 pending request를 조회한다. 그 시간대에 최근 Watch 출처 심박이 있으면 해당 request를 취소한다. 검사 중 추가 심박 이벤트가 오면 끝난 뒤 한 번 더 확인하고, 여러 이벤트를 각각 조회하지 않는다. 30분 재예약 제한에 걸린 foreground refresh에도 동일한 검사를 수행한다.

알림 갱신과 심박 이벤트의 취소 작업은 스케줄러 안에서 직렬로 실행한다. 따라서 갱신 중 새 알림이 등록된 뒤 취소 작업이 시작되며, 반대 순서에서는 갱신이 최신 심박 상태를 다시 평가한다. 알림 센터에는 같은 식별자의 요청을 추가해 기존 예약을 교체한다.

착용 여부를 확정할 수 없는 상황을 고려해 알림 제목과 본문은 착용을 단정하는 명령형 대신 착용 상태를 확인하는 문장으로 바꿨다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift` | 예약 시각 저장, 시간대별 재확인, 갱신·취소 직렬화 | 예약 후 달라진 착용 상태 반영과 비동기 경합 방지 |
| `DUNE/Data/HealthKit/HealthKitObserverManager.swift` | 심박 observer 등록, 주입 가능한 알림 재확인 경로 | 백그라운드에서 새 심박에 반응하고 이벤트 경로 테스트 허용 |
| `DUNETests/BedtimeReminderSchedulerTests.swift` | 낮 예약 후 밤 착용, Watch 외 샘플, debounce, 등록·조회 중 심박 이벤트 테스트 | 오탐·경합 회귀 방지 |
| `DUNETests/HealthKitObserverManagerTests.swift` | 심박 observer 등록, delivery 주기, 완료 콜백 테스트 | 이벤트 경로 유지 |
| `Shared/Resources/Localizable.xcstrings` | en/ko/ja 알림 문구 수정 | 실제 착용 상태를 단정하지 않음 |

### Key Code

```swift
await scheduleSerialized { [self] in
    await recheckPendingReminder(at: now())
}.value

// recheckPendingReminder first checks the stored trigger date, then reads the pending request.
```

### Verification

- iPhone 18 Pro 시뮬레이터(iOS 27.0)에서 두 취침 알림 스케줄러 suite의 20개 테스트가 통과했다. 여기에는 알림 등록과 착용 조회 중 들어오는 심박 업데이트의 경합 테스트가 포함된다.
- 최종 observer 경로 변경 후 `HealthKitObserverManagerTests`의 5개 테스트가 통과했다. 심박 이벤트의 재확인과 완료 콜백 순서를 확인했다.
- `swift scripts/format-xcstrings.swift --check`와 `git diff --check`가 통과했다.
- Watch 실기기에서 HealthKit 심박 동기화 시각과 백그라운드 알림 취소 시각을 확인하는 검증은 별도로 필요하다.

## Prevention

- 상태에 따라 **발송 여부**가 달라지는 로컬 알림은 예약 시 검사만으로 끝내지 않는다. 상태 업데이트 이후 pending request를 취소하거나 변경하는 경로를 확인한다.
- 심박 데이터는 착용의 간접 증거다. Watch→iPhone 동기화 또는 HealthKit 백그라운드 전달이 늦으면 알림 취소가 발송 전에 실행되지 않을 수 있다. [HealthKit observer background delivery](https://developer.apple.com/documentation/healthkit/executing-observer-queries)는 실기기에서 확인해야 한다.
- 직접 손목 착용 상태를 제공하는 SensorKit API는 [승인된 연구 앱에만 부여되는 권한](https://developer.apple.com/documentation/sensorkit/configuring-your-project-for-sensor-reading)이 필요하므로 이 앱의 일반 기능에 사용할 수 없다.

### Checklist Addition

- [ ] 조건부 one-shot 알림은 예약 이후 조건이 바뀔 때 pending request를 다시 평가하는가?
- [ ] 조건 판정이 간접 증거라면 알림 문구가 확정된 상태를 주장하지 않는가?
- [ ] HealthKit 백그라운드 갱신이 필요한 수정은 실제 Watch+iPhone에서 지연·권한 상태를 확인했는가?

### Rule Addition (if applicable)

현재는 문서와 테스트로 보존한다. 같은 유형의 조건부 알림이 늘어나면 공통 알림 규칙으로 승격한다.

## Lessons Learned

알림 예약 시각과 실제 전달 시각 사이에는 사용자 상태가 바뀐다. 예약 검사와 함께 상태 변경을 받아 pending 알림을 취소하는 경로가 필요하다. 또한 HealthKit 심박은 착용을 추정할 수 있지만 실시간 착용 상태를 보장하지 않으므로 문구에도 그 한계를 반영해야 한다.
