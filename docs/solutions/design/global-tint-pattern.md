---
tags: [swiftui, tint, design-system, ios26]
date: 2026-03-01
category: solution
status: implemented
---

# Global Tint Pattern (iOS 26)

## Problem

iOS 기본 파란색 tint가 Toggle, Stepper, NavigationLink chevron 등 시스템 컨트롤에 적용되어 앱 브랜드 색상과 불일치.

iOS 26의 `.sidebarAdaptable` TabView에서 `UITabBar.appearance()` 프록시는 무시됨.

## Solution

`DUNEApp.swift`의 WindowGroup 콘텐츠 최상위에 `.tint()` modifier 적용:

```swift
var body: some Scene {
    WindowGroup {
        Group {
            // ... app content
        }
        .tint(DS.Color.warmGlow)  // All system controls inherit this tint
    }
    .modelContainer(modelContainer)
}
```

### 주의사항

- `.tint()`은 **View modifier**. Scene level (`.modelContainer()` 뒤)에 적용하면 컴파일 에러.
- 자식 뷰에서 명시적 `.tint(DS.Color.activity)` 등은 override됨 (SwiftUI는 가장 가까운 tint 우선).
- `AccentColor.colorset`도 설정되어 있으나, iOS 26에서 일부 컨트롤이 이를 무시하므로 명시적 `.tint()` 필요.

## Prevention

- iOS 26+에서 `UITabBar.appearance()` 등 UIKit appearance proxy 사용 금지
- 브랜드 색상 적용은 root `.tint()` modifier 사용
- `swiftui-patterns.md` 룰 참조: "TabBar tint -> `.tint(DS.Color.warmGlow)` modifier"
