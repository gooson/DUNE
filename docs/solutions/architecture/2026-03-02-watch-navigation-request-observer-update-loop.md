---
tags: [watchos, swiftui, navigationstack, onchange, navigationpath]
category: architecture
date: 2026-03-02
severity: important
related_files: [DUNEWatch/ContentView.swift]
related_solutions:
  - architecture/2026-02-18-watch-navigation-state-management.md
  - general/2026-03-02-watchos-nested-navigationstack-crash.md
---

# Solution: watchOS NavigationRequestObserver Multi-Update 경고 제거

## Problem

### Symptoms

- workout 시작/종료 전환 시 콘솔에 `NavigationRequestObserver tried to update multiple times per frame` 경고가 간헐적으로 출력됨
- 경고는 즉시 크래시로 이어지지 않지만, 네비게이션 상태 전환이 같은 프레임에 중복 요청될 가능성을 나타냄

### Root Cause

`DUNEWatch/ContentView.swift`에서 `workoutManager.isActive`와 `workoutManager.isSessionEnded`를 각각 별도 `.onChange`로 관찰하며, 두 핸들러 모두 `navigationPath = NavigationPath()`를 수행했다.

watch workout 상태 전환(특히 종료 시점)에서 두 값이 짧은 구간에 함께 바뀔 수 있어, 동일 프레임 내 `NavigationStack` path write가 중복 발생했다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/ContentView.swift` | `NavigationObserverState`(Equatable) 추가 후 단일 `.onChange`로 통합 | navigation write 경로를 하나로 단일화 |
| `DUNEWatch/ContentView.swift` | `guard navigationPath.count > 0` 추가 | path가 이미 빈 상태일 때 불필요한 reset 방지 |
| `DUNEWatch/ContentView.swift` | `isSessionEnded == false` 전환 시 `sessionEndDate = nil` | 다음 세션에서 stale 종료 시각 잔존 방지 |

### Key Code

```swift
private struct NavigationObserverState: Equatable {
    let isActive: Bool
    let isSessionEnded: Bool
}

.onChange(of: navigationObserverState) { old, new in
    let startedWorkout = !old.isActive && new.isActive
    let endedWorkout = !old.isSessionEnded && new.isSessionEnded

    if endedWorkout {
        sessionEndDate = Date()
    }

    guard startedWorkout || endedWorkout else { return }
    guard navigationPath.count > 0 else { return }
    navigationPath = NavigationPath()
}
```

## Prevention

### Checklist Addition

- [ ] `NavigationPath` write(`navigationPath = ...`)는 가능한 한 한 곳의 상태 싱크로 제한한다.
- [ ] 동일 이벤트에서 동시에 변할 수 있는 상태를 여러 `.onChange`에서 각각 path write하지 않는다.
- [ ] path reset 전에 "실제 reset 필요 여부"(예: `path.count > 0`)를 확인한다.

### Rule Addition (if applicable)

현행 `watch-navigation.md`의 "onChange 감시 범위 최소화" 원칙으로 커버 가능하므로 신규 룰 추가는 생략했다.

## Lessons Learned

- watchOS navigation 경고는 크래시 전조 신호일 수 있으므로, 경고 단계에서 update source를 단일화하는 것이 안전하다.
- 상태 관찰 지점을 늘리는 것보다, "전환 이벤트를 하나의 상태 모델로 묶어 처리"하는 편이 side effect를 예측하기 쉽다.
