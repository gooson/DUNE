---
tags: [swift-charts, gesture, SequenceGesture, dead-code, DRY, state-machine, LongPressGesture, chart-selection]
category: architecture
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Shared/Charts/ChartSelectionInteraction.swift
  - DUNE/Presentation/Shared/Charts/AreaLineChartView.swift
  - DUNE/Presentation/Shared/Charts/BarChartView.swift
  - DUNE/Presentation/Shared/Charts/RangeBarChartView.swift
  - DUNE/Presentation/Shared/Charts/DotLineChartView.swift
  - DUNE/Presentation/Shared/Charts/SleepStageChartView.swift
  - DUNE/Presentation/Shared/Charts/HeartRateChartView.swift
  - DUNETests/ChartSelectionInteractionTests.swift
related_solutions:
  - docs/solutions/general/2026-03-08-chart-long-press-scroll-regression.md
  - docs/solutions/general/2026-03-08-common-chart-selection-overlay.md
---

# Solution: SequenceGesture 전환 후 Dead Code 제거 및 패턴 단순화

## Problem

### Symptoms

- `ChartSelectionGestureState`에 `registerChange`, `startTime`, `isCancelled`, `pendingActivation` 등 production에서 호출되지 않는 dead code가 40줄+ 잔존
- 12개 차트 뷰의 `selectionGesture` 클로저에 `switch value { case .first(true): ... case .second(true, let drag): ... }` 패턴이 동일하게 반복 (DRY 위반)
- `.first(true)` case에서 `beginSelection` 호출 후 `.second` case에서도 동일 호출 — 불필요한 중복
- `beginSelection`에 idempotency guard 없어 `.second` 호출 시 `initialScrollPosition` 덮어쓰기 가능

### Root Cause

`DragGesture(minimumDistance: 0)` → `LongPressGesture.sequenced(before: DragGesture)` 전환 시, 새 `beginSelection` 메서드를 추가했지만 old state machine (`registerChange` + `ChartSelectionGestureUpdate` + `pendingActivation` phase)을 제거하지 않았음. `SequenceGesture.Value`의 `.first(true)` / `.second(true, _)` 양쪽에서 `beginSelection`을 호출하는 보수적 패턴을 채택하면서 불필요한 분기와 guard 중복이 발생.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `ChartSelectionInteraction.swift` | `registerChange` 메서드 삭제 (30줄) | production 호출자 없음 |
| `ChartSelectionInteraction.swift` | `ChartSelectionGestureUpdate` enum 삭제 | `registerChange` 전용 반환 타입 |
| `ChartSelectionInteraction.swift` | `pendingActivation` case 삭제 | `registerChange` 전용 상태 |
| `ChartSelectionInteraction.swift` | `startTime`, `isCancelled` 프로퍼티 삭제 | `registerChange` 전용 상태 |
| `ChartSelectionInteraction.swift` | `activationDistance` 상수 삭제 | `registerChange` 전용 임계값 |
| `ChartSelectionInteraction.swift` | `CGSize.magnitude` extension 삭제 | `registerChange` 전용 유틸 |
| `ChartSelectionInteraction.swift` | `beginSelection`에 `guard !isSelecting` 추가 | idempotency 보장 |
| 12 chart views | `switch` → `guard case .second` 단순화 | `.first(true)` 불필요 |
| `ChartSelectionInteractionTests.swift` | `registerChange` 테스트 → `beginSelection` 테스트 교체 | dead code 테스트 제거 |

### Key Code

**Before (각 차트 뷰 — ~17줄):**
```swift
.onChanged { value in
    switch value {
    case .first(true):
        if !selectionGestureState.isSelecting {
            selectionGestureState.beginSelection(scrollPosition: scrollPosition)
        }
    case .second(true, let drag):
        if !selectionGestureState.isSelecting {
            selectionGestureState.beginSelection(scrollPosition: scrollPosition)
        }
        guard let drag else { return }
        // ... selection logic
    default: break
    }
}
```

**After (각 차트 뷰 — ~7줄):**
```swift
.onChanged { value in
    guard case .second(true, let drag) = value, let drag else { return }
    selectionGestureState.beginSelection(scrollPosition: scrollPosition)
    // ... selection logic
}
```

**`beginSelection` idempotency guard:**
```swift
mutating func beginSelection(scrollPosition: Date?) {
    guard !isSelecting else { return }  // 추가
    phase = .selecting
    initialScrollPosition = scrollPosition
}
```

### 결과

- `ChartSelectionGestureState`: 78줄 → 42줄 (46% 감소)
- 12개 차트 뷰 제스처 클로저: 각 ~17줄 → ~7줄 (59% 감소)
- 전체: -124줄 순감소

## Prevention

### SequenceGesture.Value 패턴 가이드

`LongPressGesture.sequenced(before: DragGesture)` 사용 시:

1. **`.first(true)` 무시**: LongPress 인식 시점이지만, drag 데이터가 없어 유용한 작업 불가. 이 이벤트를 처리하면 drag location 없이 상태를 변경하는 부작용 발생
2. **`.second(true, let drag)` only**: 항상 `guard case .second(true, let drag) = value, let drag else { return }` 패턴 사용
3. **상태 전환 idempotency**: `beginSelection` 같은 상태 전환 함수는 내부에 `guard !isSelecting` 포함 — 외부에서 반복 호출 가능

### Checklist Addition

- [ ] 제스처 방식 전환 후 이전 방식의 코드가 dead code로 남아 있지 않은가
- [ ] `SequenceGesture.Value` 처리에 `.first(true)` case가 불필요하게 포함되지 않았는가
- [ ] 상태 전환 함수에 idempotency guard가 있는가

## Lessons Learned

1. **제스처 방식 전환은 2단계로**: (1) 새 방식 적용 + 동작 검증, (2) old 방식 코드 제거. 한 번에 하면 범위가 커지고, 2단계로 나누면 각 단계에서 안전하게 검증 가능
2. **`.first(true)` 함정**: `SequenceGesture`의 `.first` 이벤트는 첫 번째 제스처(LongPress) 인식 시 발생하지만, 두 번째 제스처(Drag)의 데이터가 없음. 이 시점에서 상태 변경하면 drag location 없이 scroll position이 캡처되어 stale 값이 저장될 수 있음
3. **idempotency는 메서드 내부에**: 호출자가 guard하는 대신 메서드 자체에 guard를 넣으면 12곳의 중복 guard를 1곳으로 통합 가능
