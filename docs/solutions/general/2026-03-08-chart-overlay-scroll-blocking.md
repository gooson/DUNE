---
tags: [swiftui, swift-charts, chart-overlay, gesture, long-press, scroll, selection, ui-testing, seeded-mock, regression]
category: general
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Shared/Charts/ChartSelectionInteraction.swift
  - DUNE/Presentation/Shared/Charts/ChartSelectionOverlay.swift
  - DUNE/Presentation/Shared/Charts/DotLineChartView.swift
  - DUNE/Presentation/Shared/Charts/AreaLineChartView.swift
  - DUNE/Presentation/Shared/Charts/HeartRateChartView.swift
  - DUNE/Presentation/Activity/TrainingReadiness/Components/ReadinessTrendChartView.swift
  - DUNE/Presentation/Activity/WeeklyStats/Components/DailyVolumeChartView.swift
  - DUNETests/ChartSelectionInteractionTests.swift
  - DUNEUITests/Regression/ChartInteractionRegressionUITests.swift
  - .claude/rules/testing-required.md
related_solutions:
  - docs/solutions/general/2026-03-08-sequence-gesture-dead-code-cleanup.md
---

# Solution: chartOverlay hit-testing으로 막히던 차트 스크롤 복구

## Problem

scrollable chart들이 `chartOverlay` 내부의 전체 영역 gesture에 selection을 직접 매달고 있었다. 이 구조에서는 overlay가 터치를 먼저 잡아 horizontal drag가 차트의 기본 scroll host까지 자연스럽게 전달되지 않았고, 이후 tap 기반 우회로 바꾸는 과정에서 selection model까지 흔들렸다.

### Symptoms

- 과거 데이터로 수평 스크롤이 잘 시작되지 않음
- shared detail chart에서 selection을 tap으로 바꾸면 tooltip/rule/dim 상태가 gesture 종료 후에도 남음
- shared/activity 차트마다 제스처 구현이 갈라져 회귀가 반복됨
- scroll 회귀 UI 테스트는 통과해도 selection 정확도나 cleanup 회귀는 놓칠 수 있음

### Root Cause

- `chartOverlay`를 표시 레이어가 아니라 full-surface interaction layer로 사용했다
- overlay hit-testing이 chart의 scroll arbitration에 개입했다
- tap 기반 fallback은 scroll 문제를 피했지만 long-press 기반 selection contract와 transient state cleanup을 깨뜨렸다
- 제스처 변경을 seeded/mock 데이터 기준으로 직접 재현하지 않아 interaction 회귀를 초기에 놓쳤다

## Solution

selection capture를 Swift Charts 기본 `chartXSelection`이나 overlay-local drag에 맡기지 않고, shared `scrollableChartSelectionOverlay(...)` modifier로 통일했다. 이 modifier는 `ChartLongPressSelectionRecognizer(UIViewRepresentable)`를 통해 long press를 chart container 바깥에서 관찰하고, overlay는 floating tooltip 렌더링만 담당한다.

scrollable chart에서는 다음 contract를 공통으로 유지한다.

- quick horizontal drag는 그대로 chart scroll
- long press 인식 후에는 pan을 끊고 selection에 집중
- long press 종료 후에는 scroll이 즉시 다시 가능
- scrollPosition이 바뀌면 stale overlay / selection state를 강제로 정리

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Charts/ChartSelectionOverlay.swift` | shared long-press recognizer, floating overlay 렌더링, scrollable selection modifier 추가 | 12개 차트의 interaction 진입점과 overlay rendering을 하나로 통일 |
| `DUNE/Presentation/Shared/Charts/ChartSelectionInteraction.swift` | selection lifecycle, nearest-point snap, stale selection cleanup, anchor/layout helper 공통화 | scroll/selection 경쟁과 snap-back 회귀를 한 곳에서 제어 |
| `DUNE/Presentation/Shared/Charts/*` + `DUNE/Presentation/Activity/**/Charts` | 12개 selection chart를 `scrollableChartSelectionOverlay(...)` 경로로 통일 | shared/activity 차트 간 UX contract 분리 제거 |
| `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift` | scroll, long press, cleanup, scroll-resume, no-snap-back regression 추가 | seeded/mock 데이터 기준 실제 interaction lifecycle 고정 |
| `DUNETests/ChartSelectionInteractionTests.swift` | stale selection cleanup helper 테스트 추가 | selection state machine의 종료 조건을 unit level에서 고정 |

### Key Code

```swift
.scrollableChartSelectionOverlay(
    isScrollable: timePeriod != nil,
    visibleDomainLength: timePeriod?.visibleDomainSeconds,
    scrollPosition: scrollPosition,
    selectedDate: $selectedDate,
    selectionState: $selectionGestureState
) { proxy, plotFrame, chartSize in
    if let point = selectedPoint,
       let anchor = selectedAnchor(for: point, proxy: proxy, plotFrame: plotFrame) {
        FloatingChartSelectionOverlay(
            date: point.date,
            value: formattedValue(point),
            anchor: anchor,
            chartSize: chartSize,
            plotFrame: plotFrame
        )
    }
}
```

검증에 사용한 회귀 테스트:

```swift
func testHRVDetailChartLongPressSelectionClearsAfterGesture() throws {
    let chart = waitForElement(AXID.detailChartSurface, timeout: 15)
    let selectionProbe = waitForElement(AXID.chartSelectionProbe, timeout: 10)

    let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.55))
    let end = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.55))
    start.press(forDuration: 0.45, thenDragTo: end)

    XCTAssertNotEqual(selectionProbe.label, "none")
    XCTAssertTrue(app.descendants(matching: .any)[AXID.chartSelectionOverlay].firstMatch.waitForNonExistence(timeout: 2))
}
```

## Prevention

같은 종류의 회귀를 막기 위해 interaction contract와 검증 규칙을 같이 고정한다.

### Checklist Addition

- [x] 동일 UX 차트는 shared interaction modifier/recognizer로 통일한다
- [x] long press 중 visible range가 밀리지 않는지 확인한다
- [x] selection 종료 후 scroll이 즉시 복구되는지 확인한다
- [x] selection 후 scroll하면 overlay/stale state가 정리되고 다음 long press가 이전 range로 snap-back 하지 않는지 확인한다
- [x] 제스처 변경은 seeded/mock 데이터로 직접 재현하고 결과를 남긴다

### Rule Addition (if applicable)

`.claude/rules/testing-required.md`에 다음 규칙을 추가했다.

- `tap`, `drag`, `long press`, `scroll`, selection arbitration 등 제스처 관련 변경은 반드시 seeded/mock 데이터로 직접 재현 검증
- 차트처럼 과거/이전 상태가 중요한 UI는 실제 사용자 흐름 기준 UI 테스트 또는 수동 재현 절차를 남김

## Lessons Learned

- scroll 회귀를 고쳤다고 해서 interaction regression이 끝난 게 아니다. selection activation, cleanup, scroll 공존 여부를 따로 검증해야 한다.
- `SpatialTapGesture` 같은 임시 우회나 화면별 patch는 당장 일부 케이스를 통과시켜도 공통 UX contract를 다시 깨뜨릴 수 있다.
- gesture 변경은 정적 코드 리뷰보다 seeded/mock 데이터 기반 실제 실행 검증이 훨씬 중요하다.
- interaction 버그는 해결 코드와 함께 테스트 규칙까지 남겨야 재발을 줄일 수 있다.
