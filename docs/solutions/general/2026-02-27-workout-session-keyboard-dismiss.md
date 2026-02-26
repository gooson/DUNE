---
tags: [ios, swiftui, keyboard, numberpad, workout-session, ux]
date: 2026-02-27
category: general
severity: important
status: implemented
related_files:
  - DUNE/Presentation/Exercise/WorkoutSessionView.swift
related_solutions: []
---

# WorkoutSession NumberPad Keyboard Dismiss Fix

## Problem

`WorkoutSessionView`의 weight/reps 입력은 `.decimalPad` / `.numberPad`를 사용한다.

### Symptoms

- 숫자 입력 후 키보드를 내릴 방법이 없어 하단 UI가 가려짐
- 화면 우측 상단 `Done`은 세트 완료 전 disabled 상태라 dismiss 버튼으로 사용할 수 없음

### Root Cause

`numberPad`/`decimalPad`는 기본 Return 키를 제공하지 않는데, 뷰에 키보드 전용 dismiss 경로(`.keyboard` toolbar + `FocusState`)가 없었다.

## Solution

`WorkoutSessionView`에 공용 포커스 상태와 키보드 전용 툴바 버튼을 추가했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | `@FocusState private var isInputFieldFocused` 추가 | TextField 포커스 상태를 명시적으로 제어하기 위해 |
| `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | `ToolbarItemGroup(placement: .keyboard)` + `Done` 버튼 추가 | 키보드 위에서 항상 dismiss 가능하게 하기 위해 |
| `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | stepper TextField에 `.focused`, `.submitLabel(.done)`, `.onSubmit` 적용 | 포커스 해제 동작 일관성 확보 |
| `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | `completeCurrentSet()`/`saveWorkout()` 시작 시 포커스 해제 | 액션 전환 시 키보드가 남지 않도록 보장 |

## Prevention

- `numberPad`/`decimalPad` 기반 입력 필드는 반드시 다음 중 하나를 포함한다:
  - `.toolbar(placement: .keyboard)` dismiss 버튼
  - 명시적 포커스 해제 경로 (`FocusState`)
- 화면 우측 상단의 저장/종료 버튼과 키보드 dismiss 책임을 분리한다.

### Checklist Addition

- [ ] `numberPad`/`decimalPad`를 도입한 화면은 포커스 해제 경로를 코드 리뷰에서 필수 확인

## Lessons Learned

키보드 타입이 Return 키를 제공하지 않는지 먼저 확인하고, 입력/저장 액션을 같은 `Done` 레이블에 혼합하지 않아야 UX 혼선을 줄일 수 있다.
