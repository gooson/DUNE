---
tags: [chart, clipping, nocturnal-vitals, sleep, swift-charts]
date: 2026-03-29
category: plan
status: approved
---

# Fix: Nocturnal Vitals Chart Top Clipping

## Problem

야간 바이탈 차트(NocturnalVitalsChartView)의 상단 Y축 라벨("75")과 상단 데이터 포인트가 잘림.
원인: `.frame(height: 160).clipped()`가 Chart view 전체를 제한하여 Y축 상단 라벨이 프레임 밖으로 나가고 잘림.

## Related Solutions

- `docs/solutions/general/2026-03-22-chart-axis-label-clipping-and-overlap.md`: `.chartPlotStyle { $0.frame(height:) }` 패턴
- Project convention: `.padding(.top, 16)` + `.frame(height: N+16)` + `.clipped()` (VitalsTimelineCard, PersonalRecordsDetailView)

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Presentation/Sleep/Components/NocturnalVitalsChartView.swift` | `.padding(.top, 16)` 추가, frame 160 → 176 |

## Implementation Steps

### Step 1: Fix chart frame (line 69-70)

현재:
```swift
.frame(height: 160)
.clipped()
```

변경:
```swift
.padding(.top, 16)
.frame(height: 176)
.clipped()
```

프로젝트 기존 패턴(VitalsTimelineCard:21-23, PersonalRecordsDetailView:242-244) 동일.

## Test Strategy

- 빌드 성공 확인 (`scripts/build-ios.sh`)
- 시각적 확인: Y축 상단 라벨("75" 등)이 잘리지 않음

## Risks & Edge Cases

- 16pt 추가로 카드 전체 높이가 16pt 증가 → Sleep 탭 스크롤 레이아웃에 미미한 영향, 허용 범위
- AreaMark max 값이 상단 가장자리에 근접할 수 있으나, padding으로 breathing room 확보
