---
tags: [chart, volume, metric, daily-breakdown, weekly-stats]
date: 2026-03-29
category: general
status: implemented
---

# Daily Breakdown 차트에 새 메트릭 추가 패턴

## Problem

`DailyVolumeChartView`의 세그먼트 피커(Duration/Sessions)에 Volume(kg) 메트릭을 추가해야 했다. `DailyVolumePoint` 모델에 데이터가 없었으므로 Domain → Service → View 전 레이어를 수정해야 했다.

## Solution

### 3-Layer 확장 패턴

1. **Domain 모델**: `DailyVolumePoint`에 stored property `totalVolume: Double = 0` 추가 + explicit init으로 기존 호출 호환
2. **Service**: `buildDailyBreakdown`에서 `manualRecords` loop 내 volume 집계 (`dailyVolume: [Date: Double]` 딕셔너리)
3. **View**: `Metric` enum에 `.volume` case + `valueFor` / `formattedValue` switch 확장

### 핵심 결정

- **기본값 0으로 기존 init 호환**: `StackedVolumeBarChartView`, `PeriodComparisonTests` 등 기존 호출 무수정
- **`isFinite` guard**: `record.totalVolume.isFinite` 체크로 NaN/Inf 방어
- **Metric enum의 `displayNames` static Dictionary 패턴**: `String(localized:)` 호이스트로 body 재생성 방지

## Prevention

- 차트에 새 메트릭 추가 시 이 3-Layer 패턴을 따르면 최소 변경으로 확장 가능
- `DailyVolumePoint`에 필드 추가 시 반드시 기본값을 제공하여 기존 호출 사이트 호환성 유지
- `displayNames` 딕셔너리에 새 키 추가 시 `Localizable.xcstrings`에 en/ko/ja 동시 등록

## Lessons Learned

- `formattedWithSeparator`는 `Int`(computed property)와 `Double`(method with default params)에서 호출 구문이 다르지만 정상 동작
- 기존 테스트의 `summaryStats.count` 기대값이 실제 값과 불일치했던 pre-existing bug 발견 및 수정 (4 → 5)
