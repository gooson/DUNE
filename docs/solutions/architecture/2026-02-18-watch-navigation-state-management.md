---
tags: [watchos, navigation, NavigationStack, NavigationPath, sheet, onChange, state-management, WatchConnectivity, data-loss]
category: architecture
date: 2026-02-18
severity: critical
related_files:
  - DailveWatch/ContentView.swift
  - DailveWatch/QuickStartView.swift
  - DailveWatch/WorkoutIdleView.swift
  - DailveWatch/WatchConnectivityManager.swift
related_solutions:
  - 2026-02-17-cloudkit-optional-relationship.md
---

# Solution: Watch NavigationStack + Sheet 상태 전환 관리

## Problem

### Symptoms

- Watch에서 Quick Start → 운동 선택 후 sheet(QuickWorkoutView) 표시됨
- iPhone에서 해당 운동이 시작되면 `activeWorkout` 상태가 Watch로 수신됨
- ContentView의 root가 `WorkoutActiveView`로 전환되지만 **화면이 바뀌지 않음**
- 사용자에게는 "운동 선택해도 아무 동작 없음"으로 보임

### Root Cause

3가지 문제가 복합적으로 작용:

1. **NavigationStack push + sheet이 화면을 덮음**: `NavigationStack` 안에서 `if/else`로 root view를 전환하더라도, push된 view(QuickStartView)와 그 위의 sheet(QuickWorkoutView)은 자동으로 pop/dismiss되지 않음. `NavigationStack(path:)` 사용 후 path를 리셋해야 push된 view가 pop됨.

2. **WatchExerciseInfo에 Hashable 미준수**: `.sheet(item: $selectedExercise)` 바인딩에서 SwiftUI가 값 변경을 감지하려면 `Equatable`이 필요. `Hashable` 없이는 sheet이 정상 작동하지 않음.

3. **Quick Workout 진행 중 데이터 유실**: `activeWorkout` 수신 시 navigation pop → QuickWorkoutView의 `@State completedSets` 유실. `sendWorkoutCompletion()`이 호출되지 않으므로 완료한 세트 데이터가 영구 소실.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| ContentView.swift | `NavigationStack(path:)` + `onChange(nil→non-nil만)` | 운동 시작 시만 push된 view 전체 pop |
| WorkoutIdleView.swift | `NavigationLink(value: WatchRoute.quickStart)` + `navigationDestination(for: WatchRoute.self)` | path와 연동되는 type-safe navigation |
| QuickStartView.swift | 중복 `onChange` 제거 | ContentView의 path 리셋이 sheet까지 자동 정리 |
| QuickWorkoutView | `onDisappear`에서 미전송 세트 자동 전송 + `finishWorkout()`에서 `completedSets = []` | 비정상 dismiss 시 데이터 유실 방지 |
| WatchConnectivityManager.swift | `WatchExerciseInfo: Hashable` (id 기반) + `WatchRoute` enum | sheet binding 정상 동작 + type-safe routing |

### Key Code

**1. NavigationStack(path:) + 조건부 리셋**
```swift
// ContentView.swift
@State private var navigationPath = NavigationPath()

NavigationStack(path: $navigationPath) { ... }
.onChange(of: connectivity.activeWorkout?.exerciseID) { oldValue, newValue in
    if oldValue == nil, newValue != nil {
        navigationPath = NavigationPath()
    }
}
```

**2. onDisappear 데이터 유실 방지**
```swift
// QuickWorkoutView
.onDisappear {
    guard !completedSets.isEmpty else { return }
    connectivity.sendWorkoutCompletion(update)
}

private func finishWorkout() {
    connectivity.sendWorkoutCompletion(update)
    completedSets = [] // Prevent duplicate send in onDisappear
    dismiss()
}
```

**3. Type-safe navigation routing**
```swift
enum WatchRoute: Hashable {
    case quickStart
}

NavigationLink(value: WatchRoute.quickStart) { ... }
.navigationDestination(for: WatchRoute.self) { destination in
    switch destination {
    case .quickStart: QuickStartView()
    }
}
```

## Prevention

### Checklist Addition

- [ ] `NavigationStack` 안에서 `if/else`로 root view를 전환하는 경우, push된 view가 자동 pop되는지 확인
- [ ] `.sheet(item:)` 사용 시 item 타입에 `Hashable` 준수 확인
- [ ] Navigation push된 view 위에 sheet이 있을 때, 상위 state 변경으로 인한 비정상 dismiss 시나리오 검증
- [ ] `@State` 데이터가 view dismiss 시 유실되면 안 되는 경우 `onDisappear`에서 저장 처리

### Rule Addition

`.claude/rules/` 추가 고려 — **watch-navigation.md**:

```markdown
# Watch Navigation Rules

## NavigationStack(path:) 필수
- Watch에서 외부 상태(activeWorkout 등)로 root view가 전환되는 경우
  NavigationStack(path:)를 사용하여 push된 view를 프로그래매틱하게 pop

## Navigation value는 enum 사용
- NavigationLink(value: String) 금지 — WatchRoute enum 사용
- navigationDestination(for:)에서 switch로 모든 case 처리

## @State 데이터 보호
- onDisappear에서 미저장 데이터 전송/저장
- 정상 종료 경로에서는 데이터를 비워 중복 전송 방지
```

## Lessons Learned

1. **SwiftUI NavigationStack은 push된 view를 자동 정리하지 않는다**: root view가 `if/else`로 전환되어도, push된 child view는 stack에 남아있음. `NavigationPath`를 명시적으로 초기화해야 pop됨.

2. **sheet(item:) 바인딩은 Equatable이 핵심**: `Identifiable`만으로는 부족할 수 있음. `Hashable`(= `Equatable` 포함)을 추가해야 SwiftUI가 값 변경을 정확히 감지.

3. **비정상 view dismiss 시 @State 데이터 유실은 silent failure**: 사용자도 개발자도 데이터가 사라진 것을 인지하기 어려움. `onDisappear`를 "safety net"으로 사용하고, 정상 경로에서 데이터를 비우는 패턴이 안전.

4. **onChange 감시 범위를 최소화**: `nil → non-nil` 전환만 트리거하면 운동 종료 시 불필요한 navigation 리셋을 방지. 모든 변경에 반응하는 것은 의도하지 않은 side effect 유발.

5. **Navigation routing은 enum으로 type-safe하게**: String literal은 컴파일 타임 검증이 없어 오타, 충돌 위험. 단일 destination이라도 enum으로 시작하면 확장이 안전.
