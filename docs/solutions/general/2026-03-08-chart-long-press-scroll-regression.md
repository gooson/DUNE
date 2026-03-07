---
tags: [charts, swiftui, gesture, regression]
category: general
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Shared/Charts/ChartSelectionInteraction.swift
  - DUNE/Presentation/Shared/Charts/AreaLineChartView.swift
  - DUNE/Presentation/Activity/WeeklyStats/Components/DailyVolumeChartView.swift
  - DUNETests/ChartSelectionInteractionTests.swift
  - DUNEUITests/Regression/ChartInteractionRegressionUITests.swift
related_solutions: []
---

# Solution: Chart Long-Press Scroll Regression

## Problem

공통 차트의 long-press selection 구현이 `DragGesture` 기반으로 바뀐 뒤, 주간 차트에서 손가락을 길게 누를 때 selection보다 가로 스크롤이 먼저 먹으면서 기간이 바뀐 것처럼 보이는 회귀가 생겼다. Activity 차트 일부는 아직 이전 `chartXSelection` 경로를 유지하고 있어서 차트별 UX도 달라졌다.

### Symptoms

- 주간 차트 long press 시 월간으로 바뀐 것처럼 보임
- long press 중 차트 visible range가 좁아지거나 이동함
- 일부 Activity 차트는 공통 floating selection overlay UX를 따르지 않음

### Root Cause

`selectedDate == nil` 여부만으로 scroll 가능 상태를 제어하던 구조라, hold 임계시간을 넘기기 전까지는 scroll이 계속 살아 있었다. 그 사이에 주간 차트가 먼저 수평 이동하면서 selection 의도와 scroll 의도가 섞였다. 동시에 Activity 차트 몇 개는 shared helper를 쓰지 않아 interaction contract가 분산돼 있었다.

## Solution

long-press interaction을 `idle -> pendingActivation -> selecting` 상태로 분리한 gesture state machine으로 올리고, activation 순간에는 기존 scroll position을 복원한 뒤 selection 전용 상태로 전환했다. Shared/Activity selection charts를 모두 같은 floating overlay contract로 맞췄다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Charts/ChartSelectionInteraction.swift` | gesture phase/update 모델 추가 | hold 중 scroll과 selection 전환을 명시적으로 제어 |
| `DUNE/Presentation/Shared/Charts/*ChartView.swift` | `allowsScroll` 기반 scroll gating + scroll position restore 적용 | long press activation 전후의 스크롤 회귀 제거 |
| `DUNE/Presentation/Activity/**/*ChartView.swift` | `chartXSelection` 제거, floating overlay + shared helper로 통합 | Activity 차트 UX 일관성 확보 |
| `DUNETests/ChartSelectionInteractionTests.swift` | phase/update/restoreScrollPosition 검증 추가 | gesture state machine 회귀 방지 |
| `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift` | chart regression UI test 골격 추가, 현재 seed 부족 시 skip | gesture UI coverage 경로를 문서화하고 future-ready 상태로 유지 |

### Key Code

```swift
switch selectionGestureState.registerChange(
    at: value.time,
    translation: value.translation,
    currentScrollPosition: scrollPosition
) {
case .inactive:
    return
case .activated(let restoreScrollPosition):
    if let restoreScrollPosition {
        scrollPosition = restoreScrollPosition
    }
    fallthrough
case .updating:
    selectedDate = ChartSelectionInteraction.resolvedDate(
        at: value.location,
        proxy: proxy,
        plotFrame: plotFrame
    )
}
```

## Prevention

selection gesture가 들어가는 차트는 “hold 대기”, “selection 활성화”, “scroll 차단”을 helper state에 모두 위임해야 한다. 새 차트가 생겨도 개별 뷰에서 `chartXSelection`과 별도 overlay를 다시 도입하지 않도록 유지한다.

### Checklist Addition

- [ ] scrollable chart의 long press는 activation 전후 scroll 상태를 명시적으로 테스트한다
- [ ] Activity 차트 신규 추가 시 shared chart selection contract 사용 여부를 확인한다
- [ ] UI seed가 detail chart 진입 경로를 실제로 노출하는지 함께 점검한다

### Rule Addition (if applicable)

없음

## Lessons Learned

Swift Charts 제스처 회귀는 selection view 코드보다도 “scroll과 selection의 우선순위”에서 더 자주 발생한다. interaction helper를 modifier 수준에 두기보다 상태 기계로 끌어올려야 여러 차트에서 같은 UX를 안정적으로 재사용할 수 있다.
