---
tags: [swiftui, lazyvgrid, swiftdata, scrollview, today, scroll-bounce, accessibility, pull-to-refresh]
category: performance
status: implemented
date: 2026-10-14
severity: important
related_files: [DUNE/Presentation/Dashboard/DashboardView.swift, DUNEUITests/Full/TodaySettingsRegressionTests.swift]
related_solutions: [docs/solutions/performance/2026-02-28-wellness-scrollview-infinite-bounce.md]
---

# Solution: Today 화면에서 수동 스크롤이 최상단에 도달하지 못하는 문제

## Problem

### Symptoms

- Today 화면을 위로 끌어올릴 때 콘텐츠가 덜컹거리며 멈추고, 큰 내비게이션 제목과 Condition 카드가 처음 위치로 돌아오지 않았다.
- 수정 전 `testManualScrollToTopSettlesWithoutMovingConditionHero`는 12번의 제한된 드래그 뒤에도 히어로 카드가 처음 Y 위치로 복귀하지 않아 실패했다. 실패 화면에서 제목은 접힌 상태였고 Condition 카드도 시작 위치보다 위에 있었다.

### Root Cause

`DashboardView`에는 SwiftData `@Query` 두 개와 `LazyVGrid` 메트릭 카드 섹션이 함께 있었다. 이는 [Wellness 화면의 스크롤 피드백 루프](2026-02-28-wellness-scrollview-infinite-bounce.md)에서 확인한 레이아웃 조합과 같다. 이번에는 레이아웃 추적 로그로 개별 invalidation을 직접 확인하지 못했으므로, 정확한 내부 루프는 추정이다. 다만 동일한 데이터와 UI 테스트 조건에서 지연 그리드를 고정된 행 레이아웃으로 교체하자 최상단 복귀가 통과했다.

교체 과정에서 별도 접근성 회귀가 드러났다. 상위 섹션의 `.accessibilityIdentifier`가 자식 메트릭 버튼에 전파되어 Sleep 버튼의 식별자가 `dashboard-metric-sleep` 대신 `dashboard-section-body`로 노출됐다. 고정 카드도 `dashboard-pinned-grid` 식별자를 받았다. 접근성 로그로 실제 버튼 레이블과 잘못된 식별자를 확인했다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/DashboardView.swift` | `LazyVGrid`를 `VStack`의 2열 `HStack` 행으로 교체 | 카드 실현에 따른 스크롤 중 레이아웃 변동을 피함 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | 섹션과 고정 카드 그리드에 `.accessibilityElement(children: .contain)` 추가 | 상위 그룹 식별자와 개별 버튼 식별자를 함께 보존 |
| `DUNEUITests/Full/TodaySettingsRegressionTests.swift` | 수동 최상단 복귀·반복된 짧은 당김·카드 탭을 확인하는 테스트 추가 | 영상의 실패 경로를 재현하고 회귀를 막음 |

### Key Code

```swift
let rows = stride(from: 0, to: cards.count, by: 2).map { index in
    (left: cards[index], right: index + 1 < cards.count ? cards[index + 1] : nil, index: index)
}

return VStack(spacing: DS.Spacing.md) {
    ForEach(rows, id: \.left.id) { row in
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            metricCard(row.left, index: row.index)
            if let right = row.right {
                metricCard(right, index: row.index + 1)
            } else {
                Color.clear.frame(maxWidth: .infinity).accessibilityHidden(true)
            }
        }
    }
}
```

섹션 식별자가 필요한 컨테이너에는 자식 포함 동작을 식별자보다 먼저 적용한다:

```swift
SectionGroup(...) { cardGrid(cards: cards) }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(accessibilityIdentifier)
```

`.scrollBounceBehavior(.basedOnSize)`는 최종 코드에 두지 않았다. 긴 Today 화면의 상단 문제를 해결하는 데 필요하지 않았고, 짧은 빈 화면에서는 당겨서 새로고침에 필요한 바운스를 막을 수 있다.

### Verification

- 수정 전: 새 수동 스크롤 UI 테스트 실패.
- 수정 후: 수동 스크롤 테스트와 기존 Sleep 카드 상세 화면 테스트 2/2 통과.
- 바운스 설정 제거 후: iOS 빌드와 수동 스크롤 테스트 1/1 통과.
- 기존 Weather 상세 화면 테스트는 `main`에서도 동일하게 실패해 이 변경의 회귀로 분류하지 않았다.

## Prevention

### Checklist Addition

- [ ] `@Query`가 있는 긴 `ScrollView`에 `LazyVGrid`를 추가할 때 실제 최상단·최하단 수동 복귀를 확인한다.
- [ ] 그리드 구현을 바꿀 때 상위 섹션과 카드 버튼의 접근성 식별자를 각각 검사한다.
- [ ] 바운스 정책을 바꿀 때 데이터가 없는 짧은 화면의 당겨서 새로고침도 확인한다.
- [ ] 운동 종류가 많은 데이터에서 eager 카드 레이아웃의 초기 렌더링 시간을 측정한 뒤 최적화 여부를 결정한다. 운동 종류별 카드는 현재 고정 개수 제한이 없다.

### Rule Addition

이번 사례는 별도 공통 규칙을 추가하지 않는다. 위 체크리스트와 기존 Wellness 해결책으로 재발 조건을 찾을 수 있다.

## Lessons Learned

1. 스크롤 결함은 사용자 영상과 좌표 기반 UI 테스트를 함께 써서 수정 전 실패와 수정 후 복귀를 확인할 수 있다.
2. 레이아웃 컨테이너를 교체하면 버튼 동작이 그대로여도 접근성 계층과 식별자 전파가 달라질 수 있다.
3. 화면이 긴 경우의 바운스 개선책을 짧은 새로고침 화면에 그대로 적용하면 다른 상호작용을 해칠 수 있다.
4. 이번 수정은 운동 종류가 매우 많은 사용자의 초기 렌더링 비용을 직접 측정하지 않았다. 카드 표시 수를 임의로 제한하면 데이터 노출이 바뀌므로 성능 측정 후 별도로 판단한다.
