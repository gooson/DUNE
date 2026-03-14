---
tags: [wellness, readiness, condition, hourly, detail-view, rolling-24h]
date: 2026-03-15
category: plan
status: draft
---

# Wellness & Readiness 상세 화면 시간당 표시

## Problem

컨디션 점수는 `.day` 기간에서 rolling 24h 시간당 차트를 제공하지만, 관련 지표인 웰니스와 레디니스 상세 화면은 일별(daily) 단위만 표시함. 세 지표의 시간 해상도가 불일치.

## Approach

`HourlyScoreSnapshot`에 이미 시간당 wellness/readiness 점수가 저장되어 있으므로, 이를 활용하여 `.day` 기간 선택 시 시간당 차트를 표시.

- 컨디션은 raw HRV 샘플에서 `executeIntraday()`로 재계산 (이미 구현됨)
- 웰니스/레디니스는 `HourlyScoreSnapshot`에서 직접 읽음 (composite score이므로 재계산 대신 저장된 값 사용)

## Affected Files

| File | Change |
|------|--------|
| `WellnessScoreDetailViewModel.swift` | `.day` 분기 + `loadHourlyData()` 추가, `ScoreRefreshService` 의존성 |
| `WellnessScoreDetailView.swift` | `ScoreRefreshService` 전달, sub-score charts `.day` 숨김 |
| `WellnessView.swift` | `scoreRefreshService` 전달 |
| `TrainingReadinessDetailViewModel.swift` | `.day` 분기 + `loadHourlyData()` 추가, `ScoreRefreshService` 의존성 |
| `TrainingReadinessDetailView.swift` | `ScoreRefreshService` 전달, sub-score charts `.day` 숨김 |
| `ActivityView.swift` | `scoreRefreshService` 전달 |
| `ScoreRefreshService.swift` | `fetchRolling24hSnapshots()` 추가 |
| `ConditionScoreDetailViewModel.swift` | 재검증 (컨디션도 재점검 요청) |

## Implementation Steps

### Step 1: ScoreRefreshService에 rolling 24h fetch 추가

`fetchRolling24hSnapshots() -> [HourlyScoreSnapshot]` 메서드 추가.
기존 `fetchSnapshots(for:)`는 단일 날짜 기준이라 rolling 24h에 부적합.

### Step 2: WellnessScoreDetailViewModel 시간당 지원

1. `scoreRefreshService: ScoreRefreshService?` 의존성 추가
2. `loadData()`에서 `selectedPeriod == .day` 분기 추가
3. `loadHourlyData()` 메서드 구현: snapshot에서 wellnessScore 읽어 ChartDataPoint 변환
4. `.day` 기간에서 scroll position을 rolling 24h offset으로 설정
5. sub-score trends를 빈 배열로 설정 (시간당에서는 미표시)

### Step 3: WellnessScoreDetailView 수정

1. `ScoreRefreshService?` 파라미터 추가, VM에 전달
2. sub-score chart를 `selectedPeriod != .day` 조건으로 감싸기

### Step 4: TrainingReadinessDetailViewModel 시간당 지원

Step 2와 동일 패턴으로 readinessScore 키패스 사용.

### Step 5: TrainingReadinessDetailView 수정

Step 3과 동일 패턴.

### Step 6: 호출부 업데이트

- `WellnessView.swift`: `scoreRefreshService` 전달
- `ActivityView.swift`: `scoreRefreshService` 전달

### Step 7: 컨디션 재점검

기존 `ConditionScoreDetailViewModel.loadHourlyData()` 동작 검증.

## Test Strategy

- 빌드 통과 확인 (`scripts/build-ios.sh`)
- 기존 `ConditionScoreDetailViewModelTests`의 rolling 24h 테스트가 여전히 통과하는지 확인

## Risks & Edge Cases

- **스냅샷 비어있음**: 앱을 막 설치한 경우 — 빈 차트 표시 (기존 empty state 재사용)
- **DST 전환**: `HourlyScoreSnapshot.hourTruncated` 이미 calendar-aware
- **키패스 nil**: snapshot에 wellnessScore/readinessScore가 nil일 수 있음 — compactMap으로 필터
