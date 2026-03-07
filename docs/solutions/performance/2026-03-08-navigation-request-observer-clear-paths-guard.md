---
tags: [swiftui, navigation, navigationstack, navigationpath, navigationlink, warning, performance, multi-update, toolbar, destination-form]
date: 2026-03-08
category: solution
status: implemented
---

# NavigationRequestObserver: Multi-Update Per Frame 경고 해결

## Problem

"NavigationRequestObserver tried to update multiple times per frame" 경고가 두 가지 경로에서 발생.

### 근본 원인 1: clearAllNavPaths 무조건 초기화

`clearAllNavPaths()`가 4개의 `NavigationPath` `@State`를 **무조건** 초기화. 이미 비어있는 path에 새 `NavigationPath()`를 할당해도 SwiftUI가 state change로 간주. 한 프레임에 최대 6개 동시 mutation.

### 근본 원인 2: Destination-form NavigationLink 과다 observer

DashboardView 툴바에서 3개의 destination-form `NavigationLink { View() }`가 각각 **implicit navigation observer**를 생성. explicit `navigationDestination` 5개 + ContentView 1개 + implicit 3개 = 총 9개 observer. 히어로 카드 탭 시 모든 observer가 한 프레임에 평가되어 경고 발생.

### 증상

- notification tap 시 경고 (근본 원인 1)
- **히어로 카드 탭 시 경고** (근본 원인 2) — Dashboard, Activity 탭 모두

## Solution

### Fix 1: clearNavPaths isEmpty guard (ContentView)

`clearNavPaths(except:)` 단일 함수로 통합하고, `isEmpty` guard를 추가:

```swift
private func clearNavPaths(except excluded: AppSection? = nil) {
    if excluded != .today && !todayNavPath.isEmpty { todayNavPath = NavigationPath() }
    if excluded != .train && !trainNavPath.isEmpty { trainNavPath = NavigationPath() }
    if excluded != .wellness && !wellnessNavPath.isEmpty { wellnessNavPath = NavigationPath() }
    if excluded != .life && !lifeNavPath.isEmpty { lifeNavPath = NavigationPath() }
}
```

### Fix 2: Destination-form → Button + isPresented (DashboardView)

3개의 toolbar destination-form NavigationLink를 `Button` + `navigationDestination(isPresented:)`로 변환:

```swift
// BEFORE: implicit observer 생성
NavigationLink {
    SettingsView()
} label: {
    Image(systemName: "gearshape")
}

// AFTER: explicit isPresented observer만 사용
Button {
    showSettings = true
} label: {
    Image(systemName: "gearshape")
}
// ... 별도 위치에:
.navigationDestination(isPresented: $showSettings) {
    SettingsView()
}
```

Notifications는 기존 `$showNotificationHub` 재사용하여 이중 navigation 경로도 제거.

### 변경 파일

- `DUNE/App/ContentView.swift` (Fix 1)
- `DUNE/Presentation/Dashboard/DashboardView.swift` (Fix 2)

## Prevention

- **Destination-form `NavigationLink { View() }` 사용 금지** — implicit observer를 생성하여 NavigationStack의 observer 수를 불필요하게 증가시킴
- 대신 `Button` + `navigationDestination(isPresented:)` 또는 value-form `NavigationLink(value:)` 사용
- 하나의 NavigationStack에 `navigationDestination` modifier가 6개 이상이면 observer 과다 가능성 점검
- NavigationPath 초기화 시 isEmpty guard 적용

## Lessons Learned

- Destination-form `NavigationLink { View() }`는 value-form과 달리 **자체적으로 implicit navigation observer를 등록**함
- 동일 NavigationStack에 observer가 많을수록 모든 navigation event에서 평가 비용 증가
- Toolbar 내 NavigationLink는 Button으로 대체해도 시각적 차이가 없음 (`.topBarTrailing` placement에서 동일 렌더링)
- 같은 destination(NotificationHubView)에 대해 두 가지 navigation 경로(destination-form NavigationLink + `isPresented`)가 있으면 observer 중복 + 혼란의 원인
