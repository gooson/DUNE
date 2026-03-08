---
tags: [swiftui, swift-charts, chart-overlay, gesture, long-press, scroll, selection, ui-testing, seeded-mock, regression]
category: general
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Shared/Charts/DotLineChartView.swift
  - DUNE/Presentation/Shared/Charts/AreaLineChartView.swift
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

selection capture를 overlay에서 분리하고, scrollable shared chart들도 activity chart와 동일하게 `chartXSelection + chartGesture(LongPressGesture.sequenced(before: DragGesture))`로 통일했다. overlay는 floating tooltip 렌더링만 담당하도록 남기고 `.allowsHitTesting(false)`를 유지했다. 또한 HRV detail 차트에 selection probe 기반 regression UI test를 추가해 scroll만이 아니라 selection activation과 cleanup까지 검증하게 했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Charts/AreaLineChartView.swift` | shared area chart를 `chartXSelection + chartGesture` long-press flow로 복구 | scroll과 selection을 chart interaction system 안에서 같이 처리 |
| `DUNE/Presentation/Shared/Charts/BarChartView.swift` | tap selection 제거, gesture 종료 시 `selectedDate = nil` 정리 | sticky dim/rule 상태 제거 |
| `DUNE/Presentation/Shared/Charts/DotLineChartView.swift` | HRV detail 계열 차트에 long-press selection 복구 + test probe 추가 | seeded UI 테스트에서 selection activation 검증 가능하게 함 |
| `DUNE/Presentation/Shared/Charts/RangeBarChartView.swift` | tap selection 제거 후 shared contract에 맞춤 | range chart도 동일 회귀 방지 |
| `DUNE/Presentation/Shared/Charts/SleepStageChartView.swift` | stacked sleep chart selection 경로 통일 | scroll/selection arbitration 일관성 확보 |
| `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift` | HRV detail scroll + selection cleanup regression 추가 | seeded/mock 데이터 기준 직접 재현 검증 |
| `.claude/rules/testing-required.md` | gesture 변경 시 seeded/mock 검증 의무 규칙 추가 | 같은 종류의 검증 누락 방지 |

### Key Code

```swift
.chartXSelection(value: $selectedDate)
.chartGesture { proxy in
    LongPressGesture(minimumDuration: ChartSelectionInteraction.holdDuration)
        .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
        .onChanged { value in
            guard case .second(true, let drag) = value, let drag else { return }
            proxy.selectXValue(at: drag.location.x)
        }
        .onEnded { _ in
            selectedDate = nil
        }
}
.chartOverlay { proxy in
    GeometryReader { geometry in
        if let plotFrame = proxy.plotFrame.map({ geometry[$0] }) {
            ZStack(alignment: .topLeading) {
                if let point = selectedPoint,
                   let anchor = selectedAnchor(for: point, proxy: proxy, plotFrame: plotFrame) {
                    FloatingChartSelectionOverlay(...)
                }
            }
            .allowsHitTesting(false)
        }
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

- [x] `chartOverlay`에 full-surface selection gesture를 다시 붙이지 않는다
- [x] scrollable chart selection은 `chartXSelection + chartGesture(_:)` 우선으로 검토한다
- [x] selection UI는 long-press 중에만 유지되고 종료 시 정리되는지 확인한다
- [x] 제스처 변경은 seeded/mock 데이터로 직접 재현하고 결과를 남긴다

### Rule Addition (if applicable)

`.claude/rules/testing-required.md`에 다음 규칙을 추가했다.

- `tap`, `drag`, `long press`, `scroll`, selection arbitration 등 제스처 관련 변경은 반드시 seeded/mock 데이터로 직접 재현 검증
- 차트처럼 과거/이전 상태가 중요한 UI는 실제 사용자 흐름 기준 UI 테스트 또는 수동 재현 절차를 남김

## Lessons Learned

- scroll 회귀를 고쳤다고 해서 interaction regression이 끝난 게 아니다. selection activation, cleanup, scroll 공존 여부를 따로 검증해야 한다.
- `SpatialTapGesture` 같은 임시 우회는 당장 스크롤 테스트를 통과시킬 수 있어도 원래 UX contract를 깨뜨릴 수 있다.
- gesture 변경은 정적 코드 리뷰보다 seeded/mock 데이터 기반 실제 실행 검증이 훨씬 중요하다.
- interaction 버그는 해결 코드와 함께 테스트 규칙까지 남겨야 재발을 줄일 수 있다.
