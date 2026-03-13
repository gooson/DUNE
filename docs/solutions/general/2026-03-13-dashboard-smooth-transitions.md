---
tags: [dashboard, animation, swiftui, transitions, optimistic-update, ux]
date: 2026-03-13
category: solution
status: implemented
---

# Solution: 투데이탭 부드러운 전환 UX

## Problem

DashboardView에서 리로드/섹션 토글 시 레이아웃이 "덜컹덜컹" 점프하는 문제.

원인:
1. `loadData()`가 모든 상태를 nil로 리셋 → 섹션이 사라졌다 다시 나타남
2. 섹션 표시/숨김에 transition 없음 → `if !cards.isEmpty` 토글이 즉시 반영
3. Weather 카드 placeholder → 실제 카드 전환 시 높이 변화
4. `sortedMetrics` 변경 시 카드 그리드 한꺼번에 재배치

## Solution

### 1. Optimistic Update (DashboardViewModel)

`hasLoadedOnce` 플래그로 첫 로딩과 리로드를 분리:

```swift
private var hasLoadedOnce = false

func loadData(...) async {
    // 첫 로딩에서만 nil 리셋 (skeleton 표시)
    if !hasLoadedOnce {
        conditionScore = nil
        sortedMetrics = []
        // ...
    }

    // fetch...

    // 결과 적용 (리로드 시 기존 값이 유지되어 있으므로 diff만 반영)
    sortedMetrics = allMetrics.sorted { ... }
    hasLoadedOnce = true
}
```

**`isFirstLoad`가 아닌 `hasLoadedOnce`를 사용하는 이유**: `sortedMetrics.isEmpty && conditionScore == nil` 조건은 모든 fetch가 실패했을 때도 true가 되어, 재시도 시 다시 skeleton을 보여주는 문제가 있음. `hasLoadedOnce`는 한 번이라도 fetch를 완료하면 영구적으로 true.

### 2. Section Transitions (DashboardView)

모든 조건부 섹션에 `.transition()` 적용:

```swift
// 일반 섹션: opacity + scale
private static let sectionTransition: AnyTransition =
    .opacity.combined(with: .scale(scale: 0.95, anchor: .top))

// 에러 배너: opacity + slide from top
private static let errorBannerTransition: AnyTransition =
    .opacity.combined(with: .move(edge: .top))
```

**`static let`으로 선언하는 이유**: computed property는 호출마다 새 `AnyTransition` 인스턴스를 생성. static let은 한 번만 생성.

### 3. Animation Value 범위 확장

단일 `sortedMetrics.count` 대신 모든 섹션 가시성 요인을 포함하는 해시 사용:

```swift
private var sectionVisibilityHash: Int {
    var h = Hasher()
    h.combine(viewModel.sortedMetrics.count)
    h.combine(viewModel.conditionScore != nil)
    h.combine(viewModel.weatherSnapshot != nil)
    h.combine(viewModel.errorMessage != nil)
    h.combine(viewModel.insightCards.count)
    h.combine(viewModel.pinnedCards.count)
    return h.finalize()
}

// VStack에 적용
.animation(reduceMotion ? .none : DS.Animation.standard, value: sectionVisibilityHash)
```

### 4. Weather Card Group

placeholder와 실제 카드를 `Group`으로 감싸서 단일 transition 적용:

```swift
Group {
    if let weather = viewModel.weatherSnapshot {
        WeatherCard(snapshot: weather, ...)
    } else {
        WeatherCardPlaceholder { ... }
    }
}
.transition(Self.sectionTransition)
```

## Key Decisions

| 결정 | 이유 |
|------|------|
| ViewModel에 SwiftUI import 안 함 | 프로젝트 layer boundary 준수 |
| `withAnimation` 대신 `.animation(value:)` | ViewModel이 SwiftUI를 모르는 구조에서 View-side implicit animation이 적합 |
| `hasLoadedOnce` 플래그 | `isFirstLoad` 조건보다 edge case에 안전 |
| `Hasher` 기반 composite value | O(1) 비교, 독립적 섹션 변경도 감지 |

## Prevention

- Dashboard/탭 루트에서 리로드 패턴 구현 시, 기존 데이터를 nil 리셋하지 않는 optimistic update 패턴 우선 적용
- 조건부 섹션에는 항상 `.transition()` 고려
- `.animation(value:)` 적용 시 단일 프로퍼티가 아닌 모든 가시성 요인을 포함하는 composite value 사용
