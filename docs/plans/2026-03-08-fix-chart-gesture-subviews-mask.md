---
tags: [chart, gesture, DragGesture, simultaneousGesture, GestureMask, long-press, scroll]
date: 2026-03-08
category: plan
status: approved
---

# Plan: 차트 제스처 전면 복원 — `including: .subviews` 제거

## Problem Statement

커밋 `96c5665e` ("Fix chart long press regressions")에서 11개 차트의
`.simultaneousGesture()`에 `including: .subviews`를 추가한 것이 근본 원인.

`GestureMask.subviews`는 Apple 공식 문서 기준:
> "Enable all gestures in the subview hierarchy but **disable the added gesture**."

결과적으로 selection DragGesture가 완전히 비활성화되어:
1. 롱프레스 선택 불가
2. 스크롤 불안정 (overlay Rectangle이 터치를 가로채지만 처리하지 않음)

## Affected Files (11)

| # | 파일 | 변경 내용 |
|---|------|----------|
| 1 | `DUNE/Presentation/Shared/Charts/BarChartView.swift` | `, including: .subviews` 삭제 |
| 2 | `DUNE/Presentation/Shared/Charts/DotLineChartView.swift` | 동일 |
| 3 | `DUNE/Presentation/Shared/Charts/AreaLineChartView.swift` | 동일 |
| 4 | `DUNE/Presentation/Shared/Charts/RangeBarChartView.swift` | 동일 |
| 5 | `DUNE/Presentation/Shared/Charts/SleepStageChartView.swift` | 동일 |
| 6 | `DUNE/Presentation/Shared/Charts/HeartRateChartView.swift` | 동일 |
| 7 | `DUNE/Presentation/Activity/TrainingReadiness/Components/ReadinessTrendChartView.swift` | 동일 |
| 8 | `DUNE/Presentation/Activity/TrainingReadiness/Components/SubScoreTrendChartView.swift` | 동일 |
| 9 | `DUNE/Presentation/Activity/WeeklyStats/Components/DailyVolumeChartView.swift` | 동일 |
| 10 | `DUNE/Presentation/Activity/Components/TrainingLoadChartView.swift` | 동일 |
| 11 | `DUNE/Presentation/Activity/TrainingVolume/Components/StackedVolumeBarChartView.swift` | 동일 |

## Implementation Steps

### Step 1: 11개 파일에서 `including: .subviews` 삭제

각 파일에서:
```swift
// BEFORE (broken)
.simultaneousGesture(
    selectionGesture(proxy: proxy, plotFrame: plotFrame),
    including: .subviews
)

// AFTER (fixed)
.simultaneousGesture(
    selectionGesture(proxy: proxy, plotFrame: plotFrame)
)
```

### Step 2: 빌드 검증

`scripts/build-ios.sh` 실행하여 컴파일 성공 확인.

### Step 3: 기존 테스트 통과 확인

`ChartSelectionInteractionTests.swift` 테스트 통과 확인.

## Test Strategy

- 기존 `ChartSelectionInteractionTests` 통과 (state machine 로직 검증)
- 새 테스트 불필요: 로직 변경 없음, 파라미터 삭제만

## Risks

| 리스크 | 확률 | 대응 |
|--------|------|------|
| `.all` 기본값에서 scroll과 selection 충돌 | 낮음 | 원래 작동하던 형태로 복원이므로 기존 state machine이 충돌 방지 |
| 다른 차트에서 예외적 동작 | 낮음 | 11개 모두 동일 패턴이므로 일괄 적용 안전 |

## Verification Criteria

1. 차트 좌우 스와이프 → 과거/미래 날짜로 스크롤
2. 차트 0.18초 이상 누르기 → 선택 오버레이 + haptic
3. 선택 중 드래그 → 다른 데이터 포인트로 이동
4. 손 떼기 → 오버레이 사라짐
