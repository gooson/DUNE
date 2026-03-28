---
tags: [chart, volume, weekly-stats, activity]
date: 2026-03-29
category: plan
status: draft
---

# Weekly Stats 일별 상세 그래프에 볼륨 메트릭 추가

## Problem Statement

현재 `WeeklyStatsDetailView`의 "Daily Breakdown" 차트(`DailyVolumeChartView`)는 Duration과 Sessions 두 가지 메트릭만 지원한다. 사용자가 일별 볼륨(kg) 추이도 같은 차트에서 확인할 수 있도록 Volume 메트릭을 추가한다.

## Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Domain/Models/TrainingVolume.swift` | `DailyVolumePoint`에 `totalVolume: Double` 추가 |
| `DUNE/Domain/UseCases/TrainingVolumeAnalysisService.swift` | `buildDailyBreakdown`에서 volume 집계 |
| `DUNE/Presentation/Activity/WeeklyStats/Components/DailyVolumeChartView.swift` | `.volume` 메트릭 케이스 + 차트 로직 |
| `Shared/Resources/Localizable.xcstrings` | "Volume (kg)" 번역 추가 (en/ko/ja) |
| `DUNETests/WeeklyStatsDetailViewModelTests.swift` | 볼륨 데이터 포함 테스트 보강 |
| `DUNETests/PeriodComparisonTests.swift` | `DailyVolumePoint` init 호출 업데이트 |

## Implementation Steps

### Step 1: Domain 모델 확장

`DailyVolumePoint`에 `totalVolume: Double = 0` 추가.
- 기본값 0으로 기존 init 호출(`StackedVolumeBarChartView`, tests)은 변경 불필요
- computed property 아닌 stored property (buildDailyBreakdown에서 직접 설정)

### Step 2: Service에서 volume 집계

`TrainingVolumeAnalysisService.buildDailyBreakdown`에서:
- `dailyVolume: [Date: Double]` 추가
- `manualRecords` loop에서 `totalVolume > 0`인 경우 해당 day에 합산
- `DailyVolumePoint` 생성 시 `totalVolume` 전달

### Step 3: Chart UI 메트릭 추가

`DailyVolumeChartView.Metric`에 `.volume` 케이스 추가:
- `displayName`: `String(localized: "Volume (kg)")`
- `valueFor`: `point.totalVolume`
- `formattedValue`: `"{value} kg"` 형식
- `maxY`: volume 값 기준 최대값

### Step 4: Localization

`Localizable.xcstrings`에 "Volume (kg)" 키 추가:
- ko: "볼륨 (kg)"
- ja: "ボリューム (kg)"

### Step 5: 테스트

- `PeriodComparisonTests`: `DailyVolumePoint` init에 `totalVolume` 파라미터 추가 (기본값 있으므로 기존 테스트는 자동 호환)
- `WeeklyStatsDetailViewModelTests`: volume 데이터가 포함된 snapshot으로 `buildDailyWeightVolume` 정합성 확인

## Test Strategy

- **Unit**: `DailyVolumePoint.totalVolume` 기본값 0 확인, volume 있는 날의 집계 정확성
- **Integration**: `buildDailyBreakdown`에 volume > 0인 manual record 전달 시 일별 합산 검증
- **UI**: 차트 메트릭 피커에 Volume 옵션 표시 확인

## Risks & Edge Cases

1. **volume = 0인 날**: 기존 duration/sessions와 동일하게 0 bar 표시 (이미 처리됨)
2. **모든 날 volume = 0**: 차트 Y축 domain `0...1`로 fallback (기존 `maxY` 패턴 사용)
3. **기존 init 호환**: `totalVolume: Double = 0` 기본값으로 기존 코드 무수정
4. **`StackedVolumeBarChartView`**: volume을 사용하지 않으므로 영향 없음
