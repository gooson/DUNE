---
tags: [healthkit, swift-charts, prefetch, cancellation, scroll, y-axis]
category: performance
date: 2026-09-19
severity: important
related_files:
  - DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift
  - DUNETests/MetricDetailViewModelTests.swift
  - DUNEUITests/Regression/ChartInteractionRegressionUITests.swift
related_solutions:
  - performance/2026-09-19-all-metric-history-windows.md
---

# Solution: 연속 스크롤 중 차트 과거 조회 유지

## Problem

### Symptoms

체중 YEAR 차트를 여러 해 연속으로 이동하면 그래프가 잠시 비었다가 나타났다. 구간 교체 때 Y축도 반복해서 바뀌었다.

### Root Cause

과거 조회가 요약 통계를 갱신하는 100ms trailing debounce 작업에 연결되어 있었다. 스크롤 위치가 계속 바뀌면 대기뿐 아니라 실행 중인 조회도 취소했다. 사용자는 제한된 데이터 구간을 벗어났지만 새 구간 조회는 끝나지 못했다. 체중 Y축 역시 구간마다 새 최솟값·최댓값으로 축소되어 시각적인 변동이 생겼다.

## Solution

- 스크롤 위치 변경 시 별도 prefetch 작업을 즉시 시작한다. 요약 통계만 기존 debounce를 사용한다.
- 실행 중인 조회는 스크롤 위치 변경으로 취소하지 않는다. 완료 후 최신 위치가 범위를 벗어났으면 다음 구간을 순차 조회한다.
- 조회 구간을 위치 기준 앞 2개·뒤 3개 화면으로 넓히고, 여유 구간이 부족해지면 미리 읽는다. 전체 이력을 한 번에 읽지는 않는다.
- 기간 변경·화면 재설정·명시적 새로고침은 작업을 취소한다. 작업 ID로 이전 작업이 새 작업 상태를 지우는 것을 막는다. 오류 발생 시 반복 조회를 끝낸다.
- 체중 Y축은 과거 탐색 중 기존 범위와 새 범위의 합집합을 사용한다. 기간을 다시 선택하거나 명시적으로 로드하면 새 범위를 계산한다.

### Key Code

```swift
repeat {
    await loadData(historyNavigation: true)
    guard id == historyPrefetchID, !Task.isCancelled else { return }
    guard errorMessage == nil else { break }
} while needsHistoryPrefetch
```

## Validation

- 실기기 대상 커밋 훅 빌드 통과.
- `MetricDetailViewModelTests`와 `AllMetricHistoryTests`의 28개 테스트 통과.
- 보류된 조회 중 연속 위치 변경에도 조회가 취소되지 않는 회귀 테스트 추가.
- 과거 구간 교체 중 체중 Y축 범위가 축소되지 않는 회귀 테스트 추가.
- iPhone 17 / iOS 27.0 UI 테스트 2개 통과: 체중 YEAR에서 연속 5회 과거 이동과 HRV 과거 이동. 표시 날짜 변경과 차트 표면 존재를 검증했다. 실제 사용자 HealthKit 저장소의 응답 시간이나 프레임 속도를 측정한 테스트는 아니다.

## Prevention

- 네트워크·HealthKit 조회 생명주기를 스크롤 요약용 debounce와 분리한다.
- 한 번 이동 후 기다리는 테스트 외에 조회가 끝나기 전 위치가 여러 번 바뀌는 테스트를 포함한다.
- 제한된 데이터 교체 시 축 범위 변화도 확인한다.
- 시뮬레이터 날짜 이동 성공을 실기기 프레임 속도나 HealthKit 응답 시간 보장으로 해석하지 않는다.

## Lessons Learned

전체 과거 날짜로 이동할 수 있는 것과 연속 이동 중 데이터가 제때 준비되는 것은 별개의 요구사항이다. 기존 단일 이동 테스트는 취소가 반복되는 문제를 잡지 못했다. 계속 유효한 조회를 보존하고 최신 위치로 따라잡는 방식이 필요하다.
