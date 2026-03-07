tags: [swiftui, uicontextmenuinteraction, life, context-menu, deferred-action]
date: 2026-03-08
category: solution
status: implemented
---

# Life Context Menu Deferred Action Fix

## Problem

Life 탭의 habit row context menu 사용 중 콘솔에 아래 경고가 출력될 수 있었다.

`Called -[UIContextMenuInteraction updateVisibleMenuWithBlock:] while no context menu is visible. This won't do anything.`

## Root Cause

context menu 액션이 메뉴 dismissal이 끝나기 전에 row host를 즉시 mutate하고 있었다.

예를 들어 `Archive`, `Snooze`, `Skip`, `Edit`, `History` 같은 액션이 선택 직후 리스트 상태나 sheet 상태를 바꾸면, SwiftUI/UIKit가 이미 닫히는 중인 context menu를 다시 갱신하려고 시도하면서 warning이 발생할 수 있다.

## Solution

habit context menu 액션을 한 runloop 뒤로 미뤄서, UIKit가 visible menu를 완전히 dismiss한 뒤 상태 변경이 일어나도록 바꿨다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Life/LifeView.swift` | `performDeferredContextMenuAction` helper 추가, habit context menu의 모든 버튼 액션을 deferred execution으로 변경 | menu dismissal과 row mutation 충돌 방지 |

### Key Code

```swift
private func performDeferredContextMenuAction(_ action: @escaping @MainActor () -> Void) {
    Task { @MainActor in
        await Task.yield()
        action()
    }
}
```

## Prevention

- context menu action이 현재 menu host row를 삭제/변경하거나 sheet/navigation을 여는 경우 즉시 mutate하지 않는다.
- `contextMenu` 내부 액션에서 SwiftUI state, SwiftData model, navigation state를 바꿀 때는 dismissal 이후 실행을 기본 패턴으로 둔다.
- warning이 harmless처럼 보여도 menu lifecycle과 host identity가 충돌하는 신호로 보고 정리한다.

## Lessons Learned

SwiftUI `contextMenu`는 버튼 탭 이후 곧바로 닫히지만, UIKit lifecycle은 같은 frame 안에서 아직 정리 중일 수 있다. 그 시점에 host row를 바꾸면 menu update/dismiss 흐름과 충돌하므로, 짧은 defer가 더 안전하다.
