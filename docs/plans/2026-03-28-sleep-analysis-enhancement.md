---
tags: [sleep, healthkit, rem, waso, breathing-disturbances, nocturnal-vitals, exercise-correlation]
date: 2026-03-28
category: plan
status: approved
---

# Plan: 수면 분석 고도화 (0.7.0)

## Overview

수면 분석을 4가지 축으로 고도화한다:
1. Sleep Score에 REM 비율 + WASO 반영
2. Breathing Disturbances 통합
3. 수면-운동 상관분석
4. 야간 바이탈 통합 대시보드

## Affected Files

### 수정 대상

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Data/HealthKit/HealthKitManager.swift` | `appleSleepingBreathingDisturbances` readType 추가 |
| `DUNE/Domain/UseCases/CalculateSleepScoreUseCase.swift` | 5축 재설계 (Duration/Deep/REM/Efficiency/WASO) |
| `DUNE/Presentation/Sleep/SleepViewModel.swift` | WASO/Breathing/Correlation/NocturnalVitals 데이터 로드 |
| `DUNE/Domain/UseCases/CoachingEngine.swift` | Breathing Disturbances elevated 시 인사이트 추가 |
| `DUNE/Domain/Models/HealthMetric.swift` | `.breathingDisturbances` case 추가 |
| `DUNE/Presentation/Shared/Extensions/HealthMetric+View.swift` | breathingDisturbances displayName/icon/color |
| `Shared/Resources/Localizable.xcstrings` | 신규 문자열 en/ko/ja |

### 신규 파일

| 파일 | 설명 |
|------|------|
| `DUNE/Domain/Models/WakeAfterSleepOnset.swift` | WASO 분석 모델 |
| `DUNE/Domain/Models/BreathingDisturbanceAnalysis.swift` | 호흡 장애 분석 모델 |
| `DUNE/Domain/Models/SleepExerciseCorrelation.swift` | 수면-운동 상관 모델 |
| `DUNE/Domain/Models/NocturnalVitalsSnapshot.swift` | 야간 바이탈 스냅샷 모델 |
| `DUNE/Domain/UseCases/AnalyzeWASOUseCase.swift` | WASO 분석 UseCase |
| `DUNE/Domain/UseCases/CorrelateSleepExerciseUseCase.swift` | 수면-운동 상관 UseCase |
| `DUNE/Domain/UseCases/AggregateNocturnalVitalsUseCase.swift` | 야간 바이탈 집계 UseCase |
| `DUNE/Data/HealthKit/BreathingDisturbanceQueryService.swift` | HealthKit 쿼리 서비스 |
| `DUNE/Presentation/Sleep/Components/WakeAnalysisCard.swift` | WASO 카드 UI |
| `DUNE/Presentation/Sleep/Components/BreathingDisturbanceCard.swift` | 호흡 장애 카드 UI |
| `DUNE/Presentation/Sleep/Components/SleepExerciseCorrelationCard.swift` | 수면-운동 상관 카드 UI |
| `DUNE/Presentation/Sleep/Components/NocturnalVitalsChartView.swift` | 야간 바이탈 차트 UI |
| `DUNE/Presentation/Shared/Extensions/SleepStage+WASO.swift` | WASO 관련 View extension |
| `DUNETests/AnalyzeWASOUseCaseTests.swift` | WASO 테스트 |
| `DUNETests/CalculateSleepScoreUseCaseV2Tests.swift` | 재설계된 점수 테스트 |
| `DUNETests/BreathingDisturbanceQueryServiceTests.swift` | 호흡 장애 쿼리 테스트 |
| `DUNETests/CorrelateSleepExerciseUseCaseTests.swift` | 상관분석 테스트 |
| `DUNETests/AggregateNocturnalVitalsUseCaseTests.swift` | 야간 바이탈 집계 테스트 |

## Implementation Steps

### Step 1: WASO 분석 모델 + UseCase (Domain)

**신규 파일**: `WakeAfterSleepOnset.swift`, `AnalyzeWASOUseCase.swift`

```swift
// Domain/Models/WakeAfterSleepOnset.swift
struct WakeAfterSleepOnset: Sendable {
    let awakeningCount: Int          // 5분+ 각성 횟수
    let totalWASOMinutes: Double     // 총 WASO 시간
    let longestAwakening: Double     // 최장 단일 각성 (분)
    let score: Int                   // 0-100 (WASO 기반 점수)
}
```

**UseCase 로직**:
- 수면 개시(첫 non-awake stage) ~ 최종 기상(마지막 non-awake stage) 사이의 awake 구간 필터
- 5분 미만 각성은 noise로 간주하여 제외
- 점수: 0-10분 → 100, 10-30분 → 선형 감소, 30분+ → 최저 20

**테스트**: `AnalyzeWASOUseCaseTests.swift`
- 각성 없음 → score 100
- 10분 각성 1회 → score ~100
- 30분 각성 → score ~50
- 60분+ → score ~20
- 빈 stages → nil 반환

**Verification**: 유닛 테스트 통과

### Step 2: Sleep Score 5축 재설계 (Domain)

**수정 파일**: `CalculateSleepScoreUseCase.swift`

**현재 → 변경:**

| 컴포넌트 | 현재 | 변경 |
|----------|------|------|
| Duration | 40% → 40pt | 30% → 30pt |
| Deep Sleep | 30% → 30pt | 20% → 20pt |
| REM Sleep | — | 15% → 15pt (new) |
| Efficiency | 30% → 30pt | 20% → 20pt |
| WASO | — | 15% → 15pt (new) |

**Output 확장**:
```swift
struct Output: Sendable {
    let score: Int
    let totalMinutes: Double
    let efficiency: Double
    let remRatio: Double        // new
    let wasoMinutes: Double     // new
    let wasoCount: Int          // new
}
```

**REM 점수화**: ideal 20-25%, center 0.225, penalty curve = Deep와 동일 구조

**WASO 점수화**: `AnalyzeWASOUseCase.execute(stages).score`를 15pt 스케일로 매핑

**테스트**: `CalculateSleepScoreUseCaseV2Tests.swift` (기존 테스트 파일도 업데이트)
- 이상적 수면 (8h, 20% deep, 22% REM, efficiency 95%, WASO 5분) → 95+
- 짧은 수면 (5h) → duration 감점
- Deep 부족 → deep 감점
- REM 부족 → REM 감점
- 많은 WASO → WASO 감점
- 경계값 테스트

**Verification**: 유닛 테스트 통과, 기존 테스트도 새 가중치에 맞게 업데이트

### Step 3: Breathing Disturbances Query Service (Data)

**신규 파일**: `BreathingDisturbanceQueryService.swift`

```swift
protocol BreathingDisturbanceQuerying: Sendable {
    func fetchNightlyDisturbances(days: Int) async throws -> [BreathingDisturbanceSample]
    func fetchLatestDisturbance(withinDays: Int) async throws -> BreathingDisturbanceSample?
}

