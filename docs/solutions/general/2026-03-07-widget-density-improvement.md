---
tags: [widget, layout, density, WidgetKit, spacing]
date: 2026-03-07
category: general
status: implemented
---

# Widget Layout Density Improvement

## Problem

WidgetKit 위젯(Small/Medium/Large)의 padding과 spacing이 넓어 콘텐츠 영역이 제한적이었다. Medium 위젯의 ring이 작아 점수 가독성이 떨어지고, Small 위젯에 업데이트 시각 정보가 없어 데이터 신선도를 알 수 없었다.

## Solution

### 1. WidgetDS.Layout 토큰 조정

```swift
// Before
edgePadding: 14, columnSpacing: 8, rowSpacing: 8

// After
edgePadding: 12, columnSpacing: 6, rowSpacing: 6
```

### 2. WidgetMetricTileView (Medium) 내부 최적화

- Ring size: 52 → 56 (점수 텍스트 가독성 향상)
- VStack spacing: 8 → 6
- Padding: top 10→6, bottom 14→10, horizontal 6→4

### 3. SmallWidgetView timestamp 추가

LargeWidgetView의 footer 패턴을 차용하여 `scoreUpdatedAt` timestamp를 표시. nil이면 "Today" fallback.

## Affected Files

- `DUNEWidget/DesignSystem.swift` — Layout 토큰
- `DUNEWidget/Views/WidgetScoreComponents.swift` — WidgetMetricTileView
- `DUNEWidget/Views/SmallWidgetView.swift` — footer timestamp

## Prevention

- 위젯 spacing 변경 시 `WidgetDS.Layout` 토큰을 사용하여 일관성 유지
- 위젯 간 footer 패턴(timestamp + status)은 LargeWidgetView를 기준 패턴으로 참조

## Lessons Learned

- WidgetKit 위젯은 제한된 영역에서 정보 밀도가 중요하며, 2pt 단위의 padding 변경만으로도 체감 차이가 크다
- Small 위젯에서 timestamp를 보여주면 사용자가 "이 데이터가 최신인가?"를 빠르게 판단할 수 있다
