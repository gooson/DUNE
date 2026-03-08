---
tags: [ios, swiftui, charts, activity, ui-test, scroll, accessibility-id]
category: testing
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift
  - DUNE/Presentation/Activity/WeeklyStats/WeeklyStatsDetailViewModel.swift
  - DUNE/Presentation/Activity/Components/TrainingLoadChartView.swift
  - DUNE/Presentation/Activity/WeeklyStats/Components/DailyVolumeChartView.swift
  - DUNE/Presentation/Shared/Charts/ChartSelectionOverlay.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
  - DUNEUITests/Regression/ChartInteractionRegressionUITests.swift
related_solutions:
  - docs/solutions/testing/2026-03-03-ipad-activity-tab-ui-test-navigation-stability.md
  - docs/solutions/testing/2026-03-04-ui-test-max-hardening-and-axid-stability.md
---

# Solution: Activity Chart Scroll History and Hittable UI Regression Coverage

## Problem

트레이닝 부하 차트와 주간 통계 일일 볼륨 차트가 현재 기간만 보여서 이전 데이터를 탐색할 수 없었고, 트레이닝 차트 회귀 테스트는 실제 기능과 무관하게 오프스크린 요소에 제스처를 보내며 실패했다.

### Symptoms

- Training Volume 상세의 training load chart가 이전 기간 데이터로 스크롤되지 않음
- Weekly Stats 상세의 daily volume chart가 현재 기간만 보여 과거 비교가 어려움
- UI 테스트에서 training load chart quick drag/long press가 상태를 바꾸지 못하고 visible range가 고정됨

### Root Cause

- 두 차트 모두 현재 선택 기간 길이만 기준으로 데이터를 만들거나 표시해, 차트 스크롤에 필요한 이전 기간 history가 부족했다
- Weekly Stats와 Training Volume은 HealthKit fetch 실패 시 fallback 처리 수준이 달라, manual record만 있는 환경에서 chart history가 충분히 채워지지 않을 수 있었다
- Training Volume 차트는 상세 화면 아래쪽에 위치해 `exists`만 확인한 UI 테스트에서는 element가 화면에 보여도 실제 hit target 상태가 아니었다

## Solution

차트 데이터는 현재 기간 + 이전 기간까지 확장하고, 차트 뷰는 공통 scroll domain 계산을 사용해 이전 데이터로 이동 가능하게 만들었다. 동시에 차트 접근성 surface와 UI helper를 정리해, regression test가 오프스크린 차트를 먼저 hittable 상태로 만든 뒤 제스처를 수행하도록 보강했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift` | training load history를 current + previous period로 확장하고 manual snapshot fallback 추가 | HealthKit 비가용 환경에서도 스크롤 가능한 history 확보 |
| `DUNE/Presentation/Activity/WeeklyStats/WeeklyStatsDetailViewModel.swift` | daily breakdown chart history를 선택 기간 기준으로 재구성하고 manual snapshot fallback 강화 | Weekly Stats 차트도 이전 기간 스크롤 가능하게 유지 |
| `DUNE/Presentation/Activity/Components/TrainingLoadChartView.swift` | visible range 표시, chart scroll position, selection probe, moving average 복구 | Training chart를 실제 scrollable chart로 완성하고 디버그 코드 제거 |
| `DUNE/Presentation/Activity/WeeklyStats/Components/DailyVolumeChartView.swift` | chart visible range와 scroll overlay 연결 | Weekly chart와 동일 interaction 모델 유지 |
| `DUNE/Presentation/Shared/Extensions/VolumePeriod+View.swift` | period별 visible domain/initial range 계산 공통화 | chart별 스크롤 기준을 일관되게 적용 |
| `DUNE/Presentation/Shared/Charts/ChartSelectionOverlay.swift` | UI test surface 추가 | 차트 visible range를 안정적으로 읽고 selection overlay를 공통 검증 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | `scrollToHittableElementIfNeeded` 추가 | 화면 아래 차트도 gesture 전에 실제 터치 가능한 위치로 이동 |
| `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift` | Weekly/Training chart scroll + long-press regression 추가 및 training chart hittable scroll 적용 | 차트 scroll/selection 회귀를 기능 위치 그대로 검증 |

### Key Code

```swift
@discardableResult
func scrollToHittableElementIfNeeded(
    _ identifier: String,
    maxSwipes: Int = 8,
    direction: ScrollDirection = .up,
    timeoutPerCheck: TimeInterval = 1
) -> Bool {
    let element = descendants(matching: .any)[identifier].firstMatch

    if !element.waitForExistence(timeout: timeoutPerCheck) {
        _ = scrollToElementIfNeeded(identifier, maxSwipes: maxSwipes, direction: direction)
    }

    for _ in 0..<maxSwipes where !(element.exists && element.isHittable) {
        preferredScrollContainer().swipeUp()
    }

    return element.exists && element.isHittable
}
```

## Prevention

### Checklist Addition

- [ ] Scrollable chart 회귀 테스트는 `exists`만 보지 말고 gesture 전에 `isHittable` 상태까지 확인한다
- [ ] Activity 상세 차트는 current period만이 아니라 previous period history까지 포함하는지 검증한다
- [ ] HealthKit 의존 chart는 manual fallback 데이터에서도 scrollable domain이 유지되는지 단위 테스트로 확인한다

### Rule Addition (if applicable)

새 전역 rule 추가보다는 기존 UI 테스트 패턴에 "오프스크린 chart는 hittable 상태까지 스크롤 후 제스처 수행" 원칙을 적용하는 것으로 충분했다.

## Lessons Learned

- SwiftUI Chart scroll 기능은 뷰 설정뿐 아니라 history 데이터 길이가 같이 맞아야 동작한다.
- 같은 chart overlay를 쓰더라도 상세 화면 내 배치 위치가 다르면 UI 테스트 전략도 달라져야 한다.
- 임시 디버그 코드로 원인을 좁힌 뒤에는 원래 시각적 요소와 회귀 테스트를 함께 복구해야 안정적으로 마무리된다.
