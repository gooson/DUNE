---
tags: [watch, healthkit, workout, template, hkworkoutbuilder]
date: 2026-03-04
category: solution
status: implemented
---

# Watch 템플릿 운동 개별 HealthKit 기록

## Problem

Apple Watch에서 템플릿(루틴)에 등록된 운동 2개를 차례대로 진행하면, `HKLiveWorkoutBuilder`가 전체 세션을 단일 "Weight Training" `HKWorkout`으로 생성. 개별 운동이 HealthKit에 각각 기록되지 않음.

### Root Cause

- `HKWorkoutSession` → `HKLiveWorkoutBuilder` → `finishWorkout()` = 1 HKWorkout
- 모든 `ExerciseRecord`가 동일한 `healthKitWorkoutUUID` 참조
- HealthKit의 1 session = 1 workout 모델 제약

## Solution

### Strategy: Discard + Rebuild

1. **Strength 모드**: `HKLiveWorkoutBuilder.discardWorkout()`으로 통합 워크아웃 생성 방지
2. **개별 저장**: `HKWorkoutBuilder` (non-live)로 운동별 HKWorkout 생성
3. **Cardio 모드**: 기존 flow 유지 (1 session = 1 workout)

### Key Design Decisions

| 결정 | 이유 |
|------|------|
| `discardWorkout()` 사용 | 삭제보다 생성 자체를 방지하는 것이 안전 |
| 순차 startDate 오프셋 | 동일 시간대 HKWorkout은 Apple Health dedup 위험 |
| TaskGroup 병렬 저장 | N개 운동 순차 저장 시 Watch 하드웨어에서 지연 발생 |
| 칼로리/시간 비례 배분 | iOS 템플릿 워크아웃과 동일 로직 |

### Architecture

```
Watch Strength Template Session:
─────────────────────────────────

WorkoutManager.startStrengthSession()
    ↓
HKWorkoutSession + HKLiveWorkoutBuilder (live HR/calories 수집)
    ↓
Session ends → builder.endCollection()
    ↓
builder.discardWorkout() ← 통합 HKWorkout 생성 안 함
    ↓
SessionSummaryView:
    ↓
For each exercise (parallel via TaskGroup):
    WatchWorkoutWriter.saveIndividualWorkout()
        → HKWorkoutBuilder (non-live)
        → ExerciseCategory.hkActivityType() (정확한 활동 유형)
        → Sequential time window (non-overlapping)
        → finishWorkout() → 개별 UUID
    ↓
ExerciseRecord.healthKitWorkoutID = 개별 UUID
```

### Files Changed

| File | Change |
|------|--------|
| `DUNEWatch/Managers/WatchWorkoutWriter.swift` | **신규** - 개별 HKWorkout 생성 |
| `DUNEWatch/Managers/WorkoutManager.swift` | Strength: discardWorkout() |
| `DUNEWatch/Views/SessionSummaryView.swift` | 개별 HKWorkout 저장 + UUID 연결 |
| `DUNE/project.yml` | ExerciseCategory+HealthKit.swift Watch 공유 |

## Prevention

- Watch 워크아웃 관련 변경 시 HealthKit 개별 기록 여부 확인
- Correction Log에 관련 항목 추가
