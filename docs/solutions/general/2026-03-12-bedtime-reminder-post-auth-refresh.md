---
tags: [sleep, notification, reminder, authorization, launch, scheduler]
category: general
date: 2026-03-12
severity: important
related_files: [DUNE/App/DUNEApp.swift, DUNETests/BedtimeReminderSchedulerTests.swift, docs/plans/2026-03-12-bedtime-reminder-post-auth-refresh.md]
related_solutions: [docs/solutions/general/2026-03-09-bedtime-reminder-lead-time-setting.md, docs/solutions/architecture/2026-03-11-launch-permission-deferral-stability.md]
---

# Solution: bedtime reminder를 notification authorization 직후 재스케줄

## Problem

launch experience 이후 notification permission을 deferred로 요청하도록 바뀐 뒤,
bedtime reminder scheduler가 권한이 없던 첫 실행 시점에 한 번 실패하면 같은 세션 안에서 다시 실행되지 않았다.

### Symptoms

- 새 설치 또는 reset 상태에서 notification permission을 허용해도 bedtime reminder pending request가 바로 생기지 않음
- 사용자가 앱을 다시 foreground로 가져오거나 설정을 바꿔야만 bedtime reminder가 예약됨
- 사용자 입장에서는 bedtime reminder 기능이 "안 도는 것처럼" 보임

### Root Cause

`DUNEApp.startRuntimeServicesIfNeeded()`가 permission prompt 이전에 `BedtimeReminderScheduler.refreshSchedule()`을 호출했고,
이 시점에는 notification authorization이 없어 scheduler가 pending reminder를 제거한 뒤 종료했다.
이후 `requestDeferredAuthorizationsIfNeeded()`에서 permission을 승인받아도 bedtime scheduler를 재호출하지 않아,
동일 세션에서는 예약이 복구되지 않았다.

## Solution

notification authorization 성공 직후 bedtime scheduler를 `force: true`로 한 번 더 실행해,
launch 시 authorization 부재로 skip된 스케줄이 같은 세션 안에서 즉시 복구되도록 수정했다.
동시에 scheduler 테스트에 `unauthorized -> authorized` 전환 시나리오를 추가해 회귀를 막았다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/DUNEApp.swift` | notification authorization 성공 결과를 받아 bedtime scheduler 강제 refresh 호출 | deferred permission flow에서도 same-session scheduling 보장 |
| `DUNETests/BedtimeReminderSchedulerTests.swift` | authorization 부재 후 grant 시 force refresh로 예약되는 테스트 추가 | scheduler 회귀 방지 |
| `docs/plans/2026-03-12-bedtime-reminder-post-auth-refresh.md` | 구현 계획 기록 | 원인과 범위 추적성 확보 |

### Key Code

```swift
let granted = try await notificationService.requestAuthorization()
hasRequestedNotificationAuthorization = true
if granted {
    await BedtimeReminderScheduler.shared.refreshSchedule(force: true)
}
```

## Prevention

permission이 필요한 scheduler/observer를 launch 초기에 먼저 시도하고 나중에 authorization을 받는 구조라면,
권한 승인 직후 동일 세션에서 side effect를 재실행하는 경로를 반드시 함께 설계해야 한다.

### Checklist Addition

- [ ] deferred permission flow가 scheduler/observer 초기 실행보다 늦다면, grant 직후 재실행 경로가 있는지 확인한다
- [ ] launch orchestration 변경 시 "권한 획득 후 같은 세션에서 복구되어야 하는 side effect" 목록을 점검한다
- [ ] scheduler 테스트에는 `unauthorized -> authorized` 전환 케이스를 포함한다

### Rule Addition (if applicable)

신규 rule 추가는 보류한다. 비슷한 deferred-permission side effect가 반복되면 launch/authorization orchestration 규칙으로 승격할 가치가 있다.

## Lessons Learned

- debounce와 force refresh를 이미 갖고 있는 scheduler라면, explicit authorization grant는 force path를 재사용하는 것이 가장 단순하다.
- "앱 재실행 후에는 정상"인 증상은 launch-time ordering 문제일 가능성이 높다.
- 사용자 기대가 watch-specific reminder에 머물러 있어도, 먼저 실제로 재현 가능한 scheduling failure를 분리해 고치면 원인 파악이 쉬워진다.
