---
tags: [watchos, stair-stepper, stair-climber, inactivity, false-positive, auto-end]
category: general
date: 2026-10-14
severity: important
related_files:
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNEWatchTests/CardioInactivityPolicyTests.swift
related_solutions:
  - docs/solutions/general/2026-03-11-watch-machine-cardio-inactivity-signal.md
  - docs/solutions/general/2026-10-05-watch-stair-machine-exit-suggestion.md
---

# Solution: 손잡이를 잡은 계단 운동의 잘못된 정지 알림 방지

## Problem

### Symptoms

- 스텝퍼 또는 천국의 계단에서 손잡이를 잡고 운동하는 동안 Watch가 움직임이 없다고 알리고 종료를 제안한다.
- 알림을 놓치면 기존 정책은 마지막 활동 신호 이후 120초와 추가 10초 뒤 세션을 자동 종료할 수 있다.

### Root Cause

`CardioInactivityActivitySignal`은 거리, 걸음, 오른 층수 및 기구 운동의 활동 칼로리 증가를 지속 신호로 사용한다. 손잡이에 손목이 고정되고 기구가 제자리에서 작동하면 거리·걸음·층수가 증가하지 않을 수 있다. HealthKit의 실시간 활동 칼로리 수집도 운동 설정과 사용 가능한 데이터 타입에 좌우되므로, 값이 그대로라는 사실만으로 계단 운동 종료를 확정할 수 없다. 그러나 `CardioInactivityPolicy`는 해당 세션에도 일반 유산소 운동과 같은 정지 시간 기준을 적용했다. 당시 실기기 센서 값은 확보하지 못했으며, 확인된 것은 이 오탐 경로다.

## Solution

계단 기구 활동 유형인 `stairClimbing`과 `stairStepper`는 손목·HealthKit 지표가 정적인 경우에도 일반 정지 알림과 자동 종료를 실행하지 않는다. 당시에는 기구 이탈 추정 알림이 별도로 남아 있었으나, 2026-10-19에 실운동 중 오탐이 확인되어 제거했다. 현재 동작은 [계단 운동 알림 제거](2026-10-19-watch-stair-workout-continuity.md)를 참조한다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/Managers/WorkoutManager.swift` | 정지 정책에 운동 유형을 전달하고 계단 기구 유형을 제외 | 정적인 손목 지표로 운동을 종료하지 않기 위해 |
| `DUNEWatchTests/CardioInactivityPolicyTests.swift` | 두 계단 유형의 알림·자동 종료 방지와 일반 달리기 기준 유지 검증 | 같은 오탐의 재발 방지 |

### Key Code

```swift
if case .cardio(let activityType, _) = workoutMode, activityType.isStairBased {
    return .none
}
```

## Prevention

- 계단 기구처럼 손목을 고정하는 운동에는 걸음·거리·층수·활동 칼로리의 무변화를 종료 증거로 사용하지 않는다.
- 운동 유형별 정지 정책을 바꿀 때 알림 시작, 종료 확인, 자동 종료 경계값을 각각 테스트한다.
- 거리 기반 기구 이탈 감지의 실기기 정확도는 별도로 확인한다. 시뮬레이터의 HealthKit 데이터로 센서 정확도를 입증하지 않는다.

## Lessons Learned

활동 칼로리 fallback은 일부 계단 운동의 오탐을 줄였지만, 데이터가 오지 않는 동안 계속 운동 중임을 증명할 수는 없다. 확실하지 않은 센서의 부재는 자동 종료 근거가 될 수 없다.
