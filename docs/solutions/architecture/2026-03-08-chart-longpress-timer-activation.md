---
tags: [chart, gesture, longpress, DragGesture, timer, SwiftUI]
date: 2026-03-08
category: solution
status: implemented
---

# 차트 롱프레스 즉시 활성화 (Timer-Based Activation)

## Problem

모든 차트(12개)의 롱프레스 선택이 손가락을 가만히 누르고 있을 때 활성화되지 않고, 살짝 옆으로 이동해야만 동작하는 버그.

### Root Cause

`DragGesture(minimumDistance: 0).onChanged`는 첫 터치에서 1회 호출된 후, 손가락이 정지해 있으면 다시 호출되지 않음. `ChartSelectionGestureState.registerChange()`의 `holdDuration` 경과 체크는 `onChanged` 호출 시에만 실행되므로, 손가락이 움직이지 않으면 활성화 조건을 영영 확인하지 못함.

## Solution

### 1. `forceActivate()` 메서드 추가

`ChartSelectionGestureState`에 타이머 기반 강제 활성화 메서드 추가:

```swift
mutating func forceActivate() -> ChartSelectionGestureUpdate {
    guard phase == .pendingActivation, !isCancelled else { return .inactive }
    phase = .selecting
    return .activated(restoreScrollPosition: initialScrollPosition)
}
```

### 2. `makeActivationTask()` 헬퍼로 DRY

12개 뷰에서 반복되던 타이머 Task 생성 로직을 `ChartSelectionInteraction.makeActivationTask()`로 추출:

```swift
@MainActor
static func makeActivationTask(
    location: CGPoint,
    proxy: ChartProxy,
    plotFrame: CGRect,
    activate: @MainActor @escaping () -> ChartSelectionGestureUpdate,
    onActivated: @MainActor @escaping (_ selectedDate: Date?, _ restoreScrollPosition: Date?) -> Void
) -> Task<Void, Never>
```

### 3. 각 뷰의 호출 패턴

```swift
// 비스크롤 차트:
activationTask = ChartSelectionInteraction.makeActivationTask(
    location: location, proxy: proxy, plotFrame: plotFrame,
    activate: { selectionGestureState.forceActivate() },
    onActivated: { date, _ in selectedDate = date }
)

// 스크롤 차트:
activationTask = ChartSelectionInteraction.makeActivationTask(
    location: location, proxy: proxy, plotFrame: plotFrame,
    activate: { selectionGestureState.forceActivate() },
    onActivated: { date, restoreScroll in
        if let restoreScroll { scrollPosition = restoreScroll }
        selectedDate = date
    }
)
```

## Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `ChartSelectionInteraction.swift` | `forceActivate()` + `makeActivationTask()` 추가 |
| `BarChartView.swift` | 헬퍼 호출로 전환 |
| `AreaLineChartView.swift` | 헬퍼 호출로 전환 |
| `DotLineChartView.swift` | 헬퍼 호출로 전환 (optional Binding) |
| `RangeBarChartView.swift` | 헬퍼 호출로 전환 |
| `SleepStageChartView.swift` | 헬퍼 호출로 전환 |
| `HeartRateChartView.swift` | 헬퍼 호출로 전환 |
| `TrainingLoadChartView.swift` | 헬퍼 호출로 전환 |
| `ReadinessTrendChartView.swift` | 헬퍼 호출로 전환 |
| `SubScoreTrendChartView.swift` | 헬퍼 호출로 전환 |
| `StackedVolumeBarChartView.swift` | 헬퍼 호출로 전환 |
| `ExerciseTypeDetailView.swift` | 헬퍼 호출로 전환 |
| `DailyVolumeChartView.swift` | 헬퍼 호출로 전환 |

## Prevention

- `DragGesture`로 롱프레스 구현 시 `onChanged`가 정지 상태에서 호출되지 않음을 인지
- 타이머(Task.sleep) 기반 fallback 활성화가 필수
- 새 차트 추가 시 `makeActivationTask()` 헬퍼 재사용

## Key Insight

SwiftUI `DragGesture.onChanged`는 translation이 변경될 때만 호출됨. `minimumDistance: 0`으로 설정해도 터치 후 이동 없이 정지하면 후속 호출이 없음. 이는 `LongPressGesture`와 결합하지 않고 `DragGesture` 단독으로 롱프레스를 구현할 때 반드시 고려해야 하는 제약.
