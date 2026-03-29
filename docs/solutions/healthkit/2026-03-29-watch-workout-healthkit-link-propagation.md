---
tags: [watch, healthkit, WatchConnectivity, sync, dedup, healthKitWorkoutID]
date: 2026-03-29
category: healthkit
status: implemented
---

# Watch 운동 HealthKit 링크 WatchConnectivity 전파

## Problem

Watch에서 기록한 운동이 iPhone Activity 리스트에는 표시되지만:
- HealthKit 싱크 마크(Apple 로고 배지)가 없음
- 상세 화면에서 심박수, 칼로리 등 HealthKit 데이터가 누락됨

## Root Cause

Watch는 운동 완료 시 두 가지 경로로 데이터를 iPhone에 전달:

1. **WatchConnectivity** (즉시): `WatchWorkoutUpdate` DTO로 운동 데이터 전송 → iPhone이 ExerciseRecord 생성
2. **CloudKit** (지연): Watch SwiftData ExerciseRecord가 CloudKit으로 sync

Watch는 `saveIndividualHealthKitWorkouts()`로 HKWorkout을 생성하고 UUID를 Watch-side ExerciseRecord에 저장. 그러나 **WatchWorkoutUpdate DTO에 `healthKitWorkoutID` 필드가 없어서** WC 경로로 생성된 iPhone ExerciseRecord에는 HK 링크가 누락됨.

WC가 CloudKit보다 빨리 도착하므로, CloudKit record가 나중에 도착해도 WC record와 dedup 충돌로 무시됨.

## Solution

### 1. WatchWorkoutUpdate에 healthKitWorkoutID 추가

`DUNE/Domain/Models/WatchConnectivityModels.swift`:
```swift
struct WatchWorkoutUpdate: Codable, Sendable {
    // ... existing fields ...
    var healthKitWorkoutID: String?  // Watch-side HKWorkout UUID
}
```

Optional field → 구버전 Watch에서 보내도 `nil`로 graceful 처리.

### 2. Watch sendWorkoutToPhone()에 HK UUID 전달

`DUNEWatch/Views/SessionSummaryView.swift`:
- `sendWorkoutToPhone(perExerciseHealthKitIDs:)` 파라미터 추가
- `saveAndDismissAsync()`에서 `saveIndividualHealthKitWorkouts()` 결과를 전달

### 3. iPhone receiver에서 healthKitWorkoutID 설정

`DUNE/App/DUNEApp.swift`:
- `wireWatchWorkoutReceiver`에서 ExerciseRecord 생성 시 `healthKitWorkoutID` 전달

### 4. healthKitWorkoutID 기반 dedup 추가

CloudKit이 먼저 도착한 경우를 방어하기 위해 기존 date-window dedup 전에 `healthKitWorkoutID` 매칭 체크 추가.

### 5. Bulk sync에도 healthKitWorkoutID 포함

`DUNEWatch/WatchConnectivityManager.swift`:
- `handleBulkSyncRequest()`에서 ExerciseRecord → WatchWorkoutUpdate 변환 시 HK ID 포함

## Prevention

1. **Watch → iPhone 데이터 전달 시 항상 HK UUID 포함 확인**: 새 WC 메시지 타입 추가 시 HealthKit-linked 데이터는 UUID 전파 필수
2. **Dedup은 2단계**: HK UUID 매칭 (정확) → date-window 매칭 (폴백)
3. **WatchConnectivity DTO와 SwiftData 모델 필드 parity 검증**: 새 필드 추가 시 WC DTO에도 반영

## Affected Files

- `DUNE/Domain/Models/WatchConnectivityModels.swift`
- `DUNEWatch/Views/SessionSummaryView.swift`
- `DUNE/App/DUNEApp.swift`
- `DUNEWatch/WatchConnectivityManager.swift`
