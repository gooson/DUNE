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

- 체성분 기록은 weight/body fat/lean body mass를 `.distantPast`부터 현재까지 비동기 병렬 조회한다.
- 샘플 필터링, 날짜별 병합 및 정렬은 detached task에서 실행하고 MainActor에는 결과만 전달한다.
- DUNE sync 샘플 제외 규칙을 유지하고 같은 날 지표별 최신 측정값을 선택한다.
- 요청 ID와 cancellation 확인으로 이전 요청이 최신 결과를 덮어쓰지 않도록 한다.
- 체중 전체 데이터는 전체 기간 샘플을 한 번 조회·정렬한 뒤 실제 기록 기준 200개씩 표시한다. 빈 기간과 무관하게 마지막 기록까지 이어진다.
- 하단 로딩 task는 표시한 기록 수에 따라 갱신해 다음 페이지를 이어서 표시한다.
- 체중 그래프 역시 전체 기간을 조회한다. 목록 변경만으로는 그래프의 `extendedRange` 제한이 해제되지 않으므로 별도 수정이 필요했다.
- 그래프 x축은 가장 오래된 측정일까지 확장하고, 현재 보이는 기간 전후 buffer만 렌더링한다. 전체 기간 정렬·집계는 detached task로 수행한다.
- 사용자의 실기기 스택은 Charts layout 계산 중이었고 영상에서는 빠른 연도 이동 후 선이 비었다가 늦게 나타났다. 전체 x축에 `.stride` 눈금을 생성하던 비용과, 표시 구간을 100ms debounce 뒤에 변경하던 동작을 보완했다.
- AreaLineChart의 눈금은 현재 viewport 주변의 명시적 날짜 배열로 제한한다. 체중 표시 데이터는 scrollPosition에서 즉시 계산하고 y축 범위는 전체 조회 데이터 기준으로 고정해 이동 중 축 재조정을 피한다.

## Validation

- 최종 `scripts/build-ios.sh --no-regen` 성공.
- iPhone 17 / iOS 27.0 Simulator: AllDataViewModelTests 및 BodyCompositionViewModelTests 총 23개 통과, 실패 0.
- 2011년 기록, 같은 날 최신값, 450개 기록의 200/400/450 페이지 및 중복 방지, 재조회 초기화 검증.
- 실제 사용자 HealthKit 전체 기록 및 실기기 성능은 기기에서 추가 확인 필요.
- 그래프 회귀 시나리오: 2011년부터 5,500개 샘플을 넣고 가장 오래된 날짜로 scrollPosition을 이동했을 때 해당 기록이 표시되며 주간 렌더링 대상이 30개 미만인지 확인한다.
- 그래프 전체 기간 수정 빌드 성공. iPhone 17 / iOS 27.0 Simulator의 MetricDetailViewModelTests 22개 통과.
- 후속 성능 수정은 시뮬레이터 UI 테스트에서 `--uitest-long-weight-history` fixture로 2011년부터 일별 기록을 주입해 Weight 화면을 열고 드래그 시 날짜 범위 이동을 확인했다. UI 테스트 1개 통과. 이 fixture는 DEBUG 시뮬레이터의 `--uitesting` 실행에서만 동작한다.
- 즉시 viewport 변경, y축 유지, 모든 기간의 눈금 개수 제한을 포함한 최종 회귀 테스트: TimePeriodTests + MetricDetailViewModelTests 49개 통과(매개변수 확장 실행 61개), 실패 0. 최종 실기기 대상 빌드 성공.

## Prevention

빈 날짜 구간을 전체 기록의 끝으로 해석하지 않는다. 장기 기록의 정렬·병합을 MainActor에서 수행하지 않는다. 전체 조회는 체중·체성분에 한정하며 고빈도 심박수 기록 등에 무분별하게 확대하지 않는다.

## Lessons Learned

건강 기록은 수개월·수년의 공백이 있을 수 있다. 표시 페이지와 조회 날짜 범위는 분리해야 한다. 현재 체중 구현은 전체 샘플을 메모리에 유지하고 UI를 200개씩 늘리는 방식이며, HealthKit 자체를 200개씩 조회하는 커서 구현은 아니다.
