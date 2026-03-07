---
tags: [swiftui, navigation, navigationstack, navigationpath, warning, performance, multi-update]
date: 2026-03-08
category: solution
status: implemented
---

# NavigationRequestObserver: clearAllNavPaths isEmpty Guard

## Problem

`handleNotificationNavigationRequest()`가 실행될 때마다 "NavigationRequestObserver tried to update multiple times per frame" 경고 발생.

### 근본 원인

`clearAllNavPaths()`가 4개의 `NavigationPath` `@State`를 **무조건** 초기화. 각 path는 `NavigationStack(path:)` 바인딩에 연결되어 있어, 이미 비어있는 path에 새 `NavigationPath()`를 할당해도 SwiftUI가 state change로 간주. 한 프레임에 4개의 navigation 상태 변경 + `selectedSection` + signal = 최대 6개 동시 mutation.

### 증상

- Xcode console에 반복적으로 경고 메시지 출력
- notification tap 시 특히 빈번

## Solution

`clearNavPaths(except:)` 단일 함수로 통합하고, `isEmpty` guard를 추가하여 이미 비어있는 path는 skip:

```swift
private func clearNavPaths(except excluded: AppSection? = nil) {
    if excluded != .today && !todayNavPath.isEmpty { todayNavPath = NavigationPath() }
    if excluded != .train && !trainNavPath.isEmpty { trainNavPath = NavigationPath() }
    if excluded != .wellness && !wellnessNavPath.isEmpty { wellnessNavPath = NavigationPath() }
    if excluded != .life && !lifeNavPath.isEmpty { lifeNavPath = NavigationPath() }
}
```

`.push` case에서는 `clearNavPaths(except: selectedSection)` 사용하여 대상 탭의 path 이중 write 방지.

### 변경 파일

- `DUNE/App/ContentView.swift`

## Prevention

- NavigationPath를 여러 개 소유하는 View에서는 비어있는 path에 대한 불필요한 reset을 피한다
- 한 synchronous call에서 navigation-related @State를 2개 이상 변경할 때는 isEmpty guard 적용
- 이 패턴은 기존 해결책 (`2026-03-02-watch-navigation-request-observer-update-loop.md`)과 동일한 원칙: **불필요한 navigation state write를 최소화**

## Lessons Learned

- `NavigationPath`에 빈 `NavigationPath()`를 할당해도 SwiftUI는 이를 state change로 처리하여 re-render를 유발함
- Tab 기반 앱에서 모든 탭의 path를 일괄 초기화하는 것은 대부분의 경우 불필요 (한 번에 1개 탭만 active path 보유)
- `clearAll` + `set` 패턴보다 `clear(except:)` + `set` 패턴이 navigation mutation 수를 최소화
