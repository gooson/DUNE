---
tags: [swift-charts, scroll, extendedRange, scrollDomain, vitals, heart-rate, DotLineChartView, RangeBarChartView]
date: 2026-03-08
category: plan
status: draft
---

# Plan: 차트 스크롤 공통 로직 통일

## Summary

6개 메트릭(SpO2, Respiratory Rate, VO2 Max, HR Recovery, Wrist Temperature, Heart Rate)의 데이터 로딩을 `extendedRange` 기반으로 전환하고, DotLineChartView/RangeBarChartView에 `scrollDomain` 파라미터를 추가하여 모든 차트에서 과거 데이터 스크롤을 지원한다.

## Context

- Brainstorm: `docs/brainstorms/2026-03-08-chart-scroll-common-logic.md`
- Related solution: `docs/solutions/architecture/2026-03-08-chart-scroll-domain-sparse-data.md`

## Affected Files

| 파일 | 변경 유형 | 변경 내용 |
|------|----------|----------|
| `DUNE/Data/HealthKit/VitalsQueryService.swift` | 추가 | 프로토콜 + 구현체에 `start:end:` collection 메서드 5개 추가 |
| `DUNE/Data/HealthKit/HeartRateQueryService.swift` | 추가 | 프로토콜 + 구현체에 `fetchHeartRateHistory(start:end:)` 추가 |
| `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift` | 수정 | `loadVitalsData`/`loadHeartRateData`를 extendedRange 기반으로 전환 |
| `DUNE/Presentation/Shared/Charts/DotLineChartView.swift` | 추가 | `scrollDomain` 파라미터 + `effectiveXDomain` + `.chartXScale` |
| `DUNE/Presentation/Shared/Charts/RangeBarChartView.swift` | 추가 | `scrollDomain` 파라미터 + `effectiveXDomain` + `.chartXScale` |
| `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | 수정 | 6개 메트릭 차트에 `scrollDomain: viewModel.scrollDomain` 전달 |
| `DUNETests/` | 추가 | VitalsQueryService/HeartRateQueryService start:end 테스트 (필요시) |

## Implementation Steps

### Step 1: VitalsQuerying 프로토콜에 `start:end:` 메서드 추가

**파일**: `VitalsQueryService.swift`

프로토콜에 5개 collection 메서드 추가:
```swift
func fetchSpO2Collection(start: Date, end: Date) async throws -> [VitalSample]
func fetchRespiratoryRateCollection(start: Date, end: Date) async throws -> [VitalSample]
func fetchVO2MaxHistory(start: Date, end: Date) async throws -> [VitalSample]
func fetchHeartRateRecoveryHistory(start: Date, end: Date) async throws -> [VitalSample]
func fetchWristTemperatureCollection(start: Date, end: Date) async throws -> [VitalSample]
```

구현체에 private `fetchCollection(type:unit:start:end:validRange:)` 헬퍼 추가하고, 5개 메서드가 이를 호출.

기존 `days:` 메서드는 유지 (WellnessViewModel, AllDataViewModel에서 사용 중).

**Verification**: 컴파일 통과

### Step 2: HeartRateQuerying 프로토콜에 `start:end:` 메서드 추가

**파일**: `HeartRateQueryService.swift`

프로토콜에 추가:
```swift
func fetchHeartRateHistory(start: Date, end: Date) async throws -> [VitalSample]
```

구현: 기존 `fetchHeartRateHistory(days:)` 내부 로직에서 start/end 계산을 외부로 전달받도록 리팩터.

**Verification**: 컴파일 통과

### Step 3: DotLineChartView에 `scrollDomain` 파라미터 추가

**파일**: `DotLineChartView.swift`

AreaLineChartView 패턴과 동일하게:
```swift
var scrollDomain: ClosedRange<Date>?

private var effectiveXDomain: ClosedRange<Date> { ... }

