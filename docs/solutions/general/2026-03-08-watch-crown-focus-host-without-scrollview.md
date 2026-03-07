---
tags: [watchos, swiftui, digital-crown, focus, scrollview, sheet]
date: 2026-03-08
category: solution
status: implemented
---

# Watch Crown Sequencer Focus Host Fix

## Problem

watchOS 시뮬레이터에서 아래 경고가 반복해서 출력될 수 있었다.

`Crown Sequencer was set up without a view property. This will inevitably lead to incorrect crown indicator states`

문제는 무게 입력 시트와 운동 강도 입력 시트처럼 Digital Crown 입력을 받는 화면에서 발생했다.

## Root Cause

Digital Crown 입력이 붙은 sheet content가 `ScrollView` 기반이거나, crown host가 스크롤/내장 control과 뒤섞인 상태였다.

이 구조에서는 SwiftUI가 crown sequencer를 안정적인 단일 host view에 연결하지 못해 simulator에서 indicator state warning이 발생할 수 있다.

## Solution

Digital Crown 입력을 받는 두 시트를 `ScrollView` 없는 정적 `VStack` 레이아웃으로 바꾸고, `@FocusState`로 crown host focus를 명시했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/Views/SetInputSheet.swift` | `ScrollView` 제거, root `VStack`에 crown modifier와 focus 연결 | crown host를 단일 view로 고정 |
| `DUNEWatch/Views/SessionSummaryView.swift` | effort input sheet에서 crown modifier를 `Slider`/`ScrollView` 조합에서 root `VStack`으로 이동 | crown indicator state warning 완화 |

## Prevention

- watchOS에서 `digitalCrownRotation`을 붙이는 화면은 가능하면 `ScrollView`와 분리한다.
- crown 입력이 필요한 sheet는 단일 focus host view를 두고 `@FocusState`로 진입 시 포커스를 명시한다.
- `Slider`, `ScrollView`, `List` 같은 내장 interaction container 위에 crown modifier를 직접 중첩할 때는 warning/log를 우선 확인한다.
