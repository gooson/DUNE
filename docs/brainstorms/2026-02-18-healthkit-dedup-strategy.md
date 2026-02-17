---
tags: [healthkit, deduplication, workout, sync, data-integrity]
date: 2026-02-18
category: brainstorm
status: draft
---

# Brainstorm: HealthKit 다중 소스 데이터 중복 처리

## Problem Statement

앱에서 운동을 기록하면 **SwiftData**(세트/무게/횟수 등 상세 데이터)와 **HealthKit**(시간/칼로리 요약)에 동시 저장된다. 이후 HealthKit에서 운동 목록을 가져오면 **같은 운동이 앱 UI에 2번 표시**되는 중복 문제가 발생한다.

또한 Apple Watch Workout 앱이나 다른 피트니스 앱에서 기록한 외부 운동도 HealthKit을 통해 들어오는데, 이것은 요약 정보만 있어서 앱의 상세 운동 기록과 성격이 다르다.

```
현재 문제:
┌─────────────────────────────────────────────────────────┐
│  Activity / Exercise 화면                                │
│                                                         │
│  [1] 벤치프레스 60kg 3x12  ← SwiftData (상세)           │
│  [2] Strength Training 45min ← HealthKit (같은 운동!)    │
│  [3] Running 30min          ← HealthKit (Watch 기록)     │
│                                                         │
│  → [1]과 [2]가 같은 운동인데 중복 표시됨                   │
└─────────────────────────────────────────────────────────┘
```

## Target Users

- Dailve 앱 사용자 (iPhone + Apple Watch 조합)
- 앱에서 운동 기록 + Watch Workout 앱도 병행 사용하는 사용자

## Success Criteria

1. **앱에서 기록한 운동이 UI에 1번만 표시**되어야 함 (SwiftData 상세 버전만)
2. **외부 HealthKit 운동**(Watch 등)은 Activity 탭에서 참조용으로만 표시
3. Steps/Activity 데이터가 과다 집계되지 않아야 함

## Current Architecture

### 데이터 흐름

```
앱 내 운동 기록:
  User Input → SwiftData (ExerciseRecord + WorkoutSet[])
                  ↓ (fire-and-forget Task)
               HealthKit (HKWorkout: 시간, 칼로리만)
                  ↓ (healthKitWorkoutID 저장)
               ExerciseRecord.healthKitWorkoutID = HKWorkout.uuid

외부 운동 (Watch Workout앱 등):
  HealthKit (HKWorkout) → WorkoutQueryService → UI에 요약 표시
```

### 기존 연결 메커니즘

| 필드 | 위치 | 역할 |
|------|------|------|
| `healthKitWorkoutID` | ExerciseRecord (SwiftData) | HKWorkout UUID 저장 |
| `isFromHealthKit` | ExerciseRecord (SwiftData) | 소스 구분 플래그 |
| `sourceRevision.source.bundleIdentifier` | HKWorkout | 기록한 앱 식별 |

**현재 gap**: `healthKitWorkoutID`가 존재하지만 화면 표시 시 **필터링에 사용되지 않음**.

### SwiftData에만 있는 데이터 (HealthKit에 없음)

- 세트별 무게, 횟수, 타입 (warmup/working/drop/failure)
- 세트별 휴식 시간, 거리, 강도
- 운동 정의 ID (exerciseDefinitionID)
- 주동근/보조근 그룹
- 사용 장비
- 메모 (500자)

## Proposed Approach

### 1. 앱 운동 중복 제거 (P1 - 필수)

**전략**: HealthKit 목록에서 앱이 만든 운동을 제외

```swift
// ExerciseViewModel 또는 ActivityViewModel에서:
let appWorkoutIDs: Set<String> = Set(
    exerciseRecords.compactMap(\.healthKitWorkoutID)
)

let externalWorkouts = healthKitWorkouts.filter { workout in
    !appWorkoutIDs.contains(workout.id)
}
```

**대안 비교**:

