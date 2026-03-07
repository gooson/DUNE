---
tags: [charts, scroll, vitals, heart-rate, extendedRange, scrollDomain]
date: 2026-03-08
category: solution
status: implemented
---

# Chart Scroll: Vitals/HR 메트릭 통합

## Problem

6개 메트릭(SpO2, Respiratory Rate, VO2 Max, HR Recovery, Wrist Temperature, Heart Rate)의 디테일 차트가 과거 데이터로 스크롤되지 않았다. 원인: `loadVitalsData(_, days: N)` / `loadHeartRateData()`가 하드코딩된 일수 파라미터를 사용하여 `extendedRange` 기반 로딩을 우회했다.

## Root Cause

Swift Charts 스크롤에 필요한 3가지 조건:
1. **데이터**: visible window 너머 데이터 (`extendedRange`)
2. **X축 도메인**: 데이터를 포함하는 `.chartXScale(domain:)` (`scrollDomain`)
3. **스크롤 인프라**: `.chartScrollableAxes(.horizontal)` + `.chartXVisibleDomain`

AreaLineChartView 기반 메트릭(weight, BMI 등)은 3가지 모두 충족했으나, DotLineChartView/RangeBarChartView 기반 메트릭은 조건 1, 2가 누락되었다.

## Solution

### 3-Layer Fix

1. **Service Layer**: `start:end:` 범위 기반 쿼리 메서드 추가
   - `VitalsQuerying`: 5개 새 메서드
   - `HeartRateQuerying`: 1개 새 메서드
   - 기존 `days:` 메서드는 `start:end:`에 delegate

2. **ViewModel Layer**: `loadVitalsData` / `loadHeartRateData`를 `extendedRange` 사용으로 전환
   - `summaryStats`는 `currentPeriodValues()`로 현재 기간만 집계 (기존 패턴 유지)

3. **Chart View Layer**: `scrollDomain` + `effectiveXDomain` 추가
   - `DotLineChartView`: `scrollDomain: ClosedRange<Date>?` 프로퍼티 추가
   - `RangeBarChartView`: 동일 패턴 추가
   - `.chartXScale(domain: effectiveXDomain)` 적용

### DRY: `resolvedXDomain` 공유 함수

3개 차트 뷰의 동일한 `effectiveXDomain` 로직을 `ChartModels.swift`의 `resolvedXDomain()` 함수로 추출.

## Prevention

- 새 메트릭 추가 시 `MetricDetailViewModel`의 load 함수가 `extendedRange`를 사용하는지 확인
- 새 차트 뷰 타입 추가 시 `scrollDomain` 파라미터와 `resolvedXDomain()` 사용 확인
- Chart 스크롤 3가지 조건 체크리스트: (1) extendedRange 데이터, (2) scrollDomain/chartXScale, (3) chartScrollableAxes

## Affected Files

| 파일 | 변경 |
|------|------|
| `VitalsQueryService.swift` | 5개 `start:end:` 메서드 + guard 추가 |
| `HeartRateQueryService.swift` | `fetchHeartRateHistory(start:end:)` + guard 추가 |
| `DotLineChartView.swift` | `scrollDomain` 프로퍼티 추가 |
| `RangeBarChartView.swift` | `scrollDomain` 프로퍼티 추가 |
| `ChartModels.swift` | `resolvedXDomain()` 공유 함수 |
| `MetricDetailViewModel.swift` | `loadVitalsData`/`loadHeartRateData` extendedRange 전환 |
| `MetricDetailView.swift` | 6개 차트에 `scrollDomain` 전달 |