struct BreathingDisturbanceSample: Sendable {
    let value: Double    // count/hour
    let date: Date
    let isElevated: Bool // Apple 기준 elevated 여부
}
```

**HealthKitManager 수정**: readTypes에 `HKQuantityType(.appleSleepingBreathingDisturbances)` 추가

**쿼리 패턴**: `VitalsQueryService`의 기존 패턴(range validation + date sort) 따름
- 유효 범위: 0...100 count/hour
- Elevated 임계값: 시간당 10회 이상 (Apple 의학 기준 근거)

**테스트**: `BreathingDisturbanceQueryServiceTests.swift`
- 정상 범위 값 반환
- 범위 외 값 필터링
- 빈 결과 처리
- Elevated 분류 검증

**Verification**: 유닛 테스트 통과

### Step 4: Breathing Disturbances 모델 + 코칭 (Domain)

**신규 파일**: `BreathingDisturbanceAnalysis.swift`

```swift
struct BreathingDisturbanceAnalysis: Sendable {
    let samples: [BreathingDisturbanceSample]
    let thirtyDayAverage: Double?
    let elevatedNightCount: Int
    let trend: TrendDirection
    let riskLevel: RiskLevel

    enum RiskLevel: String, Sendable {
        case normal       // 평균 < 5/hr
        case mild         // 평균 5-10/hr
        case elevated     // 평균 10-15/hr
        case significant  // 평균 15+/hr
    }
}
```

**CoachingEngine 수정**: elevated 시 인사이트 추가
- `input`에 `breathingDisturbanceRisk: BreathingDisturbanceAnalysis.RiskLevel?` 추가
- elevated/significant → "수면 중 호흡 장애가 잦습니다. 수면 전문의 상담을 권장합니다" 인사이트

**Verification**: 코칭 인사이트 테스트

### Step 5: 수면-운동 상관분석 UseCase (Domain)

**신규 파일**: `SleepExerciseCorrelation.swift`, `CorrelateSleepExerciseUseCase.swift`

```swift
struct SleepExerciseCorrelation: Sendable {
    let dataPointCount: Int
    let confidence: Confidence
    let intensityBreakdown: [IntensityBand: SleepStats]
    let bestActivityTypes: [ActivityTypeStat]
    let overallInsight: String?

