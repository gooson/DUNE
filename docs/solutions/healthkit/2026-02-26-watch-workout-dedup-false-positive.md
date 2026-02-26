---
tags: [healthkit, watch, dedup, isFromThisApp, bundle-id, workout]
category: healthkit
date: 2026-02-26
severity: critical
related_files:
  - DUNE/Presentation/Shared/Extensions/WorkoutSummary+Dedup.swift
  - DUNE/Data/HealthKit/WorkoutQueryService.swift
  - DUNE/Presentation/Activity/ActivityViewModel.swift
related_solutions: []
---

# Solution: Watch Workout Dedup False-Positive

## Problem

Watch 앱으로 기록한 근육 운동이 Apple Health에는 존재하지만 앱의 Recent Workouts에 표시되지 않음.

### Symptoms

- Watch로 기록한 `traditionalStrengthTraining` 워크아웃이 Recent Workouts에서 완전히 사라짐
- 이전(어제까지) 워크아웃은 정상 표시, 오늘 워크아웃만 안 보임
- Apple Health 앱에서는 해당 워크아웃이 정상 표시됨

### Root Cause

**2가지 문제의 조합:**

1. **`isFromThisApp` 판정 오류**: Watch companion 앱은 parent iOS 앱의 bundle ID(`com.raftel.dailve`)를 공유. `HKWorkout.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier` 비교에서 Watch 워크아웃이 `isFromThisApp=true`로 판정됨.

2. **Dedup fallback의 과잉 필터링**: `isFromThisApp=true`이면 무조건 필터링하는 fallback 로직이 ExerciseRecord 존재 여부를 확인하지 않음. WatchConnectivity로 ExerciseRecord가 아직 생성되지 않은 워크아웃은 HK 경로와 SwiftData 경로 **양쪽 모두에서 제거**되어 완전히 보이지 않음.

**부수 문제 — `isLoading` stuck-at-true:**
`Task.isCancelled` guard가 `isLoading = false` 없이 return하면 이후 모든 데이터 로드 차단. `.task(id:)` 재실행 시 race condition으로 발생.

### 이전 워크아웃이 정상인 이유

이전 워크아웃들은 WatchConnectivity를 통해 ExerciseRecord가 생성되어 `healthKitWorkoutID`로 연결됨 → primary dedup(`appLinkedHKIDs.contains`)에서 정상 필터 → SwiftData 경로로 표시. 오늘 워크아웃은 ExerciseRecord가 아직 없어서 primary dedup 통과 → fallback(`isFromThisApp`)에서 제거.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `WorkoutSummary+Dedup.swift` | `isFromThisApp` fallback에 type+date proximity 조건 추가 | Watch 워크아웃 중 ExerciseRecord 없는 것 보존 |
| `ActivityViewModel.swift` | `defer { isLoading = false }` 추가, dead `loadTask` 제거 | 모든 exit path에서 isLoading 리셋 보장 |
| `TrainingVolumeViewModel.swift` | 동일 패턴 수정 | 동일 버그 |
| `ExerciseTypeDetailViewModel.swift` | 동일 패턴 수정 | 동일 버그 |

### Key Code

```swift
// WorkoutSummary+Dedup.swift — 수정된 dedup 로직
func filteringAppDuplicates(against records: [ExerciseRecord]) -> [WorkoutSummary] {
    let appLinkedHKIDs: Set<String> = Set(
        records.compactMap { id in
            guard let id = id.healthKitWorkoutID, !id.isEmpty else { return nil }
            return id
        }
    )

    return filter { workout in
        // Primary: exact HK ID match
        if appLinkedHKIDs.contains(workout.id) { return false }
        // Fallback: type + date proximity (±2 min) — not isFromThisApp alone
        if workout.isFromThisApp {
            let hasProbableMatch = records.contains { record in
                record.exerciseType == workout.activityType.rawValue
                    && abs(record.date.timeIntervalSince(workout.date)) < 120
            }
            if hasProbableMatch { return false }
        }
        return true
    }
}
```

```swift
// ActivityViewModel.swift — isLoading 리셋 보장
func loadActivityData() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }  // ALL exit paths
    // ... async work ...
    guard !Task.isCancelled else { return }  // defer still fires
    // ... state updates ...
}
```

## Prevention

### Checklist Addition

- [ ] Watch 워크아웃의 `sourceRevision.source.bundleIdentifier`가 parent iOS 앱 bundle ID와 동일할 수 있음을 인지
- [ ] Dedup 로직 수정 시 "ExerciseRecord 없는 Watch 워크아웃" 시나리오 테스트
- [ ] `isLoading`/`isSaving` guard 패턴에서 모든 exit path의 리셋 여부 확인

### Rule Addition

`.claude/rules/healthkit-patterns.md`에 추가 필요:

```
## Watch Workout Bundle ID

Watch companion 앱이 HealthKit에 저장한 워크아웃은 parent iOS 앱의 bundle ID를 사용.
`isFromThisApp` 판정만으로 Watch vs iOS를 구분할 수 없음.
Dedup 시 `isFromThisApp`을 단독 필터 조건으로 사용 금지.
```

## Lessons Learned

1. **Watch companion 앱은 HealthKit에서 parent bundle ID를 공유한다** — iOS 앱과 구분 불가
2. **Dedup fallback은 보수적이어야 한다** — "보이지 않는 것"이 "중복 표시"보다 사용자 경험에 심각
3. **`isLoading` guard + `Task.isCancelled` 조합은 defer 필수** — Void async 함수에서 defer는 안전하며, 모든 exit path를 커버하는 유일한 보장 수단
4. **진단 로그가 즉시 원인을 밝힌다** — 추측보다 핵심 경로에 print 추가가 훨씬 효율적
