---
tags: [observable, didSet, cached-property, test-failure, ci]
date: 2026-04-06
category: testing
status: implemented
---

# AllDataViewModel groupedByDate didSet 수정

## Problem

CI nightly unit test `groupedByDateOrdering` 실패:
- `AllDataViewModel.groupedByDate`가 stored property이고 `loadNextPage()` 내에서만 `invalidateGroupedByDate()` 호출로 갱신
- 테스트가 `vm.dataPoints`를 직접 설정하면 `groupedByDate`가 비어있는 상태 유지
- `grouped.count → 0 == 2` 실패

## Root Cause

`@Observable` 클래스에서 stored property 캐시를 도입할 때, 소스 데이터 변경 시 자동 무효화를 연결하지 않고 호출 지점에서만 수동 갱신한 것이 원인.

## Solution

`dataPoints`에 `didSet { invalidateGroupedByDate() }`를 추가하여, 어떤 경로로든 `dataPoints`가 변경되면 `groupedByDate`가 자동 동기화되도록 수정.

기존 패턴: `MetricDetailViewModel.chartData`의 `didSet { invalidateScrollCache() }`.

## Prevention

**`@Observable` 클래스에서 파생 stored property를 도입할 때**:
1. 소스 property에 `didSet`을 추가하여 자동 무효화를 보장할 것
2. 호출 지점에서의 수동 `invalidate()` 호출에만 의존하지 말 것 — 테스트나 외부 설정 경로에서 누락되기 쉬움
3. 기존 프로젝트 패턴(`MetricDetailViewModel`)을 먼저 확인하고 일관되게 적용할 것
