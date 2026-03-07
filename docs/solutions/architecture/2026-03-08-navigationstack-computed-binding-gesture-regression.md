---
tags: [NavigationStack, NavigationPath, Binding, computed-binding, chart, gesture, regression, long-press, scroll, SwiftUI, @State]
date: 2026-03-08
category: solution
status: implemented
---

# NavigationStack Computed Binding으로 인한 차트 제스처 회귀

## Problem

PR #354에서 알림 push 네비게이션 지원을 위해 `ContentView`의 NavigationStack 패턴을 변경:
- `NotificationPresentationPaths` struct에 4개 탭의 NavigationPath를 묶고
- `notificationPathBinding(for:)` computed method로 각 탭에 `Binding<NavigationPath>` 제공

**증상**: 모든 탭의 모든 차트에서 롱프레스 선택 무반응, 수평 스크롤 불가, 터치 미인식.

**근본 원인**:
1. `body` 평가마다 새 `Binding` 인스턴스 생성 → SwiftUI가 Binding 변경으로 인식
2. 4개 탭 path가 하나의 struct → 어느 탭 변경이든 전체 @State 변경 트리거
3. NavigationStack 내부 view hierarchy 재구성 → 차트의 `@State` 리셋
4. `ChartSelectionGestureState`, `selectedDate` 등 제스처 상태 초기화 → 제스처 체인 단절

## Solution

`NotificationPresentationPaths` struct + computed Binding을 제거하고, 탭별 독립 `@State NavigationPath`로 교체:

```swift
// BEFORE (broken):
@State private var notificationPresentationPaths = NotificationPresentationPaths()

NavigationStack(path: notificationPathBinding(for: .today)) { ... }

private func notificationPathBinding(for section: AppSection) -> Binding<NavigationPath> {
    Binding(
        get: { notificationPresentationPaths.path(for: section) },
        set: { notificationPresentationPaths.updatePath($0, for: section) }
    )
}

// AFTER (fixed):
@State private var todayNavPath = NavigationPath()
@State private var trainNavPath = NavigationPath()
@State private var wellnessNavPath = NavigationPath()
@State private var lifeNavPath = NavigationPath()

NavigationStack(path: $todayNavPath) { ... }
```

알림 라우팅은 헬퍼 메서드로 처리:
```swift
private func clearAllNavPaths() { ... }
private func setNavPath(_ path: NavigationPath, for section: AppSection) { ... }
```

## Prevention

1. **NavigationStack(path:)에는 반드시 직접 `@State` 바인딩 사용** — computed Binding, struct 래퍼, closure 기반 Binding 금지
2. **여러 NavigationPath를 하나의 struct/class에 묶지 않음** — 하나의 path 변경이 다른 탭에 전파
3. **차트 제스처 회귀 시 NavigationStack 패턴부터 의심** — 차트 코드 자체가 정상이어도 부모 view 구조가 @State를 리셋할 수 있음

## Lessons Learned

- SwiftUI의 `NavigationStack(path:)` Binding은 참조 안정성이 매우 중요. computed Binding은 매 body 평가마다 새 인스턴스를 생성하여 불필요한 view reconstruction을 유발할 수 있다.
- 제스처 장애의 원인이 제스처 코드 자체가 아니라 부모 view의 @State 리셋일 수 있다. git diff로 제스처 코드가 변경되지 않았다면 NavigationStack/TabView 등 부모 구조 변경을 먼저 확인해야 한다.
- 여러 관련 state를 하나의 struct로 묶는 것은 일반적으로 좋은 패턴이지만, NavigationPath처럼 Binding 안정성이 중요한 경우에는 독립 @State가 더 안전하다.
