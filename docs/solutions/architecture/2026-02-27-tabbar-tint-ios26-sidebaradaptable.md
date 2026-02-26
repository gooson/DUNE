---
tags: [tabbar, tint, ios26, sidebarAdaptable, UITabBar, appearance, SwiftUI, DS-token]
date: 2026-02-27
category: solution
status: implemented
---

# UITabBar.appearance()가 iOS 26 sidebarAdaptable에서 무시되는 문제

## Problem

`UITabBar.appearance().tintColor`로 설정한 탭바 tint 색상이 iOS 26에서 적용되지 않음.

**근본 원인**: `.tabViewStyle(.sidebarAdaptable)` 사용 시 iOS 26은 기존 `UITabBar` 기반 렌더링이 아닌 새로운 렌더링 경로를 사용함. `UIAppearance` proxy가 이 경로에 도달하지 못해 설정이 무시됨.

**증상**: 탭바 아이콘/텍스트가 시스템 기본 파란색으로 표시됨.

## Solution

UIKit `UITabBar.appearance()` 대신 SwiftUI `.tint()` modifier를 TabView에 직접 적용.

### 변경 파일

| File | Change |
|------|--------|
| `DUNE/App/ContentView.swift` | `UITabBar.appearance().tintColor` 제거, `.tint(DS.Color.warmGlow)` 적용 |

### 핵심 코드

```swift
// BEFORE (iOS 26 sidebarAdaptable에서 무시됨)
init(...) {
    if let keyColor = UIColor(named: "AccentColor") {
        UITabBar.appearance().tintColor = keyColor
    }
}

// AFTER (SwiftUI native)
TabView(selection: tabSelection) { ... }
    .tabViewStyle(.sidebarAdaptable)
    .tint(DS.Color.warmGlow)
```

### 주의사항

`.tint()`는 탭바뿐 아니라 하위 뷰 전체에 전파됨. 하위 뷰에서 다른 tint가 필요하면 해당 뷰에서 `.tint()` override 필요.

## Prevention

1. iOS 26+ 타겟에서 `UITabBar.appearance()` 사용 금지 — SwiftUI `.tint()` 사용
2. DS 토큰(`DS.Color.warmGlow`) 경유 필수 — `Color("AccentColor")` 문자열 리터럴 지양
3. `import UIKit`가 View 파일에 필요한지 재검토 — UIAppearance만을 위한 UIKit import는 제거

## Lessons Learned

- `.tabViewStyle(.sidebarAdaptable)`는 iOS 26에서 UIKit UITabBar를 우회하는 새 렌더링 사용
- UIAppearance proxy 기반 커스터마이징은 새 SwiftUI 탭 스타일에서 점진적으로 무력화됨
- SwiftUI native modifier(`.tint()`)가 모든 탭 스타일에서 안정적으로 동작
