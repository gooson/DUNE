---
tags: [swift-charts, scroll, extendedRange, scrollDomain, DotLineChartView, vitals, heart-rate]
date: 2026-03-08
category: brainstorm
status: draft
---

# Brainstorm: 차트 과거 데이터 스크롤 공통 로직 통일

## Problem Statement

15개 메트릭 중 6개(SpO2, Respiratory Rate, VO2 Max, HR Recovery, Wrist Temperature, Heart Rate)가 과거 데이터로 스크롤할 수 없다. 이들은 `loadVitalsData(_, days: N)` / `loadHeartRateData()`에서 고정된 일수로 데이터를 fetch하여 `selectedPeriod`와 `extendedRange`를 무시한다.

나머지 9개(HRV, RHR, Sleep, Steps, Exercise, Weight, BMI, BodyFat, LeanBodyMass)는 `extendedRange` 기반으로 데이터를 로드하여 스크롤이 정상 동작한다.

## Root Cause Analysis

### 스크롤 동작 조건 (3가지 모두 필요)

1. **데이터가 visible window 밖까지 존재** — `extendedRange`로 과거 데이터 fetch
2. **X축 domain이 데이터를 포함** — 암시적(data-derived) 또는 명시적(`chartXScale`)
3. **scroll infra 활성화** — `.chartScrollableAxes(.horizontal)` + `.chartXVisibleDomain`

### 메트릭별 현황

| 메트릭 | 조건 1 (data) | 조건 2 (domain) | 조건 3 (infra) | 결과 |
|--------|:---:|:---:|:---:|:---:|
| HRV, RHR, Sleep, Steps, Exercise | O (extendedRange) | O (implicit) | O | **스크롤 OK** |
| Weight, BMI, BodyFat, LeanBodyMass | O (extendedRange) | O (explicit scrollDomain) | O | **스크롤 OK** |
| SpO2, RespRate, VO2Max, HRR | X (고정 days) | X (implicit but narrow) | O | **스크롤 불가** |
| Wrist Temperature | X (고정 days) | X (scrollDomain 미전달) | O | **스크롤 불가** |
| Heart Rate | X (고정 days) | X (implicit but narrow) | O | **스크롤 불가** |

### 왜 두 경로가 존재하는가

- HRV/RHR/Sleep/Steps/Exercise: 초기 구현 시 `extendedRange` 기반으로 설계됨
- Weight/BMI/BodyFat/LeanBodyMass: objective-pare에서 `extendedRange` + `scrollDomain` 추가
- Vitals/HR: 나중에 추가되면서 `days:` 파라미터 패턴을 사용. `selectedPeriod` 기반 로딩이 적용되지 않음

## Success Criteria

1. 모든 15개 메트릭에서 과거 데이터로 수평 스크롤 가능
2. Period 전환(D/W/M/6M/Y) 시 적절한 데이터 범위 로드
3. 스크롤 후 visible range 통계(summary) 재계산

## Proposed Approach

### 1. Vitals 데이터 로딩을 `extendedRange` 기반으로 전환

`loadVitalsData(_, days:)` → `loadVitalsData(_, start:end:)` 로 변경.
`extendedRange`에서 start/end를 계산하여 전달.

```swift
// BEFORE
try await loadVitalsData(.oxygenSaturation, days: 30)

// AFTER
let range = extendedRange
try await loadVitalsData(.oxygenSaturation, start: range.start, end: range.end)
```

### 2. Heart Rate 로딩도 `extendedRange` 기반으로 전환

`loadHeartRateData()` 내부의 `fetchHeartRateHistory(days: 30)` → `fetchHeartRateHistory(start:end:)`.

### 3. DotLineChartView에 `scrollDomain` 파라미터 추가

AreaLineChartView와 동일 패턴:

```swift
var scrollDomain: ClosedRange<Date>?

private var effectiveXDomain: ClosedRange<Date> {
    if let scrollDomain { return scrollDomain }
    // fallback: data-derived range
}

.chartXScale(domain: effectiveXDomain)
```

### 4. Wrist Temperature에 `scrollDomain` 전달

MetricDetailView에서 wristTemperature case에 `scrollDomain: viewModel.scrollDomain` 추가.

### 5. RangeBarChartView에도 `scrollDomain` 추가 (Heart Rate용)

Heart Rate의 primary chart는 RangeBarChartView. 이것도 동일 패턴 적용.

## Constraints

- `VitalsQueryService` 프로토콜에 `start:end:` 메서드 추가 필요 (또는 기존 메서드 시그니처 변경)
- `HeartRateQueryService`에도 동일 변경 필요
- 기존 `days:` 메서드는 다른 곳에서 사용 중일 수 있으므로 영향 범위 확인 필요
- validRange 가드 일관 적용 (input-validation.md)

## Edge Cases

- **데이터 없음**: extendedRange 전체에 데이터 0건 → 빈 차트 + 스크롤은 가능해야 함 (scrollDomain이 범위 보장)
- **극소 데이터**: 6개월간 2-3건 → scrollDomain으로 명시적 범위 설정
- **Period 전환 중 데이터 로딩**: 이미 cancel-before-spawn 패턴 적용됨

## Scope

### MVP (Must-have)
- [ ] 6개 메트릭 모두 extendedRange 기반 fetch로 전환
- [ ] DotLineChartView에 scrollDomain 파라미터 추가
- [ ] RangeBarChartView에 scrollDomain 파라미터 추가 (Heart Rate용)
- [ ] MetricDetailView에서 모든 차트에 scrollDomain 전달
- [ ] Wrist Temperature scrollDomain 전달

### Nice-to-have (Future)
- [ ] 차트 스크롤 공통 ViewModifier 추출
- [ ] scrollDomain 기본값을 chart view 내부에서 ViewModel 없이 계산

## Affected Services/Files (예상)

| 파일 | 변경 |
|------|------|
| `MetricDetailViewModel.swift` | loadVitalsData/loadHeartRateData를 extendedRange 기반으로 변경 |
| `MetricDetailView.swift` | 모든 차트에 scrollDomain 전달 |
| `DotLineChartView.swift` | scrollDomain 파라미터 + effectiveXDomain + chartXScale 추가 |
| `RangeBarChartView.swift` | scrollDomain 파라미터 + effectiveXDomain + chartXScale 추가 |
| `VitalsQueryService.swift` | start:end: 메서드 추가 (또는 기존 시그니처 변경) |
| `HeartRateQueryService.swift` | start:end: 메서드 추가 |

## Open Questions

1. `days:` 기반 fetch 메서드를 삭제할 것인가, deprecate할 것인가?
2. BarChartView에도 scrollDomain을 추가해야 하는가? (현재 fillDateGaps로 충분히 작동)

## Next Steps

- [ ] `/plan chart-scroll-common-logic` 으로 구현 계획 생성
