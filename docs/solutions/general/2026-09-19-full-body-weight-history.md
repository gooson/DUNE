---
tags: [healthkit, weight, history, pagination, concurrency]
date: 2026-09-19
category: general
status: implemented
related_files:
  - DUNE/Presentation/BodyComposition/BodyCompositionViewModel.swift
  - DUNE/Presentation/Shared/Detail/AllDataViewModel.swift
  - DUNE/Presentation/Shared/Detail/AllDataView.swift
---

# 오래된 체중 기록 조회와 UI 응답성

## Problem

건강 앱에 2011년부터 체중 기록이 있어도 DUNE에서 전부 보이지 않았다. 체성분 기록은 최근 90일만 조회했고, 전체 데이터 화면은 30일 구간에 기록이 없으면 더 오래된 기록 조회를 중단했다.

## Solution

- 체성분 기록 화면은 weight/body fat/lean body mass를 `.distantPast`부터 현재까지 비동기 병렬 조회한다.
- 샘플 필터링, 날짜별 병합 및 정렬은 detached task에서 실행하고 MainActor에는 결과만 전달한다.
- DUNE sync 샘플 제외 규칙을 유지하고 같은 날 지표별 최신 측정값을 선택한다.
- 요청 ID와 cancellation 확인으로 이전 요청이 최신 결과를 덮어쓰지 않도록 한다.
- 상세 차트와 전체 데이터 목록은 후속 전체 지표 통일 구현을 사용한다. 목록은 날짜 구간 페이지와 실제 이전 기록 날짜로 빈 기간을 건너뛰며, 차트는 최초 기록까지 탐색하되 화면 주변 구간만 조회한다.
- 차트 눈금 수를 제한하고 조회 중 기존 차트를 유지한다. 체중 전용 전체 샘플 배열과 200개 표시 페이지는 더 이상 사용하지 않는다.

후속 구현과 검증은 [전체 지표 이력 처리](../performance/2026-09-19-all-metric-history-windows.md)에 기록한다.

## Validation

체성분 병합의 같은 날 최신값과 관리 샘플 제외 테스트를 유지한다. 전체 데이터/차트 회귀 테스트는 체중을 포함한 16개 지표에 2011년 기록과 빈 연도를 주입해 조회·페이지·스크롤 범위를 검증한다. DEBUG 시뮬레이터의 `--uitesting` 실행에서만 장기 이력 fixture를 사용할 수 있다.

## Prevention

빈 날짜 구간을 전체 기록의 끝으로 해석하지 않는다. 장기 기록의 정렬·병합을 MainActor에서 수행하지 않는다. 전체 원본 조회를 고빈도 심박수 등 다른 지표에 그대로 확대하지 않는다.

## Lessons Learned

건강 기록은 수개월·수년의 공백이 있을 수 있다. 전체 탐색 범위와 실제 조회·렌더링 범위를 분리해야 한다. 별도 체성분 기록 화면의 전체 병합과 상세 차트의 구간 조회는 목적이 다른 경로다.
