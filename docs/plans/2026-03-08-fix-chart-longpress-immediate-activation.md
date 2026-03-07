---
tags: [swiftui, charts, gesture, longpress, drag-gesture, timer]
date: 2026-03-08
category: plan
status: draft
---

# Fix: Chart Long-Press Immediate Activation

## Problem

모든 차트의 롱프레스 제스처가 롱프레스 직후 즉시 동작하지 않고, 손가락을 살짝 옆으로 이동해야 동작함.

### Root Cause

`DragGesture(minimumDistance: 0).onChanged`는 터치 시작 시 1회 호출되지만, 손가락이 정지 상태면 이후 호출되지 않음. `ChartSelectionGestureState.registerChange()`는 `onChanged` 콜백 내에서만 `holdDuration(0.18s)` 경과를 체크하므로, 손가락이 움직이지 않으면 `.pendingActivation` → `.selecting` 전환이 발생하지 않음.

### 흐름

```
Touch down → onChanged(1회) → registerChange: startTime 설정, return .inactive (elapsed=0)
Hold 0.18s → onChanged 미호출 (손가락 정지) → 상태 전환 없음
Slight move → onChanged 호출 → registerChange: elapsed>0.18s → return .activated ← 여기서야 동작
```

## Solution

터치 시작 시 `holdDuration` 후 타이머를 스케줄하여, 손가락이 움직이지 않아도 상태가 `.selecting`으로 전환되도록 함.

### 변경 사항

#### 1. `ChartSelectionGestureState` — `forceActivate()` 추가

```swift
mutating func forceActivate() -> ChartSelectionGestureUpdate {
    guard phase == .pendingActivation, !isCancelled else { return .inactive }
    phase = .selecting
    return .activated(restoreScrollPosition: initialScrollPosition)
}
```

#### 2. 12개 차트 View — 타이머 기반 활성화

각 차트에 `@State private var activationTask: Task<Void, Never>?` 추가.

`selectionGesture()` 수정:
- `onChanged`에서 `.inactive` 반환 시, `pendingActivation` 상태면 타이머 스케줄
- 타이머가 `holdDuration` 후 `forceActivate()` 호출 → `selectedDate` 설정
- `onEnded`에서 타이머 취소

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Presentation/Shared/Charts/ChartSelectionInteraction.swift` | `forceActivate()` 추가 |
| `DUNE/Presentation/Shared/Charts/BarChartView.swift` | 타이머 + 제스처 수정 |
| `DUNE/Presentation/Shared/Charts/AreaLineChartView.swift` | 타이머 + 제스처 수정 |
| `DUNE/Presentation/Shared/Charts/DotLineChartView.swift` | 타이머 + 제스처 수정 |
| `DUNE/Presentation/Shared/Charts/HeartRateChartView.swift` | 타이머 + 제스처 수정 |
| `DUNE/Presentation/Shared/Charts/RangeBarChartView.swift` | 타이머 + 제스처 수정 |
| `DUNE/Presentation/Shared/Charts/SleepStageChartView.swift` | 타이머 + 제스처 수정 |
| `DUNE/Presentation/Activity/Components/TrainingLoadChartView.swift` | 타이머 + 제스처 수정 |
| `DUNE/Presentation/Activity/TrainingReadiness/Components/ReadinessTrendChartView.swift` | 타이머 + 제스처 수정 |
| `DUNE/Presentation/Activity/TrainingReadiness/Components/SubScoreTrendChartView.swift` | 타이머 + 제스처 수정 |
| `DUNE/Presentation/Activity/TrainingVolume/Components/StackedVolumeBarChartView.swift` | 타이머 + 제스처 수정 |
| `DUNE/Presentation/Activity/TrainingVolume/ExerciseTypeDetailView.swift` | 타이머 + 제스처 수정 |
| `DUNE/Presentation/Activity/WeeklyStats/Components/DailyVolumeChartView.swift` | 타이머 + 제스처 수정 |

## Implementation Steps

### Step 1: `ChartSelectionGestureState.forceActivate()` 추가

`registerChange()` 아래에 `forceActivate()` 메서드 추가.

### Step 2: Scrollable 차트 5개 수정 (BarChart, AreaLine, DotLine, RangeBar, SleepStage)

스크롤 위치 복원 로직이 포함된 차트들:
- `@State private var activationTask: Task<Void, Never>?` 추가
- `selectionGesture()` 수정: `.inactive` 시 타이머 스케줄, `.activated` 시 타이머 취소
- `onEnded`에서 타이머 취소

### Step 3: Non-scrollable 차트 7개 수정

스크롤 복원 없는 간단한 패턴의 차트들:
- `@State private var activationTask: Task<Void, Never>?` 추가
- `selectionGesture()` 수정: 동일 패턴 (스크롤 복원 없음)

### Step 4: 테스트 작성

`ChartSelectionGestureState` 유닛 테스트 — `forceActivate()` 분기:
- idle에서 호출 → .inactive
- pendingActivation에서 호출 → .activated
- cancelled 상태에서 호출 → .inactive
- selecting에서 호출 → .inactive

## Test Strategy

- `ChartSelectionGestureStateTests`에 `forceActivate()` 테스트 케이스 추가
- UI 동작은 시뮬레이터에서 수동 검증 (차트 롱프레스 → 이동 없이 선택 활성화 확인)

## Risks

1. **`@State` Task 동기화**: Task가 `@MainActor`에서 실행되므로 `@State` 변경은 안전하지만, 제스처 `onEnded`와 타이머 완료의 레이스에 주의. 타이머 내 `Task.isCancelled` 체크로 방어.
2. **스크롤 복원 타이밍**: 타이머 기반 활성화 시 `initialScrollPosition`이 이미 캡처되어 있으므로 정상 복원 가능.

## Edge Cases

- 터치 후 `holdDuration` 내에 손가락 이동 → 타이머 + `registerChange` 중 먼저 도달하는 쪽이 처리. `isCancelled`로 중복 방지
- 터치 후 `holdDuration` 내에 손가락 떼기 → `onEnded`가 타이머 cancel
- `forceActivate()` 후 `registerChange()` 호출 → `isSelecting == true`이므로 `.updating` 반환. 정상 흐름
