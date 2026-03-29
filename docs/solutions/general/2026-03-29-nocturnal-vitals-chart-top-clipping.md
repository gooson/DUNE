---
tags: [chart, clipping, top-padding, swift-charts, nocturnal-vitals, sleep]
date: 2026-03-29
category: solution
status: implemented
---

# Nocturnal Vitals Chart Top Clipping

## Problem

야간 바이탈 차트(NocturnalVitalsChartView)에서 Y축 상단 라벨("75")과 상단 데이터 포인트가 `.frame(height: 160).clipped()`에 의해 잘림.

이는 2026-03-22 `chart-axis-label-clipping-and-overlap.md`에 문서화된 동일 class 문제의 반복 발생.

## Solution

프로젝트 기존 패턴(VitalsTimelineCard, PersonalRecordsDetailView)에 맞춰 `.padding(.top, 16)` + frame 16pt 증가:

```swift
// BEFORE: 상단 잘림
.frame(height: 160)
.clipped()

// AFTER: 16pt 여유 공간 확보
.padding(.top, 16)
.frame(height: 176)
.clipped()
```

## Prevention

Swift Charts에서 `.frame(height:).clipped()` 패턴을 사용할 때는 반드시:
1. `.padding(.top, 16)` 추가
2. frame height를 원래 의도한 plot 높이 + 16으로 설정
3. 또는 `.chartPlotStyle { $0.frame(height:) }` 사용 (2026-03-22 solution 참조)

## Lessons Learned

- 차트 짤림은 반복되는 패턴이므로 새 차트 추가 시 체크리스트에 포함해야 함
- `.clipped()` 없이는 Chart가 parent bounds를 넘어갈 수 있으므로 제거 불가 — padding이 올바른 해결책
