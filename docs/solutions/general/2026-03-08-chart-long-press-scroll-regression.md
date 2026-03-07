---
tags: [charts, swiftui, gesture, regression, xcuitest, accessibility, scroll-restoration]
category: general
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Shared/Charts/ChartSelectionInteraction.swift
  - DUNE/Presentation/Shared/Charts/AreaLineChartView.swift
  - DUNE/Presentation/Activity/WeeklyStats/Components/DailyVolumeChartView.swift
  - DUNE/Presentation/Shared/Charts/ChartSelectionOverlay.swift
  - DUNETests/ChartSelectionInteractionTests.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
  - DUNEUITests/Regression/ChartInteractionRegressionUITests.swift
related_solutions: []
---

# Solution: Chart Long-Press Scroll Regression and Coverage Hardening

## Problem

공통 차트의 long-press selection 구현이 `DragGesture` 기반으로 바뀐 뒤, 주간 차트에서 손가락을 길게 누를 때 selection보다 가로 스크롤이 먼저 먹으면서 기간이 바뀐 것처럼 보이는 회귀가 생겼다. Activity 차트 일부는 아직 이전 `chartXSelection` 경로를 유지하고 있어 차트별 UX도 달랐다. 첫 번째 UI regression test도 seeded detail 진입 경로가 불안정하고, selection이 실제로 활성화됐는지 확인하지 않아 skip/false-pass 가능성이 남아 있었다.

### Symptoms

- 주간 차트 long press 시 월간으로 바뀐 것처럼 보임
- long press 중 차트 visible range가 좁아지거나 이동함
- 일부 Activity 차트는 공통 floating selection overlay UX를 따르지 않음
- 초기 UI regression test는 seed 상태에 따라 skip 되었고, selection 실패여도 통과할 수 있었음

### Root Cause

`selectedDate == nil` 여부만으로 scroll 가능 상태를 제어하던 구조라, hold 임계시간을 넘기기 전까지는 scroll이 계속 살아 있었다. 그 사이에 주간 차트가 먼저 수평 이동하면서 selection 의도와 scroll 의도가 섞였다. 동시에 Activity 차트 몇 개는 shared helper를 쓰지 않아 interaction contract가 분산돼 있었다. 검증 측면에서는 test가 unstable Wellness detail seed에 기대고 있었고, visible range label만 비교해서 "selection이 실제로 떴는지"를 관찰하지 못했다.

## Solution

long-press interaction을 `idle -> pendingActivation -> selecting` 상태로 분리한 gesture state machine으로 올리고, activation 순간에는 기존 scroll position을 복원한 뒤 selection 전용 상태로 전환했다. Shared/Activity selection charts를 모두 같은 floating overlay contract로 맞췄다. 이후 review에서 남은 검증 공백을 닫기 위해 seeded Activity weekly-stats 경로를 쓰는 UI regression test로 바꾸고, test 전용 selection probe를 추가해 period 불변성과 selection activation을 동시에 확인하도록 강화했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Charts/ChartSelectionInteraction.swift` | gesture phase/update 모델 추가 | hold 중 scroll과 selection 전환을 명시적으로 제어 |
| `DUNE/Presentation/Shared/Charts/*ChartView.swift` | `allowsScroll` 기반 scroll gating + scroll position restore 적용 | long press activation 전후의 스크롤 회귀 제거 |
| `DUNE/Presentation/Activity/**/*ChartView.swift` | `chartXSelection` 제거, floating overlay + shared helper로 통합 | Activity 차트 UX 일관성 확보 |
| `DUNETests/ChartSelectionInteractionTests.swift` | phase/update/restoreScrollPosition 검증 추가 | gesture state machine 회귀 방지 |
| `DUNE/Presentation/Shared/Charts/ChartSelectionOverlay.swift` | `--uitesting` 전용 selection probe modifier 추가 | UI test에서 selection activation을 안정적으로 관찰 |
| `DUNE/Presentation/Activity/WeeklyStats/Components/DailyVolumeChartView.swift` | probe label을 selected point 변화에 연결 | 대표 Activity 차트에서 selection 발생 여부를 외부에서 검증 |
| `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift` | seeded Activity weekly stats 경로로 회귀 테스트 재작성 | skip 가능한 seed 의존성을 제거하고 false-pass를 방지 |

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

```swift
Rectangle()
    .fill(Color.black.opacity(0.001))
    .frame(width: 12, height: 12)
    .allowsHitTesting(false)
    .accessibilityElement()
    .accessibilityIdentifier("chart-selection-probe")
    .accessibilityLabel(label)
```

## Prevention

selection gesture가 들어가는 차트는 “hold 대기”, “selection 활성화”, “scroll 차단”을 helper state에 모두 위임해야 한다. 새 차트가 생겨도 개별 뷰에서 `chartXSelection`과 별도 overlay를 다시 도입하지 않도록 유지한다. UI regression test는 “보이면 안 되는 부작용이 없었다”만 보지 말고, selection이 실제로 활성화됐다는 positive signal도 함께 확인해야 한다.

### Checklist Addition

- [ ] scrollable chart의 long press는 activation 전후 scroll 상태를 명시적으로 테스트한다
- [ ] Activity 차트 신규 추가 시 shared chart selection contract 사용 여부를 확인한다
- [ ] UI regression test는 period/visible-range 불변성과 selection activation을 함께 검증한다
- [ ] UI-test 전용 probe는 `--uitesting` gate 아래에서만 노출한다
- [ ] optional detail path보다 seeded 대표 차트 경로를 우선 선택한다

### Rule Addition (if applicable)

없음

## Lessons Learned

Swift Charts 제스처 회귀는 selection view 코드보다도 “scroll과 selection의 우선순위”에서 더 자주 발생한다. interaction helper를 modifier 수준에 두기보다 상태 기계로 끌어올려야 여러 차트에서 같은 UX를 안정적으로 재사용할 수 있다. 또 UI regression test는 "변하지 않았다"만으로는 부족하고, 의도한 interaction이 실제로 발생했다는 관측점이 있어야 리뷰 후속 이슈를 줄일 수 있다.
