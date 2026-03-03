---
tags: [rest-time, template, prefill, workout, previous-session]
date: 2026-03-03
category: plan
status: draft
---

# Plan: Template Exercise Rest Time Prefill

## Summary

운동 세션의 rest timer에 이전 세션 기록 기반 prefill을 적용한다.
- **처음**: 템플릿 `restDuration` → 글로벌 설정 fallback
- **이후**: 이전 세션에서 사용한 타이머 값 유지

우선순위 체인: `이전 세션 rest time` > `TemplateEntry.restDuration` > `WorkoutDefaults.restSeconds`

## Affected Files

| 파일 | 변경 | 영향도 |
|------|------|--------|
| `DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift` | `EditableSet`, `PreviousSetInfo` 확장, `resolveRestDuration()` 추가, `createValidatedRecord()` 수정 | High |
| `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | `startRest()` prefill, `finishRest()` 캡처, init에 `templateRestDuration` 추가 | High |
| `DUNE/Presentation/Exercise/ExerciseStartView.swift` | `templateRestDuration` 파라미터 전달 | Low |
| `DUNE/Presentation/Exercise/ExerciseView.swift` | `startFromTemplate()` 에서 `restDuration` 캡처 | Low |
| `DUNEWatch/Managers/WorkoutManager.swift` | `CompletedSetData`에 `restDuration` 추가 | Medium |
| `DUNEWatch/Views/MetricsView.swift` | rest timer total 캡처, within-session carry-forward | Medium |
| `DUNEWatch/Views/RestTimerView.swift` | `onComplete`/`onSkip` 콜백에 `totalSeconds` 전달 | Medium |
| `DUNEWatch/Views/SessionSummaryView.swift` | `sendWorkoutToPhone()` 매핑에 `restDuration` 추가 | Low |
| `DUNE/Domain/Models/WatchConnectivityModels.swift` | `WatchSetData`에 `restDuration` 추가 | Low |
| `DUNETests/WorkoutSessionViewModelTests.swift` | rest time prefill 테스트 추가 | Medium |

## Implementation Steps

### Step 1: ViewModel 모델 확장

**파일**: `WorkoutSessionViewModel.swift`

1-1. `EditableSet`에 `restDuration: TimeInterval?` 필드 추가
```swift
struct EditableSet: Identifiable {
    // ... existing fields ...
    var restDuration: TimeInterval? = nil  // rest timer total (including +30s)
}
```

1-2. `PreviousSetInfo`에 `restDuration: TimeInterval?` 필드 추가
```swift
struct PreviousSetInfo: Sendable {
    let weight: Double?
    let reps: Int?
    let duration: TimeInterval?
    let distance: Double?
    let restDuration: TimeInterval?  // NEW
}
```

1-3. `WorkoutSessionDraft.DraftSet`에 `restDuration: TimeInterval?` 추가 (crash recovery)

1-4. `WorkoutSessionViewModel`에 `var templateRestDuration: TimeInterval?` 프로퍼티 추가

### Step 2: ViewModel 로직 수정

**파일**: `WorkoutSessionViewModel.swift`

2-1. `loadPreviousSets()`에서 `restDuration` 매핑:
```swift
previousSets = lastSession.completedSets.map { set in
    PreviousSetInfo(
        weight: set.weight,
        reps: set.reps,
        duration: set.duration,
        distance: set.distance,
        restDuration: set.restDuration  // NEW
    )
}
```

2-2. 새 메서드 `resolveRestDuration(forSetAt:)` 추가:
```swift
func resolveRestDuration(forSetAt index: Int) -> TimeInterval {
    // 1. 이전 세션의 해당 세트 rest time
    let setNumber = sets[index].setNumber
    if let prevRest = previousSetInfo(for: setNumber)?.restDuration {
        return prevRest
    }
    // 2. 템플릿 운동별 override
    if let templateRest = templateRestDuration {
        return templateRest
    }
    // 3. 글로벌 설정
    return defaultRestSeconds
}
```

2-3. `createValidatedRecord()`에서 `restDuration` 전달:
```swift
let workoutSet = WorkoutSet(
    // ... existing params ...
    restDuration: editableSet.restDuration,  // NEW
    isCompleted: true
)
```

2-4. Draft save/restore에 `restDuration` 포함

### Step 3: iOS View 수정

**파일**: `WorkoutSessionView.swift`

3-1. init에 optional `templateRestDuration` 파라미터 추가:
```swift
init(exercise: ExerciseDefinition, templateRestDuration: TimeInterval? = nil) {
    // ... existing init ...
    // Set template rest duration on viewModel
}
```
viewModel 생성 후 `viewModel.templateRestDuration = templateRestDuration` 설정

3-2. `startRest()` 수정 — `resolveRestDuration` 사용:
```swift
private func startRest() {
    let seconds = Int(viewModel.resolveRestDuration(forSetAt: currentSetIndex))
    restTotalSeconds = seconds
    restSecondsRemaining = seconds
    showRestTimer = true
    startRestCountdown()
}
```

3-3. `finishRest()` 수정 — 완료된 세트에 rest timer total 캡처:
```swift
private func finishRest() {
    // Capture rest timer value for the completed set (before advancing)
    viewModel.sets[currentSetIndex].restDuration = TimeInterval(restTotalSeconds)

    restTimerTask?.cancel()
    restTimerTask = nil
    showRestTimer = false
    restTimerCompleted += 1
    currentSetIndex += 1
    prefillCurrentSet()
}
```

### Step 4: 템플릿 → 세션 연결

**파일**: `ExerciseView.swift`, `ExerciseStartView.swift`

4-1. `ExerciseView`에 `@State private var templateRestDuration: TimeInterval?` 추가

4-2. `startFromTemplate()`에서 `templateRestDuration = firstEntry.restDuration` 캡처

4-3. Quick Start 경로 (`selectedExercise = exercise`)에서 `templateRestDuration = nil` 리셋

4-4. `.sheet(item: $selectedExercise)` closure에서 `ExerciseStartView(exercise:, templateRestDuration:)` 전달

4-5. `ExerciseStartView`에 `var templateRestDuration: TimeInterval?` 추가, `WorkoutSessionView(exercise:, templateRestDuration:)` 전달

### Step 5: Watch — RestTimerView 콜백 확장

**파일**: `RestTimerView.swift`

5-1. 콜백 시그니처 변경:
```swift
// Before
let onComplete: () -> Void
let onSkip: () -> Void

