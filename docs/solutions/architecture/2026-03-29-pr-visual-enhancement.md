---
tags: [personal-records, sparkline, chip-bar, reward, badge, chart, gamification, ui-enhancement]
date: 2026-03-29
category: architecture
status: implemented
---

# PR (Personal Records) Visual Enhancement

## Problem

Activity tab PR section and detail view were functional but visually plain:
- Cards wasted vertical space (148pt) with context rows (HR/steps/weather)
- Segmented picker for 9 metric kinds was cramped
- Timeline chart was basic (flat lines, no gradient fill)
- Reward system showed minimal info (single summary row)
- Achievement history was a flat list with no visual hierarchy

## Solution

5-area visual overhaul:

### 1. PR Cards: Compact + Sparkline + Delta

- Reduced card height from 148pt to 120pt by removing context row
- Added `MiniSparklineView` (48x24pt) showing last N PR values
- Added delta badge (`+5.2 kg`) replacing context data
- Kind-specific 3pt accent edge on left + subtle tint background

### 2. Metric Chip Bar

- Replaced `Picker(.segmented)` with horizontal scroll chip bar
- `matchedGeometryEffect` for animated selection background
- Auto-scroll to selected chip via `ScrollViewReader`

### 3. Curved Timeline Chart

- `AreaMark` with gradient fill under the curve
- `.interpolationMethod(.catmullRom)` for smooth curves
- Latest point always annotated with value
- 10% Y-axis padding for breathing room
- 최고 페이스 차트는 [운동별 페이스 기록](2026-10-14-personal-record-pace-history-chart.md)을 사용한다. 현재 최고 카드는 전체 기간 PR이며, 차트는 선택 기간의 운동 페이스와 조회되지 않은 저장 PR을 표시한다. 페이스 곡선에는 실제 측정값보다 빠른 중간값을 만들지 않도록 선형 보간을 사용한다.

### 4. Reward Progress Section

- **Level Guide**: Progress bar, tier name, points to next level
- **Badge Trophy Case**: 16 badges across 5 categories, horizontal scroll
- **Fun Comparisons**: Dynamic real-world equivalents (volume→pianos, distance→marathons)

### 5. Achievement History

- Monthly grouping with section headers
- Visual hierarchy: levelUp (gradient bg) > badgeUnlocked (tint bg) > PR > milestone
- Points pill badge per event

## Key Design Decisions

1. **Domain model additions** (RewardLevelTier, WorkoutBadgeDefinition, FunComparison) placed in `PersonalRecord.swift` to keep reward models co-located
2. **Computed properties cached** after review: `funComparisons` and `groupedHistory` moved from computed to stored, refreshed via `refreshRewardDerived()`
3. **Badge definitions are static** with unlock status passed in — no persistent badge store needed yet
4. **previousValue** added to `ActivityPersonalRecord` for delta display — nil-safe, backward compatible

## Prevention

- **AnyShapeStyle for ternary**: Swift Color/ShapeStyle ternary expressions with `.tertiary`/`.quaternary` need `AnyShapeStyle` wrapping
- **Computed properties in body**: Reward-derived data (fun comparisons, grouped history) should be cached, not recomputed per render

## Lessons Learned

- Horizontal scroll chip bar is more flexible than segmented picker for 5+ options
- `AreaMark` + `LineMark` combination creates polished chart visuals with minimal code
- Badge definitions as static array works well for MVP — can be migrated to persistent store later
