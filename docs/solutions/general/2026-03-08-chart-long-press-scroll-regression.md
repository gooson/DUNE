---
tags: [swiftui, swift-charts, gesture, long-press, scroll, selection, snap-back, seeded-mock, xcuitest, regression]
category: general
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Shared/Charts/ChartSelectionInteraction.swift
  - DUNE/Presentation/Shared/Charts/ChartSelectionOverlay.swift
  - DUNE/Presentation/Shared/Charts/DotLineChartView.swift
  - DUNE/Presentation/Shared/Charts/AreaLineChartView.swift
  - DUNE/Presentation/Activity/WeeklyStats/Components/DailyVolumeChartView.swift
  - DUNETests/ChartSelectionInteractionTests.swift
  - DUNEUITests/Regression/ChartInteractionRegressionUITests.swift
  - .claude/rules/testing-required.md
  - .claude/rules/documentation-standards.md
  - docs/corrections-active.md
related_solutions:
  - docs/solutions/general/2026-03-08-chart-overlay-scroll-blocking.md
  - docs/solutions/general/2026-03-08-common-chart-selection-overlay.md
---

# Solution: Chart Long-Press Scroll Regression And Lifecycle Coverage Hardening

## Problem

차트 스크롤을 복구한 뒤에도 long-press selection lifecycle은 계속 흔들렸다. 어떤 화면에서는 long press가 잘 안 잡혔고, 어떤 화면에서는 long press 중 visible range가 같이 움직였으며, 손을 뗀 뒤 스크롤하면 stale overlay가 남거나 다음 long press에서 이전 월로 snap-back 되는 회귀가 반복됐다.

### Symptoms

- quick drag는 되는데 long press selection이 잘 시작되지 않음
- long press 중 차트가 같이 수평 스크롤되어 원하는 값을 읽기 어려움
- long press 해제 후 스크롤하면 overlay가 남아 있거나 selection state가 정리되지 않음
- 다시 long press 하면 이전 `scrollPosition`으로 돌아가 visible range가 튀는 현상이 발생함
- 차트마다 제스처 구현이 달라 한 화면에서 고친 회귀가 다른 화면에서 다시 생김

### Root Cause

원인은 한 가지가 아니었다.

- selection capture가 차트별 로컬 gesture patch에 흩어져 있었다
- `chartOverlay`가 터치 표면과 표시 레이어 역할을 동시에 맡으면서 scroll arbitration이 계속 흔들렸다
- long press 종료, 범위 이탈, 이후 스크롤 같은 lifecycle cleanup이 공통 helper에 없었다
- 검증도 "과거 데이터로 스크롤되는지" 위주라서 `selection activation`, `scroll resume`, `overlay cleanup`, `no snap-back` 같은 후속 회귀를 놓칠 수 있었다

## Solution

12개 selection chart를 shared `scrollableChartSelectionOverlay(...)` contract로 통일하고, 입력은 `ChartLongPressSelectionRecognizer`가 담당하게 정리했다. recognizer는 chart container 바깥에서 long press를 감지하고, selection이 활성화되면 pan 경쟁을 끊어 값 확인에 집중하게 한다. 동시에 `ChartSelectionInteraction.clearSelection(...)`과 `scrollPosition` 변경 감시를 추가해 long press 종료 후 stale overlay/selection/restore state를 즉시 정리하도록 만들었다.

