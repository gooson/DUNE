---
tags: [test, fix, ci, observable, cached-property]
date: 2026-04-06
category: plan
status: approved
---

# Fix: AllDataViewModel groupedByDate test failure

## Problem

CI nightly test (`nightly-ios-unit-tests`) fails at `AllDataViewModelTests.swift:252`:
- Test: `groupedByDate returns newest date first and points sorted descending`
- Failure: `grouped.count → 0 == 2`

## Root Cause

`AllDataViewModel.groupedByDate`는 stored property이고 `invalidateGroupedByDate()` 호출로만 업데이트됩니다.
이 메서드는 `loadNextPage()` 내에서만 호출됩니다.
테스트는 `vm.dataPoints`를 직접 설정하지만, `dataPoints`에 `didSet`이 없어서 `groupedByDate`가 갱신되지 않습니다.

## Solution

`dataPoints`에 `didSet { invalidateGroupedByDate() }`를 추가합니다.
이는 프로젝트 내 기존 패턴과 일치합니다 (`MetricDetailViewModel.chartData`의 `didSet { invalidateScrollCache() }`).

## Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Presentation/Shared/Detail/AllDataViewModel.swift` | `dataPoints`에 `didSet` 추가, `loadNextPage()`의 명시적 `invalidateGroupedByDate()` 호출 제거 |

## Implementation Steps

1. `AllDataViewModel.dataPoints`에 `didSet { invalidateGroupedByDate() }` 추가
2. `loadNextPage()`에서 `invalidateGroupedByDate()` 호출 제거 (didSet이 자동 호출하므로 중복)
3. `loadInitialData()`에서 `groupedByDate = []` 직접 할당 제거 (dataPoints = [] 설정 시 didSet이 처리)
4. 빌드 검증
5. 유닛 테스트 실행

## Test Strategy

- 기존 `AllDataViewModelTests`가 통과하는지 확인 (테스트 코드 변경 불필요)
- 빌드 성공 확인

## Risks / Edge Cases

- `@Observable` 매크로가 `didSet`을 지원하는지: 프로젝트 내 5곳에서 이미 사용 중으로 확인됨
- `loadInitialData()`에서 `dataPoints = []` → `didSet` → `invalidateGroupedByDate()` 호출 후, `loadNextPage()` → `dataPoints.append()` → `didSet` → 다시 호출: 빈 배열에 대한 `invalidateGroupedByDate()`는 빈 결과를 반환하므로 무해
