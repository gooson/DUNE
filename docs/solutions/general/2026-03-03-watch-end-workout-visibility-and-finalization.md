---
tags: [watchos, workout, confirmation-dialog, healthkit, simulator, finalization-timeout]
date: 2026-03-03
category: general
status: implemented
---

# Solution: Watch 운동 종료 확인 버튼 가시성/종료 무반응 동시 개선

## Problem

### Symptoms

- Watch 시뮬레이터에서 운동 종료 확인 다이얼로그의 `운동 종료` 버튼 대비가 낮아 가시성이 떨어짐
- 버튼 탭 후에도 운동이 종료되지 않은 것처럼 세션 화면에 머무르는 경우가 발생

### Root Cause

1. 종료 확인 버튼이 `.destructive` role로 렌더링되며 테마 tint와 결합되어 텍스트 대비가 낮아졌다.
2. 종료 플로우가 `HKWorkoutSessionDelegate.didChangeTo(.ended)` 콜백에 크게 의존했는데, 시뮬레이터에서 콜백 지연/누락 시 `isSessionEnded` 전환이 늦어 종료가 실패한 것처럼 보였다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/Views/CardioMetricsView.swift` | 종료 확인 버튼 role을 기본 버튼으로 변경 | 다이얼로그 내 버튼 대비 개선 |
| `DUNEWatch/Views/MetricsView.swift` | 종료 확인 버튼 role을 기본 버튼으로 변경 | 동일 UI 경로 가시성 일관화 |
| `DUNEWatch/Views/ControlsView.swift` | 종료 확인 버튼 role을 기본 버튼으로 변경 | 동일 UI 경로 가시성 일관화 |
| `DUNEWatch/Managers/WorkoutManager.swift` | `end()`에서 즉시 `isSessionEnded` 전환 + finalization watchdog 추가 + 종료 알림 1회 전송 가드 + stale delegate 콜백 방어 | 시뮬레이터 콜백 불안정 시에도 종료 UX 보장 |

### Key Code

```swift
func end() {
    guard !isSessionEnded else { return }
    isSessionEnded = true
    isFinalizingWorkout = session != nil
    notifyWorkoutEndedIfNeeded()
    if isFinalizingWorkout { startFinalizationTimeoutWatchdog() }
    session?.end()
}
```

## Prevention

### Checklist Addition

- [ ] Watch `confirmationDialog`에서 `.destructive` 사용 시 실제 테마 대비 확인
- [ ] HealthKit 종료 경로는 delegate 콜백 지연/누락 대비 watchdog 보유
- [ ] 세션 delegate 콜백은 현재 active session과 identity 일치 여부를 검증

### Lessons Learned

- 시뮬레이터에서 HealthKit 종료 콜백은 시작 콜백보다도 더 지연/누락될 수 있다.
- 종료 UX는 "콜백 수신 시 전환"이 아니라 "사용자 액션 시 전환 + 백그라운드 finalize" 패턴이 안정적이다.
