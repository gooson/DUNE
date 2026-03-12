---
tags: [watch, rpe, auto-estimation, rest-timer, epley, 1rm]
date: 2026-03-12
category: solution
status: implemented
---

# Watch RPE Auto-Estimation & Rest Screen Integration

## Problem

Watch `SetInputSheet`에서 RPE 입력이 무게/횟수 아래에 위치하여 스크롤에 가려지고, 접힌 상태에서 기능 인지가 어려웠다.

## Solution

RPE를 자동 추정하고 세트 간 휴식 화면에서 확인/조정하도록 변경.

### Architecture

```
세트 완료 → WatchRPEEstimator.estimateRPE() → estimatedRPE @State
    → RestTimerView(estimatedRPE:, onRPEAdjusted:)
        → 사용자 ±0.5 조정 가능
    → handleRestComplete() → workoutManager.recordSetRPE()
    → CompletedSetData.rpe 기록
```

### Key Components

| Component | Role |
|-----------|------|
| `WatchRPEEstimator` (enum, static) | Epley 1RM% → RPE 매핑 + reps degradation correction |
| `RestTimerView` rpeOverlay | RPE 배지 표시 + 탭 조정 UI |
| `WorkoutManager.recordSetRPE()` | 마지막 완료 세트에 RPE 기록 |
| `MetricsView.flushEstimatedRPE()` | 모든 exit path에서 RPE 저장 보장 |

### Estimation Algorithm

1. 세션 내 이전 세트에서 Epley formula로 best 1RM 추정
2. 현재 세트의 weight / best1RM = %1RM → RPE 매핑
3. Reps degradation correction: 이전 세트 대비 reps 감소 시 +0.5
4. `RPELevel.validate()` 로 6.0-10.0, 0.5 step 보장
5. 추정 불가 시 `nil` → UI silent skip

### Critical: RPE Flush on All Exit Paths

RPE는 세트 완료 시 추정되지만, `recordSetRPE()`는 rest timer 완료 시 호출된다.
이 temporal gap에서 데이터 손실 방지를 위해 `flushEstimatedRPE()` 를 모든 exit path에서 호출:

- `handleRestComplete()` — 정상 rest 완료
- `finishCurrentExercise()` — 마지막 세트 후 운동 종료
- `addExtraSet()` — +1 세트 추가 전
- End Workout confirmation — 운동 조기 종료

### Critical: Snapshot Timing

`completeSet()` 호출 전에 `completedSets` snapshot을 캡처해야 한다.
호출 후 캡처하면 현재 세트가 자신의 1RM 추정에 포함되어 1RM이 과대평가된다.

## Prevention

- Watch에서 세트 데이터를 2단계로 기록할 때 (complete → record metadata) 모든 exit path에서 flush를 보장할 것
- 자기 자신을 포함하는 추정/계산에서는 반드시 snapshot timing을 확인할 것
- Stateless estimator는 `enum` + `static func` 패턴 사용 (struct 인스턴스 불필요)