// Chart modifier 추가
.chartXScale(domain: effectiveXDomain)
```

`scrollDomain`은 optional로, 기존 호출자(HRV, RHR 등)는 변경 불필요.

**Verification**: 기존 DotLineChartView 사용처 컴파일 통과 (default nil)

### Step 4: RangeBarChartView에 `scrollDomain` 파라미터 추가

**파일**: `RangeBarChartView.swift`

동일 패턴 적용.

**Verification**: 기존 RangeBarChartView 사용처 컴파일 통과 (default nil)

### Step 5: MetricDetailViewModel — loadVitalsData를 extendedRange 기반으로 전환

**파일**: `MetricDetailViewModel.swift`

`loadVitalsData(_, days:)` → `loadVitalsData(_ type: VitalType)`:
```swift
private func loadVitalsData(_ type: VitalType) async throws {
    let range = extendedRange
    let samples: [VitalSample]
    switch type {
    case .oxygenSaturation:  samples = try await vitalsService.fetchSpO2Collection(start: range.start, end: range.end)
    case .respiratoryRate:   samples = try await vitalsService.fetchRespiratoryRateCollection(start: range.start, end: range.end)
    case .vo2Max:            samples = try await vitalsService.fetchVO2MaxHistory(start: range.start, end: range.end)
    case .heartRateRecovery: samples = try await vitalsService.fetchHeartRateRecoveryHistory(start: range.start, end: range.end)
    case .wristTemperature:  samples = try await vitalsService.fetchWristTemperatureCollection(start: range.start, end: range.end)
    }
    chartData = samples.map { ChartDataPoint(date: $0.date, value: $0.value) }
    summaryStats = HealthDataAggregator.computeSummary(from: samples.map(\.value))
}
```

`loadData()` 호출부에서 `days:` 파라미터 제거:
```swift
case .spo2:              try await loadVitalsData(.oxygenSaturation)
case .respiratoryRate:   try await loadVitalsData(.respiratoryRate)
case .vo2Max:            try await loadVitalsData(.vo2Max)
case .heartRateRecovery: try await loadVitalsData(.heartRateRecovery)
case .wristTemperature:  try await loadVitalsData(.wristTemperature)
```

### Step 6: MetricDetailViewModel — loadHeartRateData를 extendedRange 기반으로 전환

**파일**: `MetricDetailViewModel.swift`

```swift
private func loadHeartRateData() async throws {
    let range = extendedRange
    let samples = try await heartRateService.fetchHeartRateHistory(start: range.start, end: range.end)
    chartData = samples.map { ChartDataPoint(date: $0.date, value: $0.value) }
    summaryStats = HealthDataAggregator.computeSummary(from: samples.map(\.value))
}
```

### Step 7: MetricDetailView — 6개 메트릭 차트에 scrollDomain 전달

**파일**: `MetricDetailView.swift`

6개 차트 인스턴스에 `scrollDomain: viewModel.scrollDomain` 추가:
- `.spo2` → DotLineChartView + scrollDomain
- `.respiratoryRate` → AreaLineChartView + scrollDomain (이미 AreaLineChartView가 지원)
- `.vo2Max` → DotLineChartView + scrollDomain
- `.heartRateRecovery` → DotLineChartView + scrollDomain
- `.heartRate` → RangeBarChartView + scrollDomain, DotLineChartView + scrollDomain
- `.wristTemperature` → AreaLineChartView + scrollDomain

### Step 8: 빌드 검증

`scripts/build-ios.sh`

## Test Strategy

- 신규 `start:end:` 메서드는 HealthKit 실쿼리이므로 유닛 테스트 면제 (시뮬레이터 제한)
- 기존 테스트가 영향받지 않는지 확인 (기존 `days:` 메서드 유지)
- MetricDetailViewModel의 `loadVitalsData` 시그니처 변경이 기존 테스트에 영향이 있으면 수정

## Risks & Edge Cases

| 리스크 | 대응 |
|--------|------|
| 기존 `days:` 호출자 깨짐 | `days:` 메서드 유지, `start:end:` 병렬 추가 |
| scrollDomain nil 시 기존 동작 변경 | scrollDomain은 optional + nil이면 data-derived fallback |
| Heart Rate의 RangeBarChartView 데이터 형식 | `rangeData`도 동일하게 extendedRange로 fetch해야 함 — loadHeartRateData에서 처리 |
| 테스트 mock에 새 메서드 누락 | 프로토콜 변경이므로 mock 구현체도 추가 필수 |
