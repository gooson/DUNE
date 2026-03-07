---
tags: [healthkit, watch, workout, title, metadata, strength]
date: 2026-03-07
category: plan
status: implemented
---

# HealthKit Strength Workout Title Fix

## Problem Statement

근력 운동이 개별 운동명으로 저장되더라도, 앱이 HealthKit 워크아웃을 읽을 때 제목을 다시 `activityType.typeName`으로 덮어써서 `"Weight Training"` / `"웨이트 트레이닝"`으로만 보인다. 이 때문에 CloudKit으로 동기화된 `ExerciseRecord`가 아직 도착하지 않았거나, HealthKit-only 경로가 먼저 렌더링되는 화면에서는 모든 근력 운동이 동일한 이름처럼 보인다.

## Root Cause

1. `WorkoutWriteService`와 `WatchWorkoutWriter`가 HealthKit에 운동명을 메타데이터로 기록하지 않는다.
2. `WorkoutQueryService`와 `BackgroundNotificationEvaluator`가 HealthKit에서 제목을 읽지 않고 `activityType.typeName`만 사용한다.
3. `ExerciseListItem`/`HealthKitWorkoutDetailView`가 HealthKit row에서 저장된 제목보다 `activityType.displayName`을 우선한다.

## Implementation Steps

1. 공통 HealthKit workout title helper를 기존 shared HealthKit mapping 파일에 추가한다.
2. iPhone/Watch HealthKit writer가 개별 운동명을 custom metadata key로 저장하도록 수정한다.
3. HealthKit reader가 metadata title을 우선 사용해 `WorkoutSummary.type`을 구성하도록 수정한다.
4. 리스트/상세 UI가 `WorkoutSummary.type` 기반 제목을 우선 노출하도록 수정한다.
5. metadata title resolution과 HealthKit row title 우선순위에 대한 회귀 테스트를 추가한다.

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Data/HealthKit/WorkoutActivityType+HealthKit.swift` | workout title metadata key + read/write helper 추가 |
| `DUNE/Data/HealthKit/WorkoutWriteService.swift` | iPhone HealthKit workout metadata 기록 |
| `DUNEWatch/Managers/WatchWorkoutWriter.swift` | Watch 개별 HKWorkout metadata 기록 |
| `DUNE/Data/HealthKit/WorkoutQueryService.swift` | HealthKit metadata title 읽기 |
| `DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift` | notification summary도 동일 title resolution 사용 |
| `DUNE/Presentation/Shared/Models/ExerciseListItem.swift` | HealthKit row가 stored/custom title을 먼저 사용 |
| `DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift` | 상세 화면 제목/편집 기본값 정정 |
| `DUNETests/WorkoutWriteServiceTests.swift` | metadata helper 회귀 테스트 |
| `DUNETests/ExerciseViewModelTests.swift` | HealthKit row displayName 회귀 테스트 |

## Testing Strategy

- Unit tests: workout title metadata write/read helper, HealthKit row displayName 우선순위
- Build/Test: `scripts/test-unit.sh --ios-only`
- Manual verification:
  - Watch strength template workout 2개 이상 저장 후 iPhone 리스트에 운동명별로 노출되는지 확인
  - HealthKit-only detail 화면 제목이 generic strength label 대신 운동명으로 노출되는지 확인
  - 기존 legacy workout은 계속 `Weight Training` fallback으로 보이는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 기존 legacy HKWorkout에는 metadata가 없어 제목이 nil | Low | Low | 기존 `activityType.typeName` fallback 유지 |
| UI가 raw English metadata를 그대로 노출할 수 있음 | Medium | Low | legacy/raw activity name은 localized mapping 후 custom title만 그대로 노출 |
| Watch target에서 helper 공유 누락 | Low | High | 이미 watch target에 포함된 shared HealthKit mapping 파일에 helper 추가 |
