---
tags: [swiftui, navigation, navigationstack, warning, performance]
date: 2026-03-08
category: plan
status: draft
---

# Fix: NavigationRequestObserver tried to update multiple times per frame

## Problem Statement

`ContentView.handleNotificationNavigationRequest()` 호출 시 "NavigationRequestObserver tried to update multiple times per frame" 경고 발생.

### Root Cause

`clearAllNavPaths()`가 4개의 `NavigationPath` `@State`를 동시에 초기화한다 (line 228-233).
각 path는 `NavigationStack(path:)` 바인딩에 연결되어 있어, SwiftUI가 한 프레임에 4개의 navigation 상태 변경을 감지한다.

추가로:
- `.push` case: `clearAllNavPaths()` + `setNavPath()` → 대상 탭 path를 2회 write (clear → set)
- `.openWorkoutInActivity`: `clearAllNavPaths()` + `selectedSection` + signal → 6개 state mutation
- `.openNotificationHub`: `clearAllNavPaths()` + `selectedSection` + signal → 6개 state mutation

### Why It's a Problem

- 비어있는 `NavigationPath`에 새 빈 `NavigationPath()`를 할당해도 SwiftUI는 state change로 간주
- 4개 path + tab selection + signal = 최대 6개 동시 navigation state mutation
- 통상 1개 탭만 active path를 가지므로, 나머지 3개는 불필요한 write

## Solution

`clearAllNavPaths()`에 guard를 추가하여 이미 비어있는 path는 건드리지 않는다.

### Before

```swift
private func clearAllNavPaths() {
    todayNavPath = NavigationPath()
    trainNavPath = NavigationPath()
    wellnessNavPath = NavigationPath()
    lifeNavPath = NavigationPath()
}
```

### After

```swift
private func clearAllNavPaths() {
    if !todayNavPath.isEmpty { todayNavPath = NavigationPath() }
    if !trainNavPath.isEmpty { trainNavPath = NavigationPath() }
    if !wellnessNavPath.isEmpty { wellnessNavPath = NavigationPath() }
    if !lifeNavPath.isEmpty { lifeNavPath = NavigationPath() }
}
```

추가로 `.push` case에서 대상 탭의 path 이중 write를 제거:

### Before

```swift
case .push:
    clearAllNavPaths()
    let destinations = NotificationPresentationPlanner.rootPath(for: plan)
    var path = NavigationPath()
    for destination in destinations { path.append(destination) }
    setNavPath(path, for: selectedSection)
```

### After

```swift
case .push:
    clearNavPathsExcept(selectedSection)
    let destinations = NotificationPresentationPlanner.rootPath(for: plan)
    var path = NavigationPath()
    for destination in destinations { path.append(destination) }
    setNavPath(path, for: selectedSection)
```

새 helper:

```swift
private func clearNavPathsExcept(_ section: AppSection) {
    if section != .today && !todayNavPath.isEmpty { todayNavPath = NavigationPath() }
    if section != .train && !trainNavPath.isEmpty { trainNavPath = NavigationPath() }
    if section != .wellness && !wellnessNavPath.isEmpty { wellnessNavPath = NavigationPath() }
    if section != .life && !lifeNavPath.isEmpty { lifeNavPath = NavigationPath() }
}
```

## Affected Files

| File | Change |
|------|--------|
| `DUNE/App/ContentView.swift` | `clearAllNavPaths()` guard 추가, `clearNavPathsExcept()` 추가, `.push` case 수정 |

## Implementation Steps

### Step 1: `clearAllNavPaths()` 에 isEmpty guard 추가
- 이미 비어있는 path는 write 하지 않도록 수정
- 4개 불필요한 write → 최대 1개 (active path만)

### Step 2: `clearNavPathsExcept(_:)` helper 추가
- `.push` case에서 대상 탭의 path를 두 번 write하지 않도록 분리

### Step 3: `.push` case에서 `clearNavPathsExcept` 사용
- `clearAllNavPaths()` → `clearNavPathsExcept(selectedSection)`

## Test Strategy

- 빌드 성공 확인
- 테스트 면제: 이 변경은 SwiftUI View의 private helper 수정이므로 유닛 테스트 불필요 (testing-required.md: "SwiftUI View body (UI 테스트로 대체)")

## Risks & Edge Cases

- **Risk**: `NavigationPath.isEmpty` 판정이 정확하지 않을 수 있음
  - **Mitigation**: `NavigationPath.isEmpty`는 Apple 공식 API이며 신뢰 가능
- **Edge Case**: 알림 라우팅 중 여러 탭에 path가 쌓여있는 경우
  - **Mitigation**: 기존과 동일하게 비어있지 않은 path만 clear하므로 동작 동일
- **Edge Case**: `.push` case에서 현재 탭의 기존 path가 있을 때
  - **Mitigation**: `setNavPath()`가 새 path로 덮어쓰므로 기존 path가 있어도 정상 작동
