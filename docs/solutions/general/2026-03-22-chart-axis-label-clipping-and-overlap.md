---
tags: [chart, axis, clipping, label-overlap, swift-charts, life-tab]
date: 2026-03-22
category: solution
status: implemented
---

# Chart Axis Label Clipping & Date Overlap

## Problem

달성률(HabitCompletionChartView) 차트에서 두 가지 문제 발생:
1. **X축 날짜 겹침/잘림**: `.stride(by: .weekOfYear)`가 8개 주에 8개 라벨을 배치 → 한국어 `.month(.abbreviated).day()` 포맷("2월 1일", "3월 15일")이 길어서 겹치고 마지막 라벨 잘림
2. **Y축 100% 잘림**: `.frame(height: 180)` + `.clipped()`가 Chart view 전체를 제한 → Y축 라벨이 plot 영역 바깥에 그려지는데 프레임에 의해 잘림

## Solution

### Y축 잘림: `.chartPlotStyle`로 plot 영역만 제한

```swift
// BEFORE: 전체 Chart view를 180pt로 제한 → Y축 라벨 잘림
chartContent
    .frame(height: 180)
    .clipped()

// AFTER: plot 영역만 160pt로 제한 → Y축 라벨은 자유롭게 렌더
chartContent
    .chartPlotStyle { plotContent in
        plotContent.frame(height: 160)
    }
    .clipped()
```

**핵심 원리**: `.frame(height:)`는 Chart view 전체(plot + axis labels)를 제한하지만, `.chartPlotStyle`의 `frame(height:)`는 plot 영역(bar가 그려지는 사각형)만 제한. 축 라벨은 plot 바깥에 자연스럽게 배치됨.

### X축 겹침: stride count 증가 + narrow month 포맷

```swift
// BEFORE: 매주 라벨 → 8개 → 겹침
AxisMarks(values: .stride(by: .weekOfYear)) { _ in
    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
}

// AFTER: 격주 라벨 → 4개 + 짧은 포맷
AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
    AxisValueLabel(format: .dateTime.month(.narrow).day())
}
```

**왜 `.automatic(desiredCount:)`가 아닌 `.stride(count: 2)`인가**: `.automatic`은 "nice" 캘린더 경계를 선택하므로 bar 중심과 어긋날 수 있음. `.stride(count: 2)`는 매 2주마다 정확히 bar 위에 라벨을 배치.

## Prevention

- Swift Charts에서 `.frame(height:)`로 전체 높이를 제한하면 축 라벨이 잘릴 수 있음 → `.chartPlotStyle { $0.frame(height:) }`로 plot 영역만 제한
- 날짜 기반 BarMark에서 X축 라벨 수를 줄일 때: `.automatic(desiredCount:)` 대신 `.stride(count: N)` 사용하여 bar-label 정렬 보장
- 한국어/일본어 locale에서 `.month(.abbreviated).day()` → "2월 1일" (6글자) — `.month(.narrow).day()` 사용 시 "2/1" (3글자)로 단축
