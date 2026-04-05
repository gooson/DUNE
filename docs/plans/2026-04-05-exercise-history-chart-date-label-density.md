---
tags: [chart, x-axis, date-label, density, DotLineChartView, ExerciseHistoryView]
date: 2026-04-05
category: plan
status: draft
---

# Exercise History Chart: X축 날짜 레이블 밀도 개선

## Problem Statement

ExerciseHistoryView의 "전체보기" 차트에서 x축 날짜 레이블이 오밀조밀하게 겹쳐 표시됨.

### 근본 원인

`DotLineChartView`가 `timePeriod` 없이 `Period` enum으로 호출될 때, stride 계산이 데이터 범위를 고려하지 않음:

- `.week` → stride 1일 (7개 레이블) ✓
- `.month` / `.quarter` → stride 7일 → 데이터가 60일+ 되면 ~9개+ 레이블
- 포맷 `.dateTime.day().month(.abbreviated)` → 한국어 "2월 15일" (6글자) → 공간 부족

### 영향 범위

- **ExerciseHistoryView**: 운동 기록이 많을수록(30일+) 레이블 겹침 심화
- **PostureHistoryView**: 동일 `period:` 파라미터 사용 → 동일 문제 가능

## Solution

`DotLineChartView` 내부에서 `timePeriod`가 nil일 때, 실제 데이터 날짜 범위(span)에 기반한 동적 stride + format 적용.

### 변경 전략

| 데이터 span | stride (일) | format | 예상 레이블 수 |
|-------------|------------|--------|--------------|
| ≤ 14일 | 2 | day().month(.abbreviated) | ~7개 |
| 15~60일 | 7 | month(.narrow).day() | ~4~8개 |
| 61~180일 | 14 | month(.narrow).day() | ~4~12개 |
| 181일+ | 30 (.month 단위) | month(.abbreviated) | ~6~12개 |

참고: docs/solutions/general/2026-03-22-chart-axis-label-clipping-and-overlap.md에서 `.month(.narrow).day()` → 한국어 "2/1" 확인 완료.

## Affected Files

| 파일 | 변경 | 설명 |
|------|------|------|
| `DUNE/Presentation/Shared/Charts/DotLineChartView.swift` | Modify | xStrideCount, xStrideComponent, axisFormat computed properties에 데이터 span 기반 분기 추가 |

## Implementation Steps

### Step 1: 데이터 span 계산 헬퍼 추가

`DotLineChartView`에 `private var dataSpanDays: Int` computed property 추가. `data` 배열의 첫/끝 날짜 차이를 일수로 계산.

### Step 2: xStrideCount, xStrideComponent, axisFormat 동적 분기

`timePeriod == nil` 분기에서 `dataSpanDays` 기반으로 stride와 format을 동적 결정. 기존 `period` 프로퍼티 참조를 대체.

### Step 3: ExerciseHistoryView.chartPeriod 참조 제거 검토

`DotLineChartView` 내부에서 span 기반으로 처리하므로, `ExerciseHistoryView`의 `chartPeriod` computed property가 불필요해질 수 있음. 다만 `chartPeriod`은 point mark 표시 여부 등에도 쓰일 수 있으므로 제거 여부는 구현 시 확인.

## Test Strategy

- **유닛 테스트**: 불필요 (순수 UI 변경, computed property는 view-internal)
- **시뮬레이터 확인**: 운동 세션 30개+의 운동에서 차트 확인
- **빌드 검증**: `scripts/build-ios.sh`

## Risks / Edge Cases

1. **데이터 포인트 1~2개**: `dataSpanDays` = 0 → stride 2일이면 1개 레이블만 → 정상 (singleDataPointView가 처리)
2. **PostureHistoryView**: 동일 코드 경로를 거치므로 자동으로 개선됨
3. **기존 callers**: `timePeriod`를 전달하는 MetricDetailView 등은 영향 없음 (timePeriod 분기가 우선)
