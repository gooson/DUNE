---
tags: [watch, healthkit, sync, workout, WatchConnectivity]
date: 2026-03-29
category: plan
status: draft
---

# Watch 운동 HealthKit 링크 누락 수정

## Problem

Watch에서 기록한 운동(사이드 레터럴 레이즈)이 Activity 리스트에서는 보이지만:
1. HealthKit 싱크 마크(Apple 로고 배지)가 없음
2. 상세 화면에서 심박수, 칼로리 등 HealthKit 데이터가 누락됨

## Root Cause Analysis

**두 가지 데이터 경로의 race condition**:

1. **Watch → iPhone (WatchConnectivity)**: 빠름 (즉시 또는 수초)
   - `sendWorkoutCompletion()` → iPhone `onWorkoutReceived` → ExerciseRecord 생성
   - **문제**: `WatchWorkoutUpdate`에 `healthKitWorkoutID` 필드가 없음
   - iPhone에서 만든 ExerciseRecord에 `healthKitWorkoutID = nil`

2. **Watch → iPhone (CloudKit)**: 느림 (수초~수분)
   - Watch SwiftData ExerciseRecord에는 `healthKitWorkoutID`가 설정되어 있음
   - CloudKit sync로 iPhone에 도착하지만, WC 경로가 먼저 생성한 record와 **dedup** 충돌
   - CloudKit record가 무시되거나, merge 시 `healthKitWorkoutID`가 유실됨

**결과**: iPhone ExerciseRecord에 `healthKitWorkoutID`가 없어서:
- `UnifiedWorkoutRow.sourceBadge`에 Apple 로고 미표시
- `ExerciseSessionDetailView.hasHealthKitLink = false` → 심박수 로드 안함

## Solution

### Step 1: WatchWorkoutUpdate에 healthKitWorkoutID 추가

**파일**: `DUNE/Domain/Models/WatchConnectivityModels.swift`

```swift
struct WatchWorkoutUpdate: Codable, Sendable {
    let exerciseID: String
    let exerciseName: String
    var completedSets: [WatchSetData]
    let startTime: Date
    let endTime: Date?
    var heartRateSamples: [WatchHeartRateSample]
    var rpe: Int?
    var healthKitWorkoutID: String?  // NEW: HK workout UUID from Watch
}
```

### Step 2: Watch에서 sendWorkoutToPhone()에 HK UUID 전달

**파일**: `DUNEWatch/Views/SessionSummaryView.swift`

`sendWorkoutToPhone()` 호출을 `saveIndividualHealthKitWorkouts()` 이후로 이동 (이미 이 순서임).
`perExerciseIDs`를 `sendWorkoutToPhone(perExerciseHealthKitIDs:)`에 전달.

```swift
private func sendWorkoutToPhone(perExerciseHealthKitIDs: [Int: String]) {
    // ... existing code ...
    let update = WatchWorkoutUpdate(
        exerciseID: entry.exerciseDefinitionID,
        exerciseName: entry.exerciseName,
        completedSets: watchSets,
        startTime: startDate,
        endTime: endDate,
        heartRateSamples: [],
        rpe: effort,
        healthKitWorkoutID: perExerciseHealthKitIDs[exerciseIndex]  // NEW
    )
    WatchConnectivityManager.shared.sendWorkoutCompletion(update)
}
```

### Step 3: iPhone에서 ExerciseRecord 생성 시 healthKitWorkoutID 설정

**파일**: `DUNE/App/DUNEApp.swift`

`wireWatchWorkoutReceiver`에서 ExerciseRecord 생성 시 `healthKitWorkoutID` 전달:

```swift
let record = ExerciseRecord(
    date: update.startTime,
    exerciseType: update.exerciseName,
    duration: max(0, duration),
    healthKitWorkoutID: update.healthKitWorkoutID,  // NEW
    exerciseDefinitionID: update.exerciseID,
    ...
)
```

### Step 4: Bulk Sync에도 healthKitWorkoutID 포함

**파일**: `DUNEWatch/WatchConnectivityManager.swift`

`handleBulkSyncRequest()` 에서 Watch ExerciseRecord → WatchWorkoutUpdate 변환 시 `healthKitWorkoutID` 포함 확인.

## Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Domain/Models/WatchConnectivityModels.swift` | `WatchWorkoutUpdate`에 `healthKitWorkoutID` 필드 추가 |
| `DUNEWatch/Views/SessionSummaryView.swift` | `sendWorkoutToPhone()`에 HK UUID 전달 |
| `DUNE/App/DUNEApp.swift` | `wireWatchWorkoutReceiver`에서 `healthKitWorkoutID` 설정 |
| `DUNEWatch/WatchConnectivityManager.swift` | `handleBulkSyncRequest`에서 HK ID 포함 확인 |

## Test Strategy

1. **유닛 테스트**: `WatchWorkoutUpdate` encoding/decoding에 `healthKitWorkoutID` 포함 확인
2. **통합 확인**: Watch에서 운동 기록 후 iPhone 리스트에서 Apple 배지 표시 확인
3. **상세 확인**: 운동 상세 진입 시 심박수 차트 로드 확인

## Risks & Edge Cases

1. **Backward compatibility**: 구버전 Watch가 `healthKitWorkoutID` 없이 보내도 `nil`로 처리 (optional field)
2. **HKWorkout 생성 실패**: Watch에서 HKWorkout 생성 실패 시 `perExerciseIDs[index]`가 nil → `healthKitWorkoutID = nil`로 graceful 처리
3. **CloudKit sync race**: WC 경로가 먼저 도착해도 `healthKitWorkoutID`가 설정되므로 문제 없음. CloudKit 경로가 나중에 도착하면 SwiftData가 merge
4. **Cardio 경로**: Cardio는 이미 `saveCardioRecord(healthKitWorkoutID:)`에서 설정 중 → WC sendWorkoutToPhone()에서도 동일하게 전달 필요

## Fidelity Level

F2: 명확한 범위, 4개 파일 수정, 하위 호환성 유지
