---
tags: [sleep, ui-integration, waso, breathing, correlation, nocturnal-vitals, localization]
date: 2026-03-28
category: plan
status: approved
---

# Plan: 수면 분석 카드 통합 + 데이터 로딩 + 번역

## Overview

이전 PR(#642)에서 생성한 4개 수면 카드와 UseCase를 실제 화면에 배치하고,
수면-운동 상관분석/야간 바이탈 데이터 로딩을 구현하며, 번역을 등록한다.

## Affected Files

### 수정 대상

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift` | wasoAnalysis, breathingAnalysis, exerciseCorrelation, nocturnalVitals 프로퍼티 + 로딩 |
| `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | 4개 카드 배치 (sleep 조건부) |
| `DUNE/Presentation/Sleep/SleepViewModel.swift` | exerciseCorrelation, nocturnalVitals 로딩 복원 |
| `Shared/Resources/Localizable.xcstrings` | 새 문자열 ko/ja 번역 등록 |

## Implementation Steps

### Step 1: MetricDetailViewModel에 수면 인사이트 프로퍼티 + 로딩 추가

**목표**: `loadSleepInsightCards()`에서 WASO, breathing, correlation, nocturnal vitals를 병렬 로드

**새 프로퍼티:**
```swift
private(set) var wasoAnalysis: WakeAfterSleepOnset?
private(set) var breathingAnalysis: BreathingDisturbanceAnalysis?
private(set) var exerciseCorrelation: SleepExerciseCorrelation?
private(set) var nocturnalVitals: NocturnalVitalsSnapshot?
```

**서비스 의존성 추가:**
```swift
private let breathingService: BreathingDisturbanceQuerying
private let vitalsService: VitalsQuerying  // 이미 존재하는지 확인
private let heartRateService: HeartRateQuerying  // 이미 존재하는지 확인
```

**로딩 전략:**
- WASO: 이미 fetch된 todayStages로 동기 계산
- Breathing: `breathingService.fetchNightlyDisturbances(days: 30)`
- ExerciseCorrelation: sleepService의 90일 데이터 + WorkoutQueryService의 90일 운동 데이터 매칭
  - ViewModel은 ModelContext 없으므로 WorkoutQueryService(HealthKit)를 사용
  - intensity = workout effort score 또는 duration 기반 추정
- NocturnalVitals: 수면 윈도우 내 HR/RR/temp/SpO2 fetch → AggregateNocturnalVitalsUseCase

**Verification**: 빌드 통과

### Step 2: MetricDetailView에 4개 카드 배치

**위치**: `SleepDeficitGaugeView` 뒤, `Exercise totals + Highlights` 앞 (line 102-104 사이)

```swift
// WASO card
if metric.category == .sleep, let waso = viewModel.wasoAnalysis {
    WakeAnalysisCard(analysis: waso)
}

// Breathing disturbance card
if metric.category == .sleep, let breathing = viewModel.breathingAnalysis,
   !breathing.samples.isEmpty {
    BreathingDisturbanceCard(analysis: breathing)
}

// Exercise correlation card
if metric.category == .sleep, let correlation = viewModel.exerciseCorrelation,
   correlation.dataPointCount >= 7 {
    SleepExerciseCorrelationCard(correlation: correlation)
}

// Nocturnal vitals card
if metric.category == .sleep, let vitals = viewModel.nocturnalVitals {
    NocturnalVitalsChartView(snapshot: vitals)
}
```

**Verification**: 빌드 통과, 수면 상세 화면에 카드 렌더링

### Step 3: SleepViewModel에 exerciseCorrelation + nocturnalVitals 로딩 복원

이전에 dead code로 제거했던 프로퍼티와 로딩을 복원한다.
`loadEnhancedInsights()`에서 breathing과 함께 병렬 로드.

**Verification**: 빌드 통과

### Step 4: xcstrings 번역 등록

새 문자열 목록:
- Wake Analysis / 기상 분석 / 起床分析
- Awakenings / 각성 횟수 / 覚醒回数
- Total WASO / 총 WASO / 合計WASO
- Longest / 최장 / 最長
- WASO Score / WASO 점수 / WASOスコア
- Breathing Disturbances / 호흡 장애 / 呼吸障害
- /hr avg / /시간 평균 / /時間平均
- elevated nights in 30 days / 30일간 상승한 밤 / 30日間の上昇した夜
- Normal / 정상 / 正常
- Mild / 경미 / 軽度
- Elevated / 상승 / 上昇
- Significant / 주의 / 要注意
- Sleep & Exercise / 수면 및 운동 / 睡眠と運動
- Rest Day / 휴식일 / 休息日
- Light / 가벼운 / 軽い
- Moderate / 적당한 / 適度
- Intense / 강한 / 激しい
- More data needed for accurate analysis / 정확한 분석을 위해 더 많은 데이터가 필요합니다 / 正確な分析にはより多くのデータが必要です
- Overnight Vitals / 야간 바이탈 / 夜間バイタル
- No data available for this metric / 이 지표의 데이터가 없습니다 / この指標のデータがありません
- Min HR / 최저 심박수 / 最低心拍数
- Avg HR / 평균 심박수 / 平均心拍数
- Avg RR / 평균 호흡수 / 平均呼吸数
- Temp Δ / 온도 Δ / 温度Δ

**Verification**: xcstrings 파일에 en/ko/ja 3개 언어 존재

## Test Strategy

- 기존 테스트는 모두 통과해야 함
- MetricDetailViewModel sleep loading은 HealthKit mock이 필요하여 통합 테스트 영역
- UI 배치는 WellnessSmokeTests 회귀 확인으로 검증

## Edge Cases

- Apple Watch 미착용 → breathing/nocturnal vitals nil → 카드 숨김
- 운동 데이터 부족 → correlation.dataPointCount < 7 → 카드 숨김
- 수면 데이터 없는 날 → WASO nil → 카드 숨김

## Risks

- MetricDetailViewModel에 너무 많은 서비스 의존성 추가 → 최소한으로 제한
- xcstrings 수동 편집 시 JSON 파싱 에러 가능 → 신중하게 편집
