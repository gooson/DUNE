---
tags: [wellness, readiness, condition, hourly, detail-view, rolling-24h, HourlyScoreSnapshot]
date: 2026-03-15
category: architecture
status: implemented
---

# Wellness & Readiness 상세 화면 시간당 표시

## Problem

컨디션 점수 상세 화면은 `.day` 기간에서 rolling 24h 시간당 차트를 제공하지만, 관련 지표인 웰니스와 레디니스 상세 화면은 일별(daily) 단위만 표시. 세 지표의 시간 해상도가 불일치하여 사용자가 시간대별 변화를 추적할 수 없음.

## Solution

### 접근 방식

- **컨디션**: 이미 raw HRV 샘플에서 `executeIntraday()`로 시간당 재계산 구현됨 (기존 유지)
- **웰니스/레디니스**: `HourlyScoreSnapshot`에 이미 시간당 점수가 저장되어 있으므로, snapshot에서 직접 읽어 차트 데이터 생성

### 핵심 변경

1. `ScoreRefreshService`에 `rollingWindowSeconds` 상수 및 `fetchRolling24hSnapshots()` 추가
2. `WellnessScoreDetailViewModel`과 `TrainingReadinessDetailViewModel`에 `loadHourlyData()` 추가
3. `selectedPeriod == .day` 일 때 hourly 데이터 로드 + sub-score charts 숨김
4. `ScoreRefreshService`를 detail view까지 DI 전달

### Key Files

| File | Change |
|------|--------|
| `ScoreRefreshService.swift` | `rollingWindowSeconds` 상수, `fetchRolling24hSnapshots()`, `rolling24hDescriptor()` |
| `WellnessScoreDetailViewModel.swift` | `loadHourlyData()`, `scoreRefreshService` DI |
| `TrainingReadinessDetailViewModel.swift` | `loadHourlyData()`, `scoreRefreshService` DI |
| `ConditionScoreDetailViewModel.swift` | `rollingWindowSeconds` → 공유 상수로 변경 |
| `WellnessScoreDetailView.swift` | `scoreRefreshService` init, sub-score `.day` 조건 |
| `TrainingReadinessDetailView.swift` | `scoreRefreshService` init, sub-score `.day` 조건 |
| `WellnessView.swift` | `scoreRefreshService` 저장 및 전달 |
| `ActivityView.swift` | `scoreRefreshService` 저장 및 전달 |

## Prevention

- **신규 점수 상세 화면 추가 시**: `.day` 기간 hourly 지원을 기본으로 포함할 것
- **rollingWindowSeconds 변경 시**: `ScoreRefreshService.rollingWindowSeconds` 단일 소스 변경으로 전체 반영
- **HourlyScoreSnapshot에 새 score 필드 추가 시**: `fetchRolling24hSnapshots()` 변경 없이 keypath만 지정하면 됨

## Lessons Learned

- Composite score(웰니스, 레디니스)는 raw 데이터에서 재계산하기보다 저장된 snapshot을 활용하는 것이 효율적
- 여러 ViewModel에 분산된 매직 넘버는 공유 상수로 추출해야 DRY 원칙 유지 가능
