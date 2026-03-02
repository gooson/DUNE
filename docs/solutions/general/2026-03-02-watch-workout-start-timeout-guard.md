---
tags: [watchos, healthkit, workout-start, timeout-guard, simulator-freeze, state-rollback]
category: general
date: 2026-03-02
severity: critical
related_files:
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNEWatch/Views/WorkoutPreviewView.swift
  - DUNETests/HealthMetricTests.swift
  - DUNETests/InjuryViewModelTests.swift
  - DUNETests/LifeViewModelTests.swift
related_solutions:
  - docs/solutions/healthkit/2026-03-02-watch-cardio-distance-tracking.md
  - docs/solutions/testing/2026-02-23-healthkit-permission-ui-test-gating.md
---

# Solution: Watch Workout Start Freeze by Startup Timeout Guard

## Problem

워치 시뮬레이터에서 운동 시작 버튼 탭 후 세션이 시작되지 않고 로딩 상태가 무한 지속되는 문제가 발생했다.

### Symptoms

- Outdoor/Indoor cardio 시작 버튼 탭 후 스피너가 계속 노출됨
- Strength 시작 버튼 탭 후에도 동일하게 시작 화면 전환이 되지 않음
- 실패 원인이 화면에서 구분되지 않아 재시도 동작이 불명확함

### Root Cause

운동 시작 공통 경로(`requestAuthorization`, `beginCollection`)가 외부 HealthKit 콜백에 의존하고 있었고, 시뮬레이터 환경에서 콜백이 지연/누락될 때 종료 조건 없이 대기했다. 실패 시 세션/모드 상태 롤백도 충분하지 않아 재시도 안정성이 낮았다.

## Solution

HealthKit 시작 경로를 timeout 보호 로직으로 감싸고 실패 시 상태를 정리하도록 변경했다. 또한 시작 실패를 `WorkoutStartupError`로 표준화하고 Preview UI에서 에러 표시를 공통 처리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/Managers/WorkoutManager.swift` | `runWithTimeout` 추가, `requestAuthorization`/`beginCollection` timeout 적용, 실패 시 HK 세션 정리, cardio 상태 롤백 보강 | 무한 대기 제거 + 재시도 안정성 확보 |
| `DUNEWatch/Views/WorkoutPreviewView.swift` | `presentStartError(_:)` 추가, 시작 실패 메시지 처리 일원화 | 시작 실패 시 UX 일관성 확보 |
| `DUNETests/HealthMetricTests.swift` | 시간 포맷 기대값을 로케일 안전한 표현으로 변경 | 환경/로케일에 따라 깨지는 테스트 제거 |
| `DUNETests/InjuryViewModelTests.swift` | 검증 메시지 테스트를 localized exact match로 변경 | 하드코딩 영어 substring 의존 제거 |
| `DUNETests/LifeViewModelTests.swift` | localized exact match로 변경 | 로케일 환경에서 테스트 안정성 확보 |

### Key Code

```swift
try await runWithTimeout(
    seconds: 10,
    timeoutError: WorkoutStartupError.beginCollectionTimedOut
) {
    try await newBuilder.beginCollection(at: now)
}

// startup failure cleanup
newSession.end()
session = nil
builder = nil
isPaused = false
isSessionEnded = false
startDate = nil
```

## Prevention

운동 시작처럼 외부 프레임워크 콜백에 의존하는 진입 경로는 반드시 timeout + rollback 규칙을 적용한다.

### Checklist Addition

- [ ] HealthKit 시작/종료 경로에 timeout이 없는 await 지점이 없는지 확인
- [ ] 시작 실패 시 session/builder/startDate/workoutMode 관련 상태가 복구되는지 확인
- [ ] 사용자 표시 에러 문구가 generic fallback 경로를 가지는지 확인

### Rule Addition (if applicable)

현 규칙(`healthkit-patterns.md`)로 커버 가능하며, 즉시 신규 규칙 추가는 불필요하다. 재발 시 timeout/rollback 항목을 룰로 승격한다.

## Lessons Learned

- 시뮬레이터 HealthKit 콜백은 정상 경로 전제만으로 안정성이 확보되지 않는다.
- timeout은 UX 보호뿐 아니라 상태 무결성(rollback)과 함께 설계해야 재시도 안정성이 생긴다.
- 테스트는 문자열 하드코딩보다 localized API 기반 assertion이 장기적으로 안전하다.
