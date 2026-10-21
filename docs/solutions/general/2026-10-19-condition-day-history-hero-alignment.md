---
tags: [condition-score, day-chart, healthkit, hourly-snapshot, scroll]
date: 2026-10-19
category: general
status: implemented
related_files:
  - DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift
  - DUNE/Data/Services/ScoreRefreshService.swift
  - DUNE/Presentation/Shared/Components/HourlySparklineView.swift
---

# 컨디션 일간 차트의 과거 구간과 히어로 추세 정렬

## Problem

컨디션 상세의 일간 차트는 7일 전까지 스크롤할 수 있지만, HRV 점수 계산은 최근 48시간으로 제한되고 차트에는 최근 24시간 결과만 전달됐다. 과거로 스크롤하면 날짜만 바뀌고 그래프가 비었다. Today 히어로는 저장된 시간별 점수를, 상세 차트는 HRV에서 재계산한 점수를 사용했다. 히어로 선은 저장 시각과 관계없이 점을 같은 간격으로 배치해 상세 차트와 형태도 달라질 수 있었다.

## Solution

- 일간 차트의 스크롤 시작일부터 현재까지 HRV를 조회하고, 가장 오래된 표시 시각보다 14일 앞에서 점수 기준선을 계산한다.
- 한 시간에 HRV가 여러 번 측정됐으면 시간별 점수를 계산한다. 하루에 한 번만 측정돼 시간별 계산을 할 수 없으면 같은 날짜의 일별 점수로 대체한다. 측정이 없는 날은 값을 만들지 않는다.
- 저장된 시간별 점수가 있으면 같은 시간의 재계산 값보다 우선한다. 최신 점은 Today 히어로의 현재 점수를 사용한다.
- 저장되지 않은 시간만 별도 작업에서 계산해 7일 범위 조회가 화면의 메인 스레드를 오래 점유하지 않도록 한다.
- 주간·월간 상세 차트에 오늘의 일별 점수가 있으면 히어로가 사용하는 최신 점수로 맞춘다.
- HealthKit의 제한된 읽기 시작일 이전 점수는 저장 기록에서도 표시하지 않는다.
- HealthKit 접근 범위가 바뀌면 일간 차트의 전체 스크롤 범위에 있는 저장 점수를 무효화한다. 더 오래된 보관 기록은 유지한다.
- 컨디션 히어로의 시간축에는 실제 저장 시각을 사용한다. 다른 점수 히어로의 축은 기존 배치를 유지한다.

## Verification

- `ConditionScoreDetailViewModelTests`: 16개 통과. 이전 날짜 점수, 단일 HRV 기록의 대체 계산, 저장 점수 우선순위 포함.
- `ScoreRefreshServiceTests`와 `HourlySparklineDataTests`: 변경된 테스트 통과. 접근 범위 변경 뒤 3일 전 점수 제거와 10일 전 보관 점수 유지 확인.
- `ChartInteractionRegressionUITests.testConditionDayChartRetainsPointsWhenScrollingToPreviousDays`: iPhone 시뮬레이터에서 통과.
- 일반 iPhone과 iPad의 영향받은 실제 화면 캡처를 다시 수집했다. Duo 캡처 결과는 각 기기의 `capture-index.json`에 기록한다.

## Prevention

- 스크롤 가능한 차트는 X축 범위와 실제 데이터 조회 범위를 함께 비교한다.
- 같은 지표의 히어로와 상세 차트는 겹치는 구간에서 동일한 저장 점수와 실제 시각을 사용한다.
- HealthKit 읽기 범위가 제한되면 저장 점수에도 같은 표시 하한을 적용한다.
