---
tags: [rpe, chart, coaching, overtraining, swift-charts]
date: 2026-03-15
category: solution
status: implemented
---

# RPE Trend Chart & Overtraining Warning

## Problem Statement

RPE (Rate of Perceived Exertion) 데이터가 세트/세션 레벨에서 수집되고 있지만, 시간 경과에 따른 트렌드 시각화가 없고, 연속 고강도 세션에 대한 경고 메커니즘이 없었다.

## Solution

### 1. RPE Trend Chart (Activity 탭)

**패턴**: TrainingLoadChartView 미러링

- `RPETrendDataPoint` 데이터 모델 (date, averageRPE, sessionCount)
- `TrainingVolumeViewModel.buildRPETrendData()` static 메서드로 일별 평균 RPE 집계
- `RPETrendChartView`: BarMark (색상 코딩 존) + 7일 이동평균 LineMark
- 스크롤 가능한 차트 선택, FloatingChartSelectionOverlay 재사용
- Y축 고정 도메인 0-10

**RPE 존 색상 매핑**:
| RPE | Zone | Color |
|-----|------|-------|
| <5 | Light | DS.Color.positive |
| 5-7 | Moderate | DS.Color.caution |
| 7-9 | Hard | DS.Color.scoreTired |
| 9+ | Max | DS.Color.negative |

### 2. Overtraining Warning (CoachingEngine)

**패턴**: 기존 recovery trigger 확장

- `CoachingInput.recentHighRPEStreak: Int` 필드 추가
- `DashboardViewModel.computeHighRPEStreak()`: 최근 세션부터 RPE >= 8 연속 카운트
- P1 (critical): 5+ 연속 → `recovery-rpe-overtraining`
- P2 (high): 3-4 연속 → `recovery-rpe-elevated`
- nil RPE는 streak 중단

## Key Decisions

1. **Static 메서드 패턴**: `buildRPETrendData()`와 `computeHighRPEStreak()`를 static으로 구현하여 테스트 용이성 확보 + View에서 @Query 데이터 전달
2. **방어적 정렬**: `computeHighRPEStreak`에서 정렬 유지 — 호출자가 정렬 보장을 알 수 없는 static 메서드
3. **범위 필터링**: RPE 1-10 범위 외 값은 트렌드 데이터에서 제외

## Prevention

- 새 차트 추가 시 기존 차트 패턴(TrainingLoadChartView) 미러링
- CoachingEngine trigger 추가 시 반드시 테스트에서 threshold 경계값 검증
- 새 CoachingInput 필드 추가 시 모든 call site (DashboardViewModel, 테스트 파일들) 동기화 필수

## Files Changed

| File | Change |
|------|--------|
| `Domain/UseCases/CoachingEngine.swift` | CoachingInput 필드 + 2개 RPE trigger |
| `Presentation/Activity/Components/RPETrendChartView.swift` | NEW: RPE 바 차트 |
| `Presentation/Activity/TrainingVolume/TrainingVolumeDetailView.swift` | 차트 섹션 추가 |
| `Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift` | RPE 집계 로직 |
| `Presentation/Dashboard/DashboardView.swift` | @Query + streak 계산 |
| `Presentation/Dashboard/DashboardViewModel.swift` | streak 프로퍼티 + static 메서드 |
| `DUNETests/RPETrendChartDataTests.swift` | NEW: 8개 데이터 집계 테스트 |
| `DUNETests/CoachingEngineTests.swift` | 6개 RPE streak 테스트 |
