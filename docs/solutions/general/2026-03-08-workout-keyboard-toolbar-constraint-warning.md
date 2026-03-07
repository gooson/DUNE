---
tags: [swiftui, keyboard, toolbar, autolayout, workout-session, input]
date: 2026-03-08
category: solution
status: implemented
---

# Workout Keyboard Toolbar Constraint Warning

## Problem

운동 세션 입력 중 콘솔에 아래와 같은 keyboard constraint warning이 반복해서 출력되었다.

`Unable to simultaneously satisfy constraints`

로그는 `_UIRemoteKeyboardPlaceholderView` 와 `_UIKBCompatInputView` 사이에서 accessory/input view 제약이 충돌하고 있었다.

## Root Cause

`WorkoutSessionView`가 `ToolbarItemGroup(placement: .keyboard)`로 number pad dismiss 버튼을 붙이고 있었다.

SwiftUI keyboard toolbar는 UIKit accessory view를 생성하는데, 현재 iOS simulator/runtime 조합에서는 이 accessory view가 keyboard placeholder와 충돌하면서 반복적인 Auto Layout warning을 만들 수 있다.

## Solution

keyboard accessory toolbar를 제거하고, 같은 dismiss 기능을 `safeAreaInset(edge: .bottom)` 기반의 하단 dismiss bar로 옮겼다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | `.keyboard` toolbar 제거, `keyboardDismissBar` 추가, focus 시 bottom inset으로 표시 | accessory view 생성 경로 제거, numberPad dismiss UX 유지 |

## Prevention

- numberPad/decimalPad dismiss가 필요해도 `ToolbarItemGroup(placement: .keyboard)`를 기본값처럼 쓰지 않는다.
- keyboard warning이 `_UIRemoteKeyboardPlaceholderView` / `_UIKBCompatInputView` 패턴이면 accessory toolbar부터 먼저 의심한다.
- dismiss UX는 가능하면 view-owned inset/overlay bar로 유지하고 UIKit accessory view 의존을 줄인다.
