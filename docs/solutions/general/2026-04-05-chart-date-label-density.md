---
tags: [chart, x-axis, date-label, density, stride, DotLineChartView]
date: 2026-04-05
category: solution
status: implemented
---

# Chart X축 날짜 레이블 밀도 동적 조절

## Problem

DotLineChartView에서 `timePeriod`가 nil인 경우(ExerciseHistoryView, PostureHistoryView), x축 레이블 stride가 고정값(`Period` enum 기반)이어서 데이터가 60일+ 범위를 커버할 때 레이블이 오밀조밀하게 겹침. 특히 한국어 locale에서 `.month(.abbreviated).day()` 포맷("2월 15일")이 길어 문제가 심화.

## Solution

`DotLineChartView` 내부에서 실제 데이터 날짜 범위(span)를 계산하여 stride와 format을 동적으로 결정.

### Span 기반 stride/format 분기

| 데이터 span | stride | format | 예상 레이블 수 |
|-------------|--------|--------|--------------|
| ≤ 14일 | 2일 | `.day().month(.abbreviated)` | ~7 |
| 15~60일 | 7일 | `.month(.narrow).day()` | ~4~8 |
| 61~180일 | 14일 | `.month(.narrow).day()` | ~4~12 |
| 181일+ | 1개월 | `.month(.abbreviated)` | ~6~12 |

### 주요 결정

1. **`@State cachedSpanDays` 캐싱**: `Calendar.dateComponents`가 body에서 3회 호출되는 문제 해결. `onAppear`/`onChange(of: data.count)`에서 1회만 계산.
2. **`min/max` 사용**: `data.first/last` 대신 `data.map(\.date).min()/max()` — 비정렬 데이터 방어.
3. **`Period` enum 제거**: 데이터 span 기반 로직이 `Period` enum을 완전 대체하므로 dead code 제거.
4. **`.month(.narrow).day()` 포맷**: 한국어 "2/1" (3글자) vs `.month(.abbreviated).day()` "2월 1일" (6글자). docs/solutions/general/2026-03-22-chart-axis-label-clipping-and-overlap.md에서 검증된 패턴.

## Prevention

- DotLineChartView에 새 axis 표시 모드를 추가할 때, `timePeriod == nil` 경로의 `cachedSpanDays` 기반 분기를 함께 검토
- 한국어/일본어 locale에서 date format 길이를 항상 확인 — `.abbreviated` (6글자) vs `.narrow` (3글자)
- Chart axis computed property에서 `Calendar` 연산은 반드시 `@State` 캐싱