// After
let onComplete: (_ timerTotal: TimeInterval) -> Void
let onSkip: (_ timerTotal: TimeInterval) -> Void
```

5-2. `timerFinished()` 에서 `onComplete(TimeInterval(totalSeconds))` 호출

5-3. Skip 버튼에서 `onSkip(TimeInterval(totalSeconds))` 호출

### Step 6: Watch — CompletedSetData 확장

**파일**: `WorkoutManager.swift`

6-1. `CompletedSetData`에 `restDuration: TimeInterval?` 추가:
```swift
struct CompletedSetData: Codable, Sendable {
    let setNumber: Int
    let weight: Double?
    let reps: Int?
    let completedAt: Date
    var restDuration: TimeInterval?  // NEW: rest timer total after this set
}
```

6-2. `completeSet()` 수정 — `restDuration` 파라미터 추가 또는 별도 setter

### Step 7: Watch — MetricsView 수정

**파일**: `MetricsView.swift`

7-1. `@State private var lastRestTimerTotal: TimeInterval?` 추가

7-2. `RestTimerView` 콜백에서 `lastRestTimerTotal` 캡처 + `handleRestComplete()` 호출

7-3. `handleRestComplete()` 에서 이전 세트의 `CompletedSetData`에 `restDuration` 기록

7-4. `currentRestDuration` 수정 — within-session carry-forward:
```swift
private var currentRestDuration: TimeInterval {
    // 1. 같은 운동의 이전 세트에서 사용한 rest time
    if let lastRest = lastRestTimerTotal { return lastRest }
    // 2. Template entry override
    if let entryRest = workoutManager.currentEntry?.restDuration { return entryRest }
    // 3. Global default
    return WatchConnectivityManager.shared.globalRestSeconds
}
```

7-5. 운동 전환 시 `lastRestTimerTotal = nil` 리셋 (`onChange(of: currentExerciseIndex)`)

### Step 8: Watch DTO — WatchSetData 확장

**파일**: `WatchConnectivityModels.swift`, `SessionSummaryView.swift`

8-1. `WatchSetData`에 `restDuration: TimeInterval?` 추가

8-2. `SessionSummaryView.sendWorkoutToPhone()`에서 `CompletedSetData.restDuration` → `WatchSetData.restDuration` 매핑

### Step 9: 테스트 작성

**파일**: `DUNETests/WorkoutSessionViewModelTests.swift`

9-1. `loadPreviousSets()`가 `restDuration`을 `PreviousSetInfo`에 포함하는지 검증

9-2. `resolveRestDuration(forSetAt:)` 우선순위 체인 검증:
- 이전 세션 rest 있는 경우 → 이전 값 반환
- 이전 세션 없고 templateRestDuration 있는 경우 → 템플릿 값 반환
- 둘 다 없는 경우 → defaultRestSeconds 반환

9-3. `createValidatedRecord()`가 `restDuration`을 `WorkoutSet`에 포함하는지 검증

9-4. Draft save/restore 시 `restDuration` 보존 검증

## 주의사항

- `WorkoutSet.restDuration`은 기존 `@Model` 스키마에 이미 존재 → 마이그레이션 불필요
- `CompletedSetData`는 `Codable` → 필드 추가는 optional이므로 하위 호환
- `WatchSetData`도 `Codable` → optional 필드 추가는 하위 호환
- Watch DTO 변경 시 양쪽 target 동기화 필수 (Correction #69, #138)
- `restTotalSeconds` 저장 (실제 경과 시간이 아닌 타이머 설정값 + 조정값)
- CompoundWorkoutView는 이 scope에서 제외 (별도 작업)
