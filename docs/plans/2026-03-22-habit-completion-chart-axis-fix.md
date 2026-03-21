---
tags: [chart, axis, clipping, life-tab]
date: 2026-03-22
category: plan
status: implemented
---

# 달성률 차트 축 표시 수정

## Problem

1. **X축 날짜 표시 겹침/잘림**: weekly chart에서 `.dateTime.month(.abbreviated).day()` 포맷이 한국어로 "2월 1일", "3월 15일" 등 긴 텍스트를 생성. 매주 stride로 8+개 라벨이 나와 겹치고 마지막 라벨이 "3월 2..."처럼 잘림
2. **Y축 100% 잘림**: chart container height(180) + `.clipped()`로 상단 Y축 "100%" 라벨이 잘림

## Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Presentation/Life/HabitCompletionChartView.swift` | X축 포맷, Y축 여백 |

## Solution

### X축 (weekly)

- `AxisMarks(values: .stride(by: .weekOfYear))` → `AxisMarks(values: .automatic(desiredCount: 5))`로 변경하여 Swift Charts가 적절한 수의 라벨을 자동 선택
- 포맷: `.dateTime.month(.abbreviated).day()` → `.dateTime.month(.narrow).day()` (짧은 월 약어: "2/1", "3/8" 등)

### X축 (monthly)

- 현재 `.stride(by: .month)` → 데이터가 많아지면 같은 문제 발생 가능
- `AxisMarks(values: .automatic(desiredCount: 6))`으로 변경

### Y축 100% 잘림

- `.chartPlotStyle` inset 또는 container 높이 증가 대신, `.clipped()` 제거
- swiftui-patterns.md 규칙: "Swift Charts → `.clipped()` 필수" — 하지만 이는 bar/area가 plot 영역을 넘어서는 경우. Y축 라벨은 plot 바깥이므로 `.clipped()`가 라벨을 잘라냄
- 해결: `.clipped()` 유지하되, Y축 상한 여백을 위해 container padding 조정 — `.padding(.top, 4)` 추가

실제로는 Swift Charts의 Y축 라벨은 plot area 바깥에 그려지는데 `.clipped()`가 전체 Chart view의 bounds를 자르고 있음. 정확한 원인: chart height 180이 너무 작아서 Y축 라벨 공간이 부족. `.frame(height: 200)`으로 증가하거나 `.chartPlotStyle { $0.frame(height: 160) }` + 외부 frame 제거.

**최종 결정**:
1. 외부 `.frame(height: 180)` 제거
2. `.chartPlotStyle { plotContent in plotContent.frame(height: 160) }` 추가 → Y축 라벨 공간 확보
3. X축 포맷 간소화

## Implementation Steps

1. weeklyChart X축: `AxisMarks(values: .automatic(desiredCount: 5))` + 간결한 포맷
2. monthlyChart X축: `AxisMarks(values: .automatic(desiredCount: 6))` 유지
3. chartContent에 `.chartPlotStyle` 추가하여 plot 영역과 전체 프레임 분리
4. 빌드 확인

## Test Strategy

- 시각적 확인 (차트 라벨 잘림/겹침 해소)
- 빌드 통과

## Risks

- `.automatic(desiredCount:)`가 데이터가 적을 때 어색한 간격으로 표시될 수 있음 → 데이터 2주 미만이면 라벨이 자연스러운지 확인 필요
- `.chartPlotStyle` frame이 기존 레이아웃과 충돌 가능 → 전체 카드 높이 확인