| 접근 | 장점 | 단점 |
|------|------|------|
| **A. healthKitWorkoutID 매칭** | 이미 인프라 있음, 정확함 | 쓰기 실패 시 ID 없음 |
| B. source bundleIdentifier 필터 | 쿼리 시점에서 필터 가능 | 앱 번들ID 하드코딩 필요 |
| C. 시간 범위 겹침 체크 | 추가 필드 불필요 | 오탐 가능성 (같은 시간 다른 운동) |

**권장: A + B 혼합** — healthKitWorkoutID 매칭 우선, 없으면 bundleIdentifier로 fallback

### 2. 외부 운동 참조 표시 (P1 - 필수)

**전략**: 외부 HealthKit 운동은 Activity 탭에서 요약만 표시

- 이미 Activity 탭에 WorkoutSummary로 표시되고 있음
- 운동 기록(Exercise) 탭에서는 SwiftData 레코드만 표시
- 외부 운동에는 HealthKit 아이콘(❤️) 표시하여 구분

### 3. Steps 중복 확인 (P2 - 확인 필요)

**Apple의 자동 처리**: `HKStatisticsQuery`와 `HKStatisticsCollectionQuery`는 기본적으로 `mostRecentQuantityDateInterval` 옵션을 사용하여 **동일 시간대의 중복 소스를 자동 제거**한다.

- 확인 항목: 현재 Steps 쿼리가 `HKStatisticsQuery`를 사용하는지 확인
- 만약 `HKSampleQuery`로 개별 샘플을 가져오고 있다면 합산 시 중복 발생 가능

## Constraints

- **HealthKit 쓰기 실패 가능**: 네트워크/권한 문제로 `healthKitWorkoutID`가 null일 수 있음
- **외부 앱 식별**: 모든 앱의 bundleIdentifier를 알 수 없음 (자체 앱만 식별 가능)
- **CloudKit 전파**: SwiftData 변경은 CloudKit으로 전 디바이스에 전파되므로 일관된 처리 필요
- **시간 제약**: MVP 필수 기능이므로 과도한 설계 없이 실용적 접근

## Edge Cases

1. **HealthKit 쓰기 실패**: healthKitWorkoutID가 nil인 앱 운동 → bundleIdentifier fallback으로 처리
2. **HealthKit 권한 거부**: HealthKit 읽기 권한 없을 때 → SwiftData 데이터만 표시 (이미 처리됨)
3. **같은 시간에 다른 운동**: 벤치프레스 30분 + 러닝 30분 동시 기록 → ID 매칭이므로 문제 없음
4. **앱 재설치**: SwiftData는 CloudKit에서 복원되지만 healthKitWorkoutID는 유지됨
5. **여러 디바이스에서 기록**: iPhone에서 기록 + Watch에서 동일 운동 기록 → 별개 운동으로 처리 (사용자 의도)

## Scope

### MVP (Must-have)
- [ ] 앱 운동의 HealthKit 중복 필터링 (`healthKitWorkoutID` 매칭)
- [ ] Exercise 탭: SwiftData 레코드만 표시 (HealthKit 운동 미포함)
- [ ] Activity 탭: 외부 HealthKit 운동만 표시 (앱 운동은 SwiftData에서)
- [ ] bundleIdentifier fallback 필터링 (healthKitWorkoutID 없는 경우)

### Nice-to-have (Future)
- [ ] 외부 HealthKit 운동에 세트/무게 보강 기능 (import → edit)
- [ ] 사용자가 선호 소스를 설정할 수 있는 Settings UI
- [ ] Steps/Activity의 소스별 breakdown 표시
- [ ] HealthKit 쓰기 실패 시 retry 메커니즘

## Open Questions

1. ~~Steps가 `HKStatisticsQuery`를 사용하는지 확인 필요~~ → `/plan`에서 코드 확인
2. Activity 탭에서 외부 운동과 앱 운동을 어떻게 시각적으로 구분할지 (현재 ❤️ 아이콘)
3. healthKitWorkoutID 쓰기 실패율이 실제로 얼마나 되는지

## Next Steps

- [ ] `/plan healthkit-dedup` 으로 구현 계획 생성
- [ ] Steps 쿼리 방식 확인 (HKStatisticsQuery vs HKSampleQuery)
- [ ] ExerciseViewModel / ActivityViewModel의 데이터 병합 로직 수정 계획
