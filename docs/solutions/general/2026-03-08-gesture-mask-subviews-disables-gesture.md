---
tags: [swiftui, gesture, chart, simultaneousGesture, GestureMask]
date: 2026-03-08
category: solution
status: implemented
---

# GestureMask.subviews가 추가된 제스처를 비활성화하는 문제

## Problem

`.simultaneousGesture(gesture, including: .subviews)`를 사용하면 추가된 제스처가 완전히 비활성화됨.
12개 차트 뷰에서 롱프레스 선택과 스크롤 복원이 모두 동작하지 않는 버그 발생.

### 증상
- 차트 롱프레스 → 선택 오버레이 표시 안 됨
- 과거 날짜로 스크롤 → 스크롤은 동작하나 선택 불가
- 모든 차트(Bar, DotLine, AreaLine, Range, HeartRate, Sleep 등) 동일 증상

### 원인
commit `96c5665e`에서 "차트 롱프레스 회귀 수정"으로 `including: .subviews` 추가.
Apple 문서에 따르면:
- `.all` (기본값): 추가된 제스처 + 하위 뷰 제스처 모두 활성화
- `.subviews`: 하위 뷰 제스처만 활성화, **추가된 제스처는 비활성화**
- `.gesture`: 추가된 제스처만 활성화, 하위 뷰 제스처는 비활성화

## Solution

`including: .subviews` 파라미터를 제거하여 기본값 `.all`로 복원.

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

### 영향 파일 (12개)
- `Shared/Charts/BarChartView.swift`
- `Shared/Charts/DotLineChartView.swift`
- `Shared/Charts/AreaLineChartView.swift`
- `Shared/Charts/RangeBarChartView.swift`
- `Shared/Charts/HeartRateChartView.swift`
- `Shared/Charts/SleepStageChartView.swift`
- `Activity/TrainingReadiness/Components/ReadinessTrendChartView.swift`
- `Activity/TrainingReadiness/Components/SubScoreTrendChartView.swift`
- `Activity/WeeklyStats/Components/DailyVolumeChartView.swift`
- `Activity/TrainingVolume/Components/StackedVolumeBarChartView.swift`
- `Activity/Components/TrainingLoadChartView.swift`
- `Activity/TrainingVolume/ExerciseTypeDetailView.swift`

## Prevention

1. `.simultaneousGesture`의 `including:` 파라미터 사용 금지 → `swiftui-patterns.md`에 규칙 추가 완료
2. 제스처 충돌은 `ChartSelectionGestureState` 상태 머신으로 해결 (hold 0.18s → 선택 활성화, 스크롤 비활성화)
3. GestureMask 의미를 혼동하기 쉬우므로, 사용 전 반드시 Apple 문서 확인:
   - `.all` = 추가 + 하위 모두 활성
   - `.subviews` = 하위만 활성 (추가 비활성!)
   - `.gesture` = 추가만 활성 (하위 비활성)
