---
tags: [watch, stair-climber, cardio, workout-reminder, healthkit]
category: general
date: 2026-10-05
severity: important
related_files:
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNEWatch/Views/SessionPagingView.swift
  - DUNEWatchTests/StairMachineExitDetectorTests.swift
related_solutions:
  - docs/solutions/general/2026-03-11-watch-machine-cardio-inactivity-signal.md
---

# Solution: 천국의 계단 운동 이탈 시 워치 종료 제안

## Problem

천국의 계단 운동 중 기기에서 내려와 평지를 걸으면 `steps`와 `activeCalories`가 계속 증가한다. 기존 `CardioInactivityActivitySignal`은 두 값의 증가를 운동 지속으로 간주하므로 정체 감지 알림이 나오지 않는다.

### Root Cause

기존 정체 감지는 움직임 유무를 판정한다. 운동 종류가 계단에서 평지 보행으로 바뀌었는지는 판정하지 않는다. 또한 Apple Watch의 공개 동작 분류에는 계단 머신에서 내려온 이벤트가 없다.

## Solution

워치의 계단 운동에서만 거리 기반 전환 신호를 추가했다. 시작 후 90초 동안 보행 거리가 5m 이하인 세션을 고정된 머신 운동 후보로 본다. 이후 보행 거리가 증가하면 20초 이상 지속된 거리 30m와 걸음 15회, 또는 40초 이상 지속된 거리 60m를 확인한 뒤 진동과 함께 종료 여부를 묻는다. 사용자가 계속 운동을 선택하면 같은 세션에서 다시 제안하지 않는다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `WorkoutManager.swift` | 계단 운동 중 보행 거리 수집과 전환 감지기 추가 | 평지 보행 중에도 움직임 신호가 계속 증가하는 문제 해결 |
| `SessionPagingView.swift` | 계단 운동 종료 확인 알림 추가 | 사용자가 종료 또는 계속 운동을 선택 |
| `StairMachineExitDetectorTests.swift` | 전환, 거리 초기 증가, 거리 단독 대체 신호, 중복 억제 검증 | 오탐과 반복 알림 방지 |

## Prevention

운동 종류 전환을 감지할 때 걸음 수나 활동 칼로리 증가만으로 운동 지속을 확정하지 않는다. 새 신호는 해당 운동에서 실제 수집 가능한지 실기기로 확인한다. 머신 위에서도 보행 거리가 증가하는 기기에서는 이번 감지기가 초기에 비활성화된다.

## Lessons Learned

센서만으로 머신 이탈을 확정할 수 없으므로 자동 종료를 실행하지 않고 사용자에게 확인한다. HealthKit의 운동 종류별 실시간 거리 제공 여부와 샘플 지연은 Apple Watch 실기기에서 검증해야 한다.