검증도 seeded/mock 기준 lifecycle regression으로 넓혔다. 이제 단순히 "스크롤된다"만 보지 않고 long press selection, long press 중 no-scroll, release 후 scroll resume, scroll-after-selection cleanup, no snap-back, chart 표면에서 시작한 부모 vertical scroll까지 같이 확인한다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Charts/ChartSelectionOverlay.swift` | `scrollableChartSelectionOverlay(...)`, `ChartLongPressSelectionRecognizer`, `scrollPosition` 변경 시 cleanup 경로 추가 | 12개 차트의 long-press capture와 stale overlay cleanup을 공통 contract로 묶기 위해 |
| `DUNE/Presentation/Shared/Charts/ChartSelectionInteraction.swift` | `holdDuration`, `allowableMovement`, `clearSelection(...)`, `handleLongPressSelection(...)` 공통화 | long press 인식 안정성, active selection 중 pan 차단, 종료/이탈 cleanup을 한 곳에서 제어하기 위해 |
| `DUNE/Presentation/Shared/Charts/*` + `DUNE/Presentation/Activity/**` | 개별 `chartXSelection`, `SpatialTapGesture`, 로컬 gesture patch 제거 후 shared modifier 적용 | 차트 종류와 화면에 관계없이 같은 interaction lifecycle을 보장하기 위해 |
| `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift` | HRV detail / Weekly Stats seeded regression 확장 | quick drag, long press, vertical scroll, cleanup, no snap-back을 실제 사용자 흐름으로 고정하기 위해 |
| `DUNETests/ChartSelectionInteractionTests.swift` | `clearSelection` unit coverage 추가 | gesture 종료 시 상태 정리가 깨지는 회귀를 UI 이전 레벨에서 막기 위해 |

### Key Code

```swift
ChartLongPressSelectionRecognizer(
    minimumPressDuration: ChartSelectionInteraction.holdDuration
) { state, location in
    ChartSelectionInteraction.handleLongPressSelection(
        state: state,
        location: location,
        proxy: proxy,
        plotFrame: plotFrame,
        selectionState: $selectionState,
        selectedDate: $selectedDate,
        scrollPosition: scrollPosition
    )
}
```

```swift
.onChange(of: scrollPosition.wrappedValue) { _, _ in
    ChartSelectionInteraction.clearSelection(
        selectionState: $selectionState,
        selectedDate: $selectedDate
    )
}
```

## Prevention

차트 제스처는 "스크롤된다" 한 가지로 끝내면 안 된다. 앞으로는 같은 selection UX를 가진 차트는 반드시 shared modifier/recognizer/state cleanup 경로를 사용하고, 개별 화면에서 임시 gesture patch를 다시 만들지 않는다. 또한 gesture 변경은 seeded/mock 데이터로 lifecycle 전체를 직접 재현한 뒤 문서와 규칙까지 같은 턴에 갱신한다.

### Checklist Addition

- [x] 동일 selection UX 차트는 shared `scrollableChartSelectionOverlay(...)` contract로 통일한다
- [x] quick drag가 selection 없이 과거 데이터 스크롤을 유지하는지 확인한다
- [x] long press 중 visible range가 변하지 않는지 확인한다
- [x] long press 해제 직후 horizontal scroll이 즉시 다시 가능한지 확인한다
- [x] selection 후 스크롤하면 overlay/state가 정리되고 다음 long press에서 snap-back이 없는지 확인한다
- [x] 차트 표면에서 시작한 vertical drag가 부모 화면 스크롤을 막지 않는지 확인한다

### Rule Addition (if applicable)

관련 규칙과 교정사항을 함께 남겼다.

- `.claude/rules/testing-required.md`에 chart gesture lifecycle seeded/mock 검증 체크리스트 추가
- `.claude/rules/documentation-standards.md`에 solution 문서가 최종 merged 구현과 일치해야 한다는 규칙 추가
- `docs/corrections-active.md`에 `#228~#230`으로 chart interaction contract, lifecycle regression, solution-doc 동기화 교정사항 추가

## Lessons Learned

- 차트 제스처 버그는 단일 gesture 수정으로 끝나지 않고 `activation`, `competition`, `cleanup`, `resume`까지 한 묶음으로 봐야 한다.
- `SpatialTapGesture`나 화면별 overlay patch 같은 우회로는 일시적으로 한 증상만 가릴 수 있고, 다음 회귀를 더 찾기 어렵게 만든다.
- seeded/mock UI regression은 "보였다/안 보였다" 수준이 아니라 interaction lifecycle 전체를 관찰해야 실제 사용자 이슈를 막을 수 있다.
