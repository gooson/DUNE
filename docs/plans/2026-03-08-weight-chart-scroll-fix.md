---
tags: [charts, scroll, weight, body-composition, AreaLineChartView]
date: 2026-03-08
category: plan
status: draft
---

# Plan: Weight 류 상세 화면 과거 스크롤 불가 수정

## Problem

웰니스의 weight, BMI, bodyFat, leanBodyMass 상세 화면에서 차트를 과거 방향으로 스크롤할 수 없음.

### Root Cause

1. **chartXScale 미설정**: `AreaLineChartView`에 `.chartXScale(domain:)`이 없어 Swift Charts가 실제 데이터 포인트 범위로 x축 도메인을 자동 결정함. Weight 류 데이터는 sparse(매일 측정하지 않음)하여 데이터 범위 ≤ `visibleDomainSeconds`일 때 스크롤 불가.
2. **bodyFat/leanBodyMass 데이터 범위 고정**: `loadBodyFatData()`와 `loadLeanBodyMassData()`가 `extendedRange` 대신 고정 `days: 90`을 사용하여 기간 선택/스크롤 버퍼를 무시함.

### 대비: BarChartView는 정상 동작

Steps/Exercise 등 BarChartView는 `fillDateGaps()`로 확장 범위 전체에 빈 데이터 포인트를 채워 x축 도메인이 확장 범위를 커버함.

## Solution

AreaLineChartView에 `scrollDomain` 파라미터를 추가하고 `.chartXScale(domain:)`을 적용하여 데이터 밀도와 무관하게 확장 범위 전체를 스크롤 가능하게 함.

## Affected Files

| 파일 | 변경 유형 |
|------|----------|
| `DUNE/Data/HealthKit/BodyCompositionQueryService.swift` | protocol에 `fetchBodyFat(start:end:)`, `fetchLeanBodyMass(start:end:)` 추가 |
| `DUNE/Presentation/Shared/Charts/AreaLineChartView.swift` | `scrollDomain` 파라미터 + `.chartXScale(domain:)` 적용 |
| `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift` | `scrollDomain` 공개, bodyFat/leanBodyMass 데이터 로딩을 extendedRange로 변경 |
| `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | AreaLineChartView 호출에 `scrollDomain` 전달 |
| `DUNETests/MetricDetailViewModelTests.swift` | mock 업데이트 + 스크롤 도메인 테스트 |
| 기타 테스트 mock 파일 | protocol 변경에 따른 mock 동기화 |

## Implementation Steps

### Step 1: Protocol + Service 확장

`BodyCompositionQuerying`에 `fetchBodyFat(start:end:)`, `fetchLeanBodyMass(start:end:)` 추가.
`BodyCompositionQueryService`에 구현 추가 (기존 `fetchWeight(start:end:)` 패턴 따름).

### Step 2: ViewModel 수정

- `extendedRange`를 `scrollDomain: ClosedRange<Date>` 공개 computed property로 노출
- `loadBodyFatData()`: `extendedRange` + `fetchBodyFat(start:end:)` 사용 + summary에 `prevRange` 비교 추가
- `loadLeanBodyMassData()`: 동일 패턴 적용

### Step 3: AreaLineChartView 수정

- `var scrollDomain: ClosedRange<Date>? = nil` 파라미터 추가
- `.chartXScale(domain:)` 적용: `scrollDomain`이 있으면 사용, 없으면 기존 auto 동작

### Step 4: MetricDetailView 연결

- AreaLineChartView 호출 시 `scrollDomain: viewModel.scrollDomain` 전달

### Step 5: 테스트 mock 동기화

- 모든 `BodyCompositionQuerying` mock에 새 메서드 추가
- `MetricDetailViewModelTests`에 scrollDomain 검증 테스트 추가

## Test Strategy

- `MetricDetailViewModelTests`: scrollDomain이 extendedRange를 반영하는지 확인
- bodyFat/leanBodyMass가 extendedRange로 데이터 로드하는지 확인
- 기존 테스트 regression 없음 확인

## Risks / Edge Cases

- 데이터가 전혀 없는 경우: chartEmptyState가 표시되므로 scrollDomain 불필요
- 데이터가 1~2개만 있는 경우: chartXScale이 전체 범위를 보여주되 빈 영역이 많음 → Apple Health 앱도 동일 동작
- vitals(respiratoryRate, wristTemperature)도 AreaLineChartView 사용하지만 별도 이슈로 분리 (surgical scope)
