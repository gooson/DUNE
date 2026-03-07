---
tags: [life, habit, swiftui, confirmationdialog, context-menu, accessibility, ui-testing]
date: 2026-03-08
category: solution
severity: important
related_files:
  - DUNE/Presentation/Life/LifeView.swift
  - DUNE/Presentation/Life/HabitRowView.swift
  - DUNEUITests/Smoke/LifeSmokeTests.swift
related_solutions:
  - docs/solutions/general/2026-03-08-life-context-menu-deferred-actions.md
status: implemented
---

# Solution: Life Habit Actions Visibility + Deferred Dialog Pattern

## Problem

### Symptoms

- Life 탭의 내 습관 row는 수정/보관(archive)을 `contextMenu`에만 노출하고 있었다.
- long press discoverability가 낮아 사용자가 수정/삭제 경로를 찾기 어려웠다.
- menu lifecycle 회귀가 생기면 `Edit` / `Archive`가 눌려도 반응하지 않는 것처럼 보일 수 있었다.
- 초기 UI test는 영어 라벨과 `firstMatch`에 의존해 locale/row 순서가 바뀌면 쉽게 깨질 수 있었다.

### Root Cause

문제는 두 층위가 겹쳐 있었다.

1. **UX 노출 부족**: 핵심 CRUD 액션이 hidden gesture 하나에만 매달려 있었다.
2. **menu dismissal 민감성**: row mutation과 sheet open이 menu dismissal 시점과 충돌하면 no-op 또는 UIKit warning으로 이어질 수 있었다.
3. **테스트 식별자 부족**: visible action entry point와 action item에 stable accessibility identifier가 없어, 회귀 테스트가 로컬라이즈 문자열/row order에 기대게 되었다.

## Solution

각 habit row 우측 상단에 보이는 actions button을 추가하고, `confirmationDialog`에서 `Edit` / `Archive` / cycle 보조 액션을 실행하도록 정리했다.  
visible path와 `contextMenu` path 모두 공통 action builder를 사용하고, 실제 상태 변경은 deferred helper를 통해 dismissal 이후 실행하도록 맞췄다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Life/HabitRowView.swift` | trailing accessory slot 추가 | row content layout을 깨지 않고 action button overlay 공간 확보 |
| `DUNE/Presentation/Life/LifeView.swift` | visible actions button + `confirmationDialog` 추가, action item builder 공통화, deferred helper 정리 | hidden long press 의존 제거 + menu/dialog mutation 타이밍 통일 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | row/action AXID 추가 | locale-independent selector 제공 |
| `DUNEUITests/Smoke/LifeSmokeTests.swift` | seeded edit/archive smoke test 추가 및 AXID 기반 lookup으로 전환 | 핵심 CRUD 회귀를 안정적으로 고정 |
| `Shared/Resources/Localizable.xcstrings` | `"More actions"` 번역 추가 | visible action entry point localization 보장 |

### Key Code

```swift
.overlay(alignment: .topTrailing) {
    habitActionsButton(for: progress)
        .padding(.top, habitActionInset)
        .padding(.trailing, habitActionInset)
}
.confirmationDialog("More actions", isPresented: ...) {
    if let progress = selectedActionProgress {
        habitActionItems(for: progress, deferred: true)
    }
}

private func performDeferredHabitAction(_ action: @escaping () -> Void) {
    Task { @MainActor in
        await Task.yield()
        action()
    }
}
```

## Prevention

- 핵심 CRUD 액션을 hidden gesture 하나에만 의존하지 않는다.
- `contextMenu`, `Menu`, `confirmationDialog`처럼 dismissal lifecycle이 있는 액션 경로는 동일한 deferred mutation helper를 사용한다.
- UI test는 로컬라이즈 문자열이나 `firstMatch`보다 row/action AXID를 우선 사용한다.
- 사용자가 찾기 어려운 액션은 visible button 또는 explicit dialog entry point로 승격한다.

### Checklist Addition

- [ ] 핵심 edit/delete/archive 액션이 hidden gesture 하나에만 묶여 있지 않은가
- [ ] menu/dialog action이 row mutation 또는 sheet open을 직접 즉시 실행하지 않는가
- [ ] 새 UI test selector가 localized label이 아니라 AXID를 우선 사용하고 있는가

### Rule Addition (if applicable)

현재는 solution 문서 축적으로 충분하다.  
비슷한 패턴이 두세 번 더 반복되면 `.claude/rules/`에 다음 규칙 승격을 검토한다:

- hidden gesture에만 핵심 CRUD 액션을 두지 않는다
- UI smoke test는 localized label 대신 AXID를 우선 사용한다

## Lessons Learned

1. **가시성 문제와 lifecycle 문제는 함께 다뤄야 한다**: visible entry point만 추가하면 timing 회귀가 남고, defer만 추가하면 사용자는 여전히 액션을 찾기 어렵다.
2. **UI test selector도 제품 설계의 일부다**: stable AXID가 없으면 테스트가 영어 텍스트와 우연한 row 순서에 묶여 금방 불안정해진다.
3. **공통 action builder가 회귀를 줄인다**: context menu, visible dialog, future swipe action이 생겨도 동일한 action item builder와 deferred helper를 재사용하면 동작 차이가 줄어든다.