    enum Confidence: String, Sendable { case low, medium, high }

    struct IntensityBand: String, Sendable {
        case rest, light, moderate, intense
    }

    struct SleepStats: Sendable {
        let avgScore: Double
        let avgDeepRatio: Double
        let avgEfficiency: Double
        let sampleCount: Int
    }

    struct ActivityTypeStat: Sendable {
        let activityType: String
        let avgSleepScore: Double
        let sampleCount: Int
    }
}
```

**UseCase Input**:
```swift
struct Input: Sendable {
    let sleepScoresByDate: [(date: Date, score: Int, deepRatio: Double, efficiency: Double)]
    let exercisesByDate: [(date: Date, intensity: Double, activityType: String, durationMinutes: Double)]
}
```

**매칭 로직**:
- 각 수면일(sleep date D)에 대해 D-1의 운동 데이터를 매칭
- 운동이 여러 개면 가장 높은 intensity 기준
- 운동 없는 날 = `rest` band

**Confidence**: <14쌍 low, 14-30 medium, 30+ high

**테스트**: `CorrelateSleepExerciseUseCaseTests.swift`
- 14쌍 미만 → low confidence
- 30쌍 → high confidence
- 운동 없는 날 → rest band
- 강도별 분류 정확성

**Verification**: 유닛 테스트 통과

### Step 6: 야간 바이탈 집계 UseCase (Domain)

**신규 파일**: `NocturnalVitalsSnapshot.swift`, `AggregateNocturnalVitalsUseCase.swift`

```swift
struct NocturnalVitalsSnapshot: Sendable {
    let sleepStart: Date
    let sleepEnd: Date
    let heartRateBuckets: [VitalBucket]
    let respiratoryRateBuckets: [VitalBucket]
    let wristTemperatureBuckets: [VitalBucket]
    let spO2Buckets: [VitalBucket]
    let summary: VitalsSummary

    struct VitalBucket: Sendable, Identifiable {
        let id: Date    // bucket start time
        let avg: Double
        let min: Double
        let max: Double
    }

