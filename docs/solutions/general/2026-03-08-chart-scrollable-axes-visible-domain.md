---
tags: [swift-charts, scrollableAxes, visibleDomain, gesture, regression]
date: 2026-03-08
category: solution
status: implemented
---

# chartScrollableAxes 토글이 visibleDomain을 무효화하는 문제

## Problem

차트에서 롱프레스 선택 시 `.chartScrollableAxes`를 `.horizontal`에서 `[]`로 전환하면, `.chartXVisibleDomain(length:)`가 무시되어 버퍼링된 전체 데이터(주간 뷰 기준 ~5주)가 한 번에 렌더링됨. 사용자에게는 주간 차트가 월간으로 전환된 것처럼 보임.

### 근본 원인

Apple Swift Charts는 `.chartXVisibleDomain`을 **scrollable 차트에서만** 적용한다. `.chartScrollableAxes([])`로 스크롤 축을 제거하면 visibleDomain 제약도 함께 해제되어, 데이터 소스의 전체 범위가 차트에 표시된다.

이전 해결책(`chart-long-press-scroll-regression.md`)에서 `ChartSelectionGestureState.allowsScroll`을 도입하면서 `.chartScrollableAxes(allowsScroll ? .horizontal : [])`로 구현한 것이 회귀 원인.

## Solution

### 핵심: scrollableAxes와 scrollDisabled 분리

```swift
// BAD: visibleDomain이 무효화됨
.chartScrollableAxes(selectionGestureState.allowsScroll ? .horizontal : [])

// GOOD: 인프라(scrollableAxes)와 UX(scrollDisabled) 분리
.chartScrollableAxes(.horizontal)
.scrollDisabled(!selectionGestureState.allowsScroll)
```

- `.chartScrollableAxes(.horizontal)`: 항상 활성화 → visibleDomain 유지
- `.scrollDisabled()`: 사용자 스크롤만 차단 → 선택 중 스크롤 방지

### 부가: .updating 시 scroll position 복원

선택 드래그 중 미세한 스크롤 드리프트를 방지하기 위해 `.updating` 콜백마다 초기 스크롤 위치를 복원:

```swift
case .updating:
    if let restore = selectionGestureState.initialScrollPosition,
       scrollPosition != restore {
        scrollPosition = restore
    }
    selectedDate = ChartSelectionInteraction.resolvedDate(...)
```

**성능 가드**: `scrollPosition != restore` 동등성 체크로 불필요한 `@Binding` 할당(60Hz) 방지.

## Affected Files

| 파일 | 변경 |
|------|------|
| AreaLineChartView.swift | scrollableAxes 분리 + updating 복원 |
| BarChartView.swift | 동일 |
| DotLineChartView.swift | 동일 (scrollPosition?.wrappedValue 변형) |
| RangeBarChartView.swift | 동일 |
| SleepStageChartView.swift | 동일 |

## Prevention

1. `.chartScrollableAxes`를 동적으로 토글하지 않는다
2. 스크롤 차단이 필요하면 `.scrollDisabled()`를 사용한다
3. gesture hot path(60Hz)에서 `@Binding` 할당 시 동등성 가드 필수
4. 차트 수정 후 반드시 롱프레스 + 과거 스크롤 테스트 수행
