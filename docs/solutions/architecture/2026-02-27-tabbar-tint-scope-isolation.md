---
tags: [swiftui, tabbar, tint, uikit-appearance, design-system, accentColor]
category: architecture
date: 2026-02-27
status: implemented
severity: important
related_files:
  - DUNE/App/ContentView.swift
related_solutions:
  - architecture/2026-02-26-accentcolor-fallback-fix.md
  - architecture/2026-02-27-design-system-consistency-integration.md
---

# Solution: TabBar Tint Scope Isolation

## Problem

### Symptoms

- 메인 탭바 tint를 앱 키컬러로 맞추려는 변경에서 `TabView`에 `.tint(...)`를 적용함
- 탭바 아이콘/라벨뿐 아니라 탭 내부 하위 뷰의 기본 tint 환경값까지 함께 변경될 수 있는 구조가 됨

### Root Cause

`TabView.tint`는 탭바 전용 속성이 아니라 SwiftUI environment tint를 하위 뷰 트리에 전파한다.  
요구사항이 "탭바만 키컬러 적용"인 경우, 컨테이너 단위 `.tint`는 스코프가 과도하다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/ContentView.swift` | `TabView`의 `.tint(DS.Color.warmGlow)` 제거, `init`에서 `UITabBar.appearance().tintColor = UIColor(named: "AccentColor")` 적용 | 탭바 전용으로 tint 스코프를 제한하고 하위 뷰 tint 회귀를 방지 |

### Key Code

```swift
import UIKit

init(sharedHealthDataService: SharedHealthDataService? = nil) {
    self.sharedHealthDataService = sharedHealthDataService
    if let keyColor = UIColor(named: "AccentColor") {
        UITabBar.appearance().tintColor = keyColor
    }
}
```

## Prevention

### Checklist Addition

- [ ] "탭바만 색상 변경" 요구에서 `TabView.tint`를 바로 적용하지 않았는지 확인
- [ ] 컨테이너 modifier가 environment를 통해 하위 뷰까지 전파되는지 먼저 검토
- [ ] 범위 한정이 필요하면 `UITabBarAppearance` 또는 `UITabBar.appearance()` 우선 검토

### Rule Addition (if applicable)

현재는 solution 문서화로 충분하며, 동일 패턴이 반복될 경우 공통 UI 규칙으로 승격한다.

## Lessons Learned

- SwiftUI의 `.tint`는 UI 요소 개별 스타일이 아니라 environment 레벨 설정으로 동작할 수 있다.
- "어디에 적용할지"보다 "어디까지 전파되는지"를 먼저 판단해야 의도치 않은 회귀를 줄일 수 있다.
- 색상 토큰 자체(`AccentColor`)와 적용 스코프(탭바 전용)는 별개 문제이며 각각 분리해 설계해야 한다.