    struct VitalsSummary: Sendable {
        let minHeartRate: Double?
        let avgHeartRate: Double?
        let avgRespiratoryRate: Double?
        let wristTempDeviation: Double?  // baseline 대비 편차
        let avgSpO2: Double?
    }
}
```

**집계 로직**:
- 수면 윈도우(sleepStart~sleepEnd) 기준으로 HR/호흡수/온도/SpO2 데이터 수집
- 5분 단위 bucketing (max ~96 buckets for 8h sleep)
- 각 bucket: avg/min/max 계산
- Summary: 전체 수면 기간의 집계 통계

**Input**: 수면 윈도우 + 각 바이탈의 raw samples
**Output**: `NocturnalVitalsSnapshot`

**테스트**: `AggregateNocturnalVitalsUseCaseTests.swift`
- 정상 8시간 수면 → ~96 buckets
- 빈 HR 데이터 → nil summary
- 혼합 데이터 (HR 있고 SpO2 없음) → partial snapshot
- 경계값: 정확히 5분 간격 데이터

**Verification**: 유닛 테스트 통과

### Step 7: HealthMetric + Extensions (Domain/Presentation)

**수정**: `HealthMetric.swift`에 `.breathingDisturbances` case 추가
**수정**: `HealthMetric+View.swift`에 displayName, icon, color, unit, changeFractionDigits 추가

```swift
case .breathingDisturbances: DS.Color.sleep
// icon: "lungs"
// displayName: "Breathing Disturbances"
// unit: "/hr"
```

**Localization**: `Localizable.xcstrings`에 새 문자열 3개 언어 등록

**Verification**: 빌드 통과, 분류 switch exhaustive

### Step 7.5: SleepViewModel 확장 (Presentation)

**수정**: `SleepViewModel.swift`

추가 프로퍼티:
```swift
var wasoAnalysis: WakeAfterSleepOnset?
var breathingAnalysis: BreathingDisturbanceAnalysis?
var exerciseCorrelation: SleepExerciseCorrelation?
var nocturnalVitals: NocturnalVitalsSnapshot?
```

`loadData()` 확장:
- Phase 1: 기존 수면 데이터 로드 (현재 로직 유지)
- Phase 2 (parallel):
  - WASO 분석
  - Breathing Disturbances 30일 로드
  - 수면-운동 상관분석 (90일 데이터)
  - 야간 바이탈 집계 (오늘 수면 윈도우)

**에러 처리**: 각 추가 기능은 독립적으로 실패 가능 → partial failure 패턴

**Verification**: 빌드 통과

### Step 8: UI 카드 구현 (Presentation)

**WASO 카드** (`WakeAnalysisCard.swift`):
- 각성 횟수, 총 WASO 시간, 최장 각성
- 점수 게이지 (0-100)

**Breathing Disturbance 카드** (`BreathingDisturbanceCard.swift`):
- 30일 추세 bar chart
- 최근 평균, elevated 밤 수
- Risk level 배지

**수면-운동 상관 카드** (`SleepExerciseCorrelationCard.swift`):
- 강도별 평균 수면 점수 bar chart
- "Best activity for sleep" 인사이트

**야간 바이탈 차트** (`NocturnalVitalsChartView.swift`):
- 수면 단계 타임라인 상단
- HR 라인 차트 하단
- 토글로 호흡수/온도/SpO2 전환
- 요약 통계 그리드

**각 카드 공통**:
- Apple Watch 데이터 없으면 graceful empty state
- Localized 문자열 (en/ko/ja)

**Verification**: 빌드 통과

### Step 9: Localization + 최종 통합

**xcstrings 업데이트**: 모든 신규 문자열 en/ko/ja 등록
**xcodegen**: 새 파일 추가 후 프로젝트 재생성

**Verification**: `scripts/build-ios.sh` 통과

## Test Strategy

| UseCase/Service | 테스트 파일 | 주요 케이스 |
|-----------------|------------|------------|
| AnalyzeWASOUseCase | AnalyzeWASOUseCaseTests | 0 awakening, short, long, edge |
| CalculateSleepScoreUseCase (v2) | CalculateSleepScoreUseCaseV2Tests | 5축 가중치, 경계값, 이상적/최악 |
| BreathingDisturbanceQueryService | BreathingDisturbanceQueryServiceTests | 범위, elevated, empty |
| CorrelateSleepExerciseUseCase | CorrelateSleepExerciseUseCaseTests | confidence, bands, empty |
| AggregateNocturnalVitalsUseCase | AggregateNocturnalVitalsUseCaseTests | bucketing, partial, empty |

기존 테스트 파일 업데이트:
- `CalculateSleepScoreUseCaseTests.swift` → 새 가중치 반영

## Edge Cases

1. **Apple Watch 미착용**: Breathing/야간바이탈/상세수면단계 없음 → 해당 카드 숨김
2. **짧은 수면 (<3h)**: WASO 분석은 수행하되 "짧은 수면" 표시
3. **운동 데이터 부족 (<14일)**: 상관분석 confidence=low, "더 많은 데이터 필요" 메시지
4. **Breathing Disturbances 미지원 기기**: Series 9 미만 → 카드 숨김
5. **SpO2 미지원**: Watch SE → SpO2 트랙만 숨김, 나머지 표시
6. **0 division 방어**: 모든 평균/비율 계산에 count>0 guard
7. **NaN/Infinite 방어**: `isFinite` guard 후 fallback

## Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Sleep Score 변경으로 사용자 혼란 | Medium | What's New에서 안내 |
| 야간 HR 데이터 볼륨 (480+ samples) | Low | 5분 bucketing으로 ~96개 축소 |
| Breathing Disturbances API 미제공 가능성 | Low | HealthKit 문서에 명시적으로 존재 |
| 상관분석 통계적 유의성 | Medium | Confidence level 표시로 완화 |

## Dependencies

- 기존 `SleepQueryService` 인터페이스 변경 없음 (WASO는 기존 stages로 분석)
- 기존 `VitalsQueryService` 인터페이스 확장 없음 (야간 바이탈은 기존 collection 메서드 활용)
- 신규 HealthKit 권한: `appleSleepingBreathingDisturbances` 1개만 추가
