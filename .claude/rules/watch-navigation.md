# Watch Navigation Rules

## NavigationStack(path:) 필수

외부 상태(`activeWorkout` 등)로 root view가 전환되는 경우 `NavigationStack(path:)`를 사용하여 push된 view를 프로그래매틱하게 pop.

```swift
// BAD: push된 view가 stack에 남아 root 전환을 가림
NavigationStack { if condition { ViewA() } else { ViewB() } }

// GOOD: path 리셋으로 push된 view 전체 pop
@State private var navigationPath = NavigationPath()
NavigationStack(path: $navigationPath) { ... }
.onChange(of: state) { old, new in
    if old == nil, new != nil { navigationPath = NavigationPath() }
}
```

## Navigation value는 enum 사용

`NavigationLink(value: String)` 금지. `WatchRoute` enum으로 type-safe routing.

```swift
// BAD: magic string, 컴파일 타임 검증 없음
NavigationLink(value: "quickStart") { ... }
.navigationDestination(for: String.self) { _ in QuickStartView() }

// GOOD: type-safe, switch exhaustive check
NavigationLink(value: WatchRoute.quickStart) { ... }
.navigationDestination(for: WatchRoute.self) { destination in
    switch destination {
    case .quickStart: QuickStartView()
    }
}
```

## @State 데이터 보호

비정상 dismiss 시 `@State` 데이터 유실은 silent failure. `onDisappear`에서 미저장 데이터를 전송/저장하고, 정상 종료 경로에서는 데이터를 비워 중복 전송 방지.

```swift
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

## onChange 감시 범위 최소화

`onChange(of:)`는 특정 전환(예: `nil → non-nil`)만 트리거. 모든 변경에 반응하면 의도하지 않은 side effect 유발.

```swift
// BAD: 운동 종료(exerciseID → nil)에도 path 리셋
.onChange(of: activeWorkout?.exerciseID) { navigationPath = NavigationPath() }

// GOOD: 운동 시작(nil → exerciseID)만 트리거
.onChange(of: activeWorkout?.exerciseID) { old, new in
    if old == nil, new != nil { navigationPath = NavigationPath() }
}
```
