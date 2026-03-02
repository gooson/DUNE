---
tags: [healthkit, watch, delete, workout, watchconnectivity, dedup]
category: architecture
date: 2026-03-03
severity: important
related_files:
  - DUNE/Data/HealthKit/WorkoutDeleteService.swift
  - DUNE/Presentation/Shared/ViewModifiers/ConfirmDeleteRecordModifier.swift
  - DUNE/Presentation/Exercise/ExerciseView.swift
  - DUNE/Data/WatchConnectivity/WatchSessionManager.swift
  - DUNEWatch/WatchConnectivityManager.swift
related_solutions:
  - docs/solutions/healthkit/2026-02-26-watch-workout-dedup-false-positive.md
---

# Solution: Watch Manual Workout Delete Parity

## Problem

워치에서 직접 기록한 운동은 iPhone에서 삭제해도 HealthKit 데이터가 남아 재표시되거나, HealthKit-only 항목은 삭제 액션이 노출되지 않았다.

### Symptoms

- iPhone 수동 입력 운동은 삭제되지만 Watch 입력 운동은 삭제 후 다시 보임
- `healthKitWorkoutID`가 누락된 레코드는 HealthKit 삭제가 전혀 시도되지 않음
- HealthKit-only 항목(앱 기원)에는 삭제 스와이프가 없어 사용자가 정리할 수 없음

### Root Cause

1. 삭제 경로가 `ExerciseRecord.healthKitWorkoutID`에 강하게 의존했다.
2. UUID가 없는 경우 fallback 삭제 전략이 없었다.
3. iPhone HealthKit 삭제 실패 시 Watch 측 재시도 경로가 없었다.
4. Exercise 목록에서 HealthKit source 항목은 삭제 UI가 차단되어 있었다.

## Solution

UUID 기반 삭제는 유지하고, UUID 누락/권한 실패 경로를 보강했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/HealthKit/WorkoutDeleteService.swift` | UUID 누락 시 시간 근접 + 앱 소스 기반 삭제 대상 UUID 복구 로직 추가 | watch 저장 race로 ID 누락된 레코드 삭제 지원 |
| `DUNE/Data/HealthKit/WorkoutQueryService.swift` | `isFromThisApp` 판정에 app-family source classifier 적용 | watch companion bundle도 앱 기원으로 인식 |
| `DUNE/Presentation/Shared/ViewModifiers/ConfirmDeleteRecordModifier.swift` | manual 삭제 시 UUID 복구 경로 사용, iPhone 삭제 실패 시 Watch 삭제 요청 fallback | iPhone 단독 삭제 실패 케이스 보완 |
| `DUNE/Presentation/Exercise/ExerciseView.swift` | 앱 기원 HealthKit-only row에도 삭제 스와이프 + 확인 alert 추가 | orphan HealthKit row를 UI에서 정리 가능 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | iPhone → Watch workout UUID 삭제 요청 전송(sendMessage + transferUserInfo) | watch-side deletion fallback 전달 |
| `DUNEWatch/WatchConnectivityManager.swift` | 삭제 요청 수신 후 Watch HealthKit 삭제 수행 | iPhone 실패 시 watch source에서 삭제 수행 |
| `DUNETests/ExerciseViewModelTests.swift` | strength watch/manual dedup fallback 테스트 추가 | watch set 기반 레코드 회귀 방지 |
| `DUNETests/WorkoutSourceClassifierTests.swift` | app-family source 판정 단위 테스트 추가 | bundle 분류 로직 안정성 확보 |

### Key Code

```swift
// ConfirmDeleteRecordModifier.swift
let targetUUID = try await deleteService.resolveDeletionTargetUUID(
    linkedUUID: hkWorkoutID,
    fallbackStartDate: recordDate,
    preferredActivityType: inferredActivityType
)
try await deleteService.deleteWorkout(uuid: targetUUID)
```

```swift
// iPhone fallback -> Watch delete request
WatchSessionManager.shared.requestWatchWorkoutDeletion(workoutUUID: targetUUID)
```

## Prevention

### Checklist Addition

- [ ] 삭제 로직이 `healthKitWorkoutID == nil` 경로를 명시적으로 처리하는가
- [ ] HealthKit-only 목록 항목에 사용자 삭제 경로가 제공되는가
- [ ] iPhone HealthKit 삭제 실패 시 watch fallback 경로가 존재하는가
- [ ] fallback 삭제는 app-family source + 시간 근접 + 모호성 차단 조건을 만족하는가

### Rule Addition (if applicable)

`.claude/rules/healthkit-patterns.md`에 아래 체크 추가를 권장:
- "삭제 fallback은 app-family source가 식별되지 않으면 수행하지 않는다."
- "UUID 없는 삭제 fallback은 후보가 모호하면 중단한다."

## Lessons Learned

`healthKitWorkoutID` 단일 키에 의존한 삭제 경로는 Watch 동기화 지연/누락 상황에서 쉽게 끊어진다.
삭제 기능은 `식별자 누락`, `소스 권한 차이`, `UI 노출`을 함께 설계해야 재발을 막을 수 있다.
