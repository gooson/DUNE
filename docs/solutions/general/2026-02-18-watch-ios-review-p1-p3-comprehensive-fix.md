---
tags: [watch, ios, review, input-validation, cross-vm-coupling, deferred-sheet, state-caching, userdefaults, stale-data, magic-number]
category: general
date: 2026-02-18
severity: critical
related_files:
  - DailveWatch/Managers/WorkoutManager.swift
  - Dailve/Presentation/Exercise/WorkoutSessionView.swift
  - Dailve/Presentation/Exercise/WorkoutSessionViewModel.swift
  - Dailve/Presentation/Exercise/ExerciseStartView.swift
  - Dailve/Presentation/Shared/WorkoutDefaults.swift
  - Dailve/Presentation/Shared/Layouts/FlowLayout.swift
  - Dailve/Data/WatchConnectivity/WatchSessionManager.swift
  - DailveWatch/Views/MetricsView.swift
  - DailveWatch/Managers/RecentExerciseTracker.swift
  - DailveWatch/Views/QuickStartPickerView.swift
related_solutions:
  - 2026-02-16-six-perspective-review-application.md
  - 2026-02-17-second-review-validation-hardening.md
---

# Solution: Watch/iOS 6관점 리뷰 P1~P3 일괄 수정

## Problem

### Symptoms

iOS 워크아웃 세션 1-set-at-a-time 리디자인 + Watch 디자인 오버홀 후 6관점 리뷰에서 17건 발견:
- P1 (Critical): 1건 — Watch에서 입력 검증 없이 완료 세트 전송
- P2 (Important): 7건 — cross-VM 커플링, sheet 이중 트리거, magic number 등
- P3 (Minor): 9건 — UserDefaults stale 데이터, computed property 비용 등

### Root Cause

1. **입력 검증 누락**: Watch `WorkoutManager.completeSet()`이 weight/reps를 검증 없이 기록 → WatchConnectivity로 잘못된 값 전파 가능
2. **Cross-VM 커플링**: `ExerciseStartView`가 `WorkoutSessionViewModel.defaultSetCount`를 직접 참조 — ViewModel 간 불필요한 의존
3. **Sheet 이중 트리거**: `MetricsView`에서 `onAppear`와 `handleRestComplete()`가 동시에 `showInputSheet = true` 시도 시 SwiftUI sheet 충돌
4. **Stale UserDefaults**: `RecentExerciseTracker`가 삭제된 운동 ID를 영구 보관 → 무한 증가

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `WorkoutManager.swift` | weight 0-500, reps 0-1000 범위 검증 추가 | P1: WatchConnectivity 전 입력 검증 |
| `WorkoutManager.swift` | `effectiveTotalSets` bounds check | P3: index out of range 방어 |
| `WorkoutSessionView.swift` | `adjustDecimalValue`/`adjustIntValue`에 trim+isEmpty | P1: Correction #38 패턴 적용 |
| `WorkoutSessionView.swift` | +30s 버튼에 3600초 상한 | P2: 무한 증가 방지 |
| `WorkoutSessionView.swift` | magic number 12 → `maxProgressDots` 상수 | P3: 가독성 |
| `WorkoutSessionViewModel.swift` | `defaultSetCount` 제거 → `WorkoutDefaults.setCount` | P1: cross-VM 커플링 해소 |
| `WorkoutSessionViewModel.swift` | `loadPreviousSets`에 `guard !isSaving` | P2: 중복 실행 방지 |
| `ExerciseStartView.swift` | `WorkoutDefaults.setCount` 사용, FlowLayout 추출 | P1+P2 |
| `WorkoutDefaults.swift` (NEW) | `enum WorkoutDefaults { static let setCount = 5 }` | 공유 상수 |
| `FlowLayout.swift` (NEW) | Layout 프로토콜 구현 추출 | P2: 재사용 |
| `WatchSessionManager.swift` | `defaultSets: WorkoutDefaults.setCount` | P2: magic number 제거 |
| `MetricsView.swift` | `pendingInputSheet` + `onChange` 패턴 | P2: sheet 이중 트리거 방지 |
| `RecentExerciseTracker.swift` | Bundle prefix key, empty ID guard, stale purge | P3: 데이터 위생 |
| `QuickStartPickerView.swift` | `@State` 캐시 + `rebuildFilteredLists()` | P3: computed property 비용 |

