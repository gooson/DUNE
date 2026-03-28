---
tags: [bugfix, weekly-stats, date-range, referenceDate, analyze]
date: 2026-03-29
category: plan
status: approved
---

# Fix: "Last Week" Summary Cards Empty Despite Chart Data

## Problem

WeeklyStatsDetailView에서 "지난 주" 탭 선택 시 상단 요약 카드(볼륨, 소요 시간, 칼로리, 세션, 활동 일수)가 전부 0/빈 값으로 표시됨. 하단 일별 상세 차트에는 데이터가 정상 표시됨.

### Root Cause

`TrainingVolumeAnalysisService.analyze()`가 내부에서 항상 `Date()`를 기준으로 current period 범위를 계산:
- `today = startOfDay(Date())`
- `currentStart = today - 7`, `currentEnd = Date()`

ViewModel이 지난 주 데이터(now-14 ~ now-7)를 필터링해서 넘겨도, `analyze()` 내부에서 이번 주(now-7 ~ now) 범위로 재필터링하여 교집합이 비어짐.

차트는 `buildHistoryDailyBreakdown()`을 사용하는데, 이 메서드는 명시적 start/end를 받으므로 정상 동작.

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Domain/UseCases/TrainingVolumeAnalysisService.swift` | `referenceDate` 파라미터 추가 |
| `DUNE/Presentation/Activity/WeeklyStats/WeeklyStatsDetailViewModel.swift` | pre-filtering 제거, `referenceDate` 전달 |
| `DUNETests/TrainingVolumeAnalysisServiceTests.swift` | referenceDate 테스트 2개 추가 |

## Implementation Steps

### Step 1: TrainingVolumeAnalysisService.analyze() 수정
- `referenceDate: Date = Date()` 파라미터 추가
- `let today = calendar.startOfDay(for: referenceDate)` 사용
- `let currentEnd = referenceDate` 사용
- 기존 호출자는 default 값으로 동작 유지

### Step 2: WeeklyStatsDetailViewModel 수정
- lastWeek 전용 수동 필터링(lines 113-123) 제거
- `analyze()` 호출 시 `referenceDate: range.end` 전달
- thisWeek/thisMonth은 `range.end = Date()`이므로 기존 동작 유지

### Step 3: 테스트 추가
- `referenceDate`가 분석 윈도우를 과거로 시프트하는지 검증
- 기본값이 기존 today 기반 동작과 동일한지 검증

## Test Strategy

- **Unit**: `TrainingVolumeAnalysisServiceTests` — referenceDate 시프트 + 기본값 동등성
- **Regression**: 기존 17개 테스트 전부 통과 확인 (default referenceDate)
- **Manual**: 시뮬레이터에서 Last Week 탭 전환 후 카드 값 표시 확인

## Risks & Edge Cases

- **기존 호출자**: `TrainingVolumeViewModel`, `ExerciseTypeDetailViewModel`은 default `Date()` 사용하므로 영향 없음
- **Boundary**: lastWeek의 `range.end`가 정확히 7일 전 시각이므로 `startOfDay` 처리와 정합
- **Previous period**: lastWeek 기준 previous는 now-21 ~ now-14가 되어 정상

## Related

- `docs/solutions/general/2026-03-29-weekly-stats-period-alignment.md` — 동일 서비스의 이전 기간 정렬 수정
- Correction #213: summary/detail metric 데이터 소스 parity 필수
