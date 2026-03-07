---
tags: [swift-charts, scroll, sparse-data, body-composition, AreaLineChartView]
date: 2026-03-08
category: solution
status: implemented
---

# Swift Charts 스크롤이 Sparse 데이터에서 작동하지 않는 문제

## Problem

Swift Charts의 `.chartScrollableAxes(.horizontal)` + `.chartXVisibleDomain(length:)`를 사용할 때, 데이터 포인트가 희소(sparse)하면 과거로 스크롤할 수 없다.

### 근본 원인

`.chartXScale(domain:)`을 명시하지 않으면 Swift Charts가 **실제 데이터 포인트**에서 자동으로 x축 범위를 계산한다. 체중/BMI/체지방 등 body composition 데이터는 매일 기록되지 않으므로, 자동 계산된 범위가 visible window보다 작거나 같아서 스크롤 여유가 없다.

### 대조

BarChartView는 `fillDateGaps()`로 빈 날짜에 0값 포인트를 삽입하므로 이 문제가 없었다. AreaLineChartView는 gap filling 없이 실제 데이터만 표시하므로 영향을 받았다.

## Solution

### 1. `.chartXScale(domain:)` 명시

AreaLineChartView에 `scrollDomain: ClosedRange<Date>?` 파라미터를 추가하고, `.chartXScale(domain: effectiveXDomain)`로 전체 스크롤 가능 범위를 명시적으로 설정.

```swift
// AreaLineChartView.swift
var scrollDomain: ClosedRange<Date>?

private var effectiveXDomain: ClosedRange<Date> {
    if let scrollDomain { return scrollDomain }
    // Fallback: data-derived range (preview/test용)
    guard let first = data.min(by: { $0.date < $1.date })?.date,
          let last = data.max(by: { $0.date < $1.date })?.date,
          first < last else {
        let now = Date()
        return now...now.addingTimeInterval(1)
    }
    return first...last
}
```

### 2. ViewModel에서 `extendedRange` 활용

`MetricDetailViewModel.scrollDomain`이 `extendedRange` (현재 기간 + scrollBufferPeriods)를 `ClosedRange<Date>`로 변환하여 차트에 전달.

### 3. Range 기반 fetch로 통일

`loadBodyFatData()`/`loadLeanBodyMassData()`가 고정 `days: 90` 대신 `extendedRange`를 사용하도록 변경. `BodyCompositionQuerying` 프로토콜에 `fetchBodyFat(start:end:)`, `fetchLeanBodyMass(start:end:)` 추가.

### 4. DRY 헬퍼 추출

4개의 body composition 로딩 함수(weight, BMI, bodyFat, leanBodyMass)가 동일한 fetch-aggregate-summarize 패턴을 공유하므로 `loadBodyCompositionData(fetch:)` 헬퍼로 추출.

## Prevention

- AreaLineChartView 사용 시 항상 `scrollDomain`을 전달할 것
- 새 body composition 메트릭 추가 시 `loadBodyCompositionData(fetch:)` 헬퍼 재사용
- Range 기반 fetch 메서드에는 반드시 `validRange` 파라미터 전달 (input-validation.md 참조)
- `async let` 병렬 fetch에서 summary 계산 시 `self.chartData` 대신 로컬 변수 사용 (race condition 방지)

## Affected Files

| 파일 | 변경 |
|------|------|
| `BodyCompositionQueryService.swift` | 프로토콜 + 구현체에 start:end 메서드 추가, validRange 적용 |
| `MetricDetailViewModel.swift` | scrollDomain 추가, DRY 헬퍼 추출, bodyFat/leanBodyMass range 기반 fetch |
| `AreaLineChartView.swift` | scrollDomain 파라미터 + effectiveXDomain 추가 |
| `MetricDetailView.swift` | scrollDomain 전달 |
