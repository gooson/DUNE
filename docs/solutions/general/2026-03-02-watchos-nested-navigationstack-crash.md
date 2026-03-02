---
tags: [watchos, navigationstack, crash, puicstackednavigationbar, sheet]
category: general
date: 2026-03-02
severity: critical
related_files: [DUNEWatch/Views/SetInputSheet.swift, DUNEWatch/ContentView.swift]
related_solutions: [architecture/2026-02-18-watch-navigation-state-management.md]
---

# Solution: watchOS Nested NavigationStack Crash in Sheet

## Problem

### Symptoms

- Thread 1 crash: "Layout requested for visible navigation bar, when the top item belongs to a different navigation bar, possibly from a client attempt to nest wrapped navigation controllers."
- `PUICStackedNavigationBar` 두 개가 동시에 활성화되어 layout conflict 발생

### Root Cause

`SetInputSheet`이 자체 `NavigationStack`을 가지고 있었고, 이 sheet는 `ContentView`의 root `NavigationStack` 안에서 `.sheet()` modifier로 표시됨. watchOS에서는 sheet 내부의 NavigationStack도 root NavigationStack과 동일한 navigation bar 계층을 공유하여 충돌 발생.

iOS에서는 sheet가 별도의 presentation context를 생성하므로 허용되지만, watchOS의 `PUICStackedNavigationBar`는 이를 허용하지 않음.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| DUNEWatch/Views/SetInputSheet.swift | `NavigationStack` + `navigationDestination` 제거 → `if/else` 조건부 View 전환 | NavigationStack 중첩 방지 |
| DUNEWatch/Views/SetInputSheet.swift | `.onChange(of: weight)` clamping을 else 분기에 유지 | 방어적 입력 검증 보존 |

### Key Code

```swift
// BEFORE: nested NavigationStack (crash)
var body: some View {
    NavigationStack {
        ScrollView { ... }
        .navigationDestination(isPresented: $showPreviousSets) {
            previousSetsDetail
        }
    }
}

// AFTER: conditional view switching (safe)
var body: some View {
    if showPreviousSets {
        previousSetsDetail
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { showPreviousSets = false } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
    } else {
        ScrollView { ... }
        .onChange(of: weight) { _, newValue in
            let clamped = min(max(newValue, 0), 500)
            if clamped != newValue { weight = clamped }
        }
    }
}
```

## Prevention

### Checklist Addition

- [ ] watchOS sheet 내부에 `NavigationStack` 추가 금지 — `if/else` 조건부 전환 사용
- [ ] navigation 관련 리팩터링 시 `.onChange` 등 부수 modifier가 누락되지 않았는지 확인

### Rule Addition (if applicable)

`watch-navigation.md`에 추가 고려:
- **watchOS sheet 내부 NavigationStack 금지**: iOS와 달리 watchOS sheet는 별도 presentation context를 생성하지 않으므로, sheet 내부에 NavigationStack을 사용하면 root NavigationStack과 충돌하여 crash 발생. 조건부 View 전환 패턴 사용.

## Lessons Learned

- iOS의 sheet NavigationStack 허용 패턴이 watchOS에서는 crash를 유발함
- navigation 구조 변경 시 `.onChange`, `.onAppear` 등 부수 modifier가 실수로 제거되기 쉬움 — 리뷰에서 반드시 확인
- `digitalCrownRotation`의 `from:through:` 범위 제한은 crown 입력만 보호하며, binding에 직접 할당되는 값은 보호하지 않으므로 `onChange` clamping이 여전히 필요
