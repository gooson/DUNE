---
tags: [watch, healthkit, workout, template, bug-fix]
date: 2026-03-04
category: plan
status: draft
---

# Watch 템플릿 운동 HealthKit 통합 기록 버그 수정

## Problem

Apple Watch에서 템플릿(루틴)에 등록된 운동 2개를 차례대로 진행하면, 개별 운동이 HealthKit에 각각 기록되지 않고 하나의 "Weight Training" 워크아웃으로 통합 기록됨.

### Root Cause

`HKLiveWorkoutBuilder`가 세션 종료 시 `finishWorkout()`으로 단일 `HKWorkout`을 생성하고, 모든 `ExerciseRecord`가 동일한 `healthKitWorkoutUUID`를 참조함. HealthKit은 1 session = 1 workout 모델.

### iOS vs Watch 차이

- **iOS**: `WorkoutHealthKitWriter`가 각 `ExerciseRecord`마다 별도 `HKWorkoutBuilder`(non-live)로 개별 `HKWorkout` 생성
- **Watch**: `HKLiveWorkoutBuilder`가 전체 세션을 단일 `HKWorkout`으로 생성

## Solution

Strength 템플릿 워크아웃에서:
1. `HKLiveWorkoutBuilder.finishWorkout()` 대신 `discardWorkout()`으로 통합 워크아웃 생성을 방지
2. 각 운동별로 `HKWorkoutBuilder`(non-live)를 사용해 개별 `HKWorkout` 생성
3. 각 `ExerciseRecord`가 자신만의 `healthKitWorkoutID`를 가짐

## Affected Files

| File | Change |
|------|--------|
| `DUNE/project.yml` | Watch target에 `ExerciseCategory+HealthKit.swift` 공유 추가 |
| `DUNEWatch/Managers/WorkoutManager.swift` | Strength 모드: discard builder workout |
| `DUNEWatch/Managers/WatchWorkoutWriter.swift` | **신규** - 개별 HKWorkout 생성 |
| `DUNEWatch/Views/SessionSummaryView.swift` | 개별 HKWorkout 생성 후 각 record에 UUID 연결 |

## Implementation Steps

1. `project.yml`에 `ExerciseCategory+HealthKit.swift` 공유 소스 추가
2. `WatchWorkoutWriter` 생성 - iOS `WorkoutWriteService` 패턴 참조
3. `WorkoutManager` 수정 - strength 모드에서 builder workout discard
4. `SessionSummaryView` 수정 - 개별 workout 생성 및 UUID 연결
5. 빌드 검증

## Design Decisions

- **Cardio 모드 변경 없음**: 카디오는 1세션=1운동이므로 기존 flow 유지
- **`discardWorkout()` 사용**: 통합 workout 삭제보다 생성 자체를 방지하는 것이 안전
- **칼로리 비례 배분**: 전체 칼로리를 활성 운동 수로 나누어 배분 (iOS 동일 로직)