### Key Code

**1. Watch 입력 검증 (P1)**

```swift
func completeSet(weight: Double?, reps: Int?) {
    let validatedWeight: Double? = weight.flatMap { (0...500).contains($0) ? $0 : nil }
    let validatedReps: Int? = reps.flatMap { (0...1000).contains($0) ? $0 : nil }
    // ...
}
```

**2. Deferred sheet 패턴 (P2)**

```swift
@State private var pendingInputSheet = false

.onChange(of: pendingInputSheet) { _, shouldShow in
    if shouldShow {
        pendingInputSheet = false
        showInputSheet = true
    }
}

// Rest 완료 후 — 직접 showInputSheet = true 대신
pendingInputSheet = true
```

**3. Cross-VM 커플링 해소 (P1)**

```swift
// Before: ExerciseStartView가 WorkoutSessionViewModel에 의존
Label("\(WorkoutSessionViewModel.defaultSetCount) sets", ...)

// After: 공유 enum으로 분리
enum WorkoutDefaults {
    static let setCount = 5
}
Label("\(WorkoutDefaults.setCount) sets", ...)
```

**4. UserDefaults stale purge (P3)**

```swift
static func sorted(_ exercises: [WatchExerciseInfo]) -> [WatchExerciseInfo] {
    var history = loadHistory()
    let validIDs = Set(exercises.map(\.id))
    let staleKeys = history.keys.filter { !validIDs.contains($0) }
    if !staleKeys.isEmpty {
        for key in staleKeys { history.removeValue(forKey: key) }
        UserDefaults.standard.set(history, forKey: key)
    }
    // ... sort logic
}
```

## Prevention

### Checklist Addition

- [ ] Watch에서 사용자 입력을 기록/전송하기 전에 도메인 범위 검증이 있는가?
- [ ] ViewModel의 static 프로퍼티를 다른 View에서 참조하고 있는가? → 공유 상수로 추출
- [ ] `showSheet = true`가 여러 경로에서 동시에 호출될 수 있는가? → deferred 패턴 사용
- [ ] UserDefaults에 ID 기반 데이터를 저장할 때 stale 정리 로직이 있는가?
- [ ] UserDefaults key에 bundle identifier prefix가 있는가?

### Rule Addition (if applicable)

**`watch-input-validation` 규칙 후보**: Watch에서 WatchConnectivity로 데이터 전송 전 반드시 범위 검증. iOS의 validation과 동일 수준 유지. 이미 Correction Log #22, #42에서 유사한 원칙이 있으므로 별도 규칙 파일 생성보다 기존 `input-validation.md` 규칙에 Watch 섹션을 추가하는 것이 적합.

## Lessons Learned

1. **Cross-target 상수는 첫 사용 시 공유 enum 추출**: `defaultSetCount`처럼 2곳 이상에서 쓰이는 상수가 특정 VM에 묶이면 불필요한 import chain 발생. `WorkoutDefaults` 같은 중립적 enum으로 시작하면 이후 확장이 쉬움

2. **SwiftUI sheet 이중 트리거는 silent failure**: `showInputSheet = true`가 이미 표시 중인 sheet과 충돌하면 아무 일도 안 일어남. 디버깅 어려움 → deferred `@State` + `onChange` 패턴이 안전

3. **UserDefaults 기반 캐시는 반드시 garbage collection 필요**: 운동 라이브러리에서 삭제된 ID가 UserDefaults에 남으면 maxEntries를 차지하며 실제 최근 운동을 밀어냄

4. **P3도 누적되면 P1**: stale data, magic number, uncached computed property 각각은 사소하지만, 모두 모이면 Watch의 제한된 리소스에서 체감 가능한 문제가 됨
