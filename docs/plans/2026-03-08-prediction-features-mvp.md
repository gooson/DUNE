---
tags: [prediction, injury-risk, sleep-quality, workout-report, foundation-models, mvp]
date: 2026-03-08
category: plan
status: draft
---

# Plan: 예측 기능 MVP (부상 위험 · 수면 품질 · 운동 요약)

## 배경

`docs/brainstorms/2026-03-08-apple-on-device-ml-sdk-research.md`에서 분석한 Apple ML SDK 기능 중
MVP로 선정된 3개 기능을 구현합니다.

- **부상 위험 예측도**: 기존 fatigue/injury 데이터를 결합한 rule-based risk score
- **수면 품질 예측**: 당일 활동 데이터 기반 오늘 밤 수면 품질 예측
- **운동 요약 리포트**: 주간 운동 데이터 집계 + Foundation Models 자연어 요약

## 설계 원칙

1. MVP는 **rule-based 점수 모델** (부상/수면) + **Foundation Models 텍스트 생성** (리포트)
2. Domain 레이어에 `SwiftUI`/`FoundationModels` import 금지 — 텍스트 생성은 Data adapter
3. 기존 UseCase 패턴 준수 (Protocol + Input/Output struct + Sendable)
4. 미지원 디바이스 fallback 필수 (Foundation Models: A17 Pro+ only)
5. 기존 CoachingEngine/FatigueCalculation 데이터를 최대한 재사용

## Affected Files

### 신규 생성

| 파일 | 레이어 | 설명 |
|------|--------|------|
| `Domain/Models/InjuryRiskAssessment.swift` | Domain | 부상 위험 점수 모델 |
| `Domain/UseCases/CalculateInjuryRiskUseCase.swift` | Domain | 부상 위험 계산 로직 |
| `Domain/Models/SleepQualityPrediction.swift` | Domain | 수면 품질 예측 모델 |
| `Domain/UseCases/PredictSleepQualityUseCase.swift` | Domain | 수면 품질 예측 로직 |
| `Domain/Models/WorkoutReport.swift` | Domain | 운동 요약 리포트 데이터 모델 |
| `Domain/UseCases/GenerateWorkoutReportUseCase.swift` | Domain | 리포트 데이터 집계 |
| `Domain/Protocols/WorkoutReportFormatting.swift` | Domain | 텍스트 생성 프로토콜 |
| `Data/Services/FoundationModelReportFormatter.swift` | Data | Foundation Models 텍스트 생성 |
| `Data/Services/TemplateReportFormatter.swift` | Data | Template 기반 fallback |
| `Presentation/Activity/InjuryRisk/InjuryRiskCardView.swift` | Presentation | 부상 위험 카드 UI |
| `Presentation/Wellness/SleepPrediction/SleepPredictionCardView.swift` | Presentation | 수면 예측 카드 UI |
| `Presentation/Activity/WorkoutReport/WorkoutReportView.swift` | Presentation | 운동 리포트 화면 |
| `Presentation/Activity/WorkoutReport/WorkoutReportViewModel.swift` | Presentation | 운동 리포트 VM |
| `DUNETests/CalculateInjuryRiskUseCaseTests.swift` | Tests | 부상 위험 UseCase 테스트 |
| `DUNETests/PredictSleepQualityUseCaseTests.swift` | Tests | 수면 예측 UseCase 테스트 |
| `DUNETests/GenerateWorkoutReportUseCaseTests.swift` | Tests | 리포트 집계 테스트 |

### 기존 수정

| 파일 | 변경 내용 |
|------|----------|
| `Presentation/Activity/ActivityView.swift` | InjuryRiskCard + WorkoutReport 진입점 추가 |
| `Presentation/Activity/ActivityViewModel.swift` | injuryRisk/workoutReport 데이터 로드 |
| `Presentation/Wellness/WellnessView.swift` | SleepPredictionCard 추가 |
| `Presentation/Wellness/WellnessViewModel.swift` | sleepPrediction 데이터 로드 |
| `Shared/Resources/Localizable.xcstrings` | 새 문자열 en/ko/ja 번역 |
| `DUNE/project.yml` | 새 파일 등록 (xcodegen 자동) |

## Implementation Steps

### Step 1: 부상 위험 예측 모델 + UseCase

**목표**: 근육 피로, 연속 훈련일, 볼륨 증가율, 수면 부족, 부상 이력을 결합한 0-100 risk score

**InjuryRiskAssessment 모델**:
```swift
struct InjuryRiskAssessment: Sendable, Hashable {
    let score: Int           // 0-100 (높을수록 위험)
    let level: Level         // low/moderate/high/critical
    let factors: [RiskFactor]
    let date: Date

    enum Level: String, Sendable, CaseIterable {
        case low, moderate, high, critical
    }

    struct RiskFactor: Sendable, Hashable {
        let type: FactorType
        let contribution: Int  // 0-100 가중 기여도
        let detail: String
    }

    enum FactorType: String, Sendable {
        case muscleFatigue
        case consecutiveTraining
        case volumeSpike
        case sleepDeficit
        case activeInjury
        case lowRecovery
    }
}
```

**CalculateInjuryRiskUseCase**:
- Input: fatigueStates, consecutiveTrainingDays, weeklyVolume (this/last), sleepDeficitMinutes, activeInjuries, conditionScore
- 가중치: muscleFatigue(25%) + consecutiveTraining(20%) + volumeSpike(20%) + sleepDeficit(15%) + activeInjury(10%) + lowRecovery(10%)
- Level: 0-25 low, 26-50 moderate, 51-75 high, 76-100 critical

**Verification**: 테스트에서 경계값 검증 (0, 25, 50, 75, 100)

### Step 2: 수면 품질 예측 모델 + UseCase

**목표**: 오늘의 활동/생체 데이터로 오늘 밤 예상 수면 품질을 예측

**SleepQualityPrediction 모델**:
```swift
struct SleepQualityPrediction: Sendable, Hashable {
    let predictedScore: Int       // 0-100
    let confidence: Confidence    // low/medium/high
    let outlook: Outlook          // poor/fair/good/excellent
    let factors: [PredictionFactor]
    let tips: [String]            // 개선 팁 (localized)

    enum Confidence: String, Sendable { case low, medium, high }
    enum Outlook: String, Sendable, CaseIterable {
        case poor, fair, good, excellent
    }
}
```

**PredictSleepQualityUseCase**:
- Input: todayWorkoutIntensity (0-1), conditionScore, hrvTrend, recentSleepScores (7일), bedtimeConsistencyMinutes, daysSinceLastIntenseWorkout
- 공식:
  - 최근 7일 수면 평균 기반 baseline (40%)
  - 당일 운동 강도 영향 (20%) — 적정 운동은 +, 과도/무운동은 -
  - HRV 트렌드 (15%) — 상승 = +
  - 수면 일관성 (15%) — 취침 시간 편차 작을수록 +
  - Condition score (10%)
- Confidence: 데이터 가용성에 따라 (7일 미만 = low, 7-14일 = medium, 14일+ = high)

**Verification**: 경계값 + 데이터 부족 시 graceful degradation 테스트

### Step 3: 운동 요약 리포트 데이터 집계

**목표**: 주간 운동 데이터를 구조화된 모델로 집계

**WorkoutReport 모델**:
```swift
struct WorkoutReport: Sendable {
    let period: Period
    let startDate: Date
    let endDate: Date
    let stats: Stats
    let muscleBreakdown: [MuscleGroupStat]
    let highlights: [Highlight]
    let formattedSummary: String?  // Foundation Models 생성 텍스트

    enum Period: String, Sendable { case weekly, monthly }

    struct Stats: Sendable {
        let totalSessions: Int
        let totalVolume: Double     // kg
        let totalDuration: Int      // minutes
        let activeDays: Int
        let averageIntensity: Double
    }

    struct MuscleGroupStat: Sendable {
        let muscleGroup: MuscleGroup
        let volume: Double
        let sessions: Int
    }

    struct Highlight: Sendable {
        let type: HighlightType
        let description: String
    }

    enum HighlightType: String, Sendable {
        case personalRecord, streak, volumeIncrease, consistency, newExercise
    }
}
```

**GenerateWorkoutReportUseCase**:
- Input: exerciseRecords (기간 내), personalRecords, workoutStreak, previousPeriodStats
- 주간/월간 집계 → `WorkoutReport.Stats` + `MuscleGroupStat` + `Highlight` 계산
- 텍스트 생성은 `WorkoutReportFormatting` 프로토콜에 위임

**Verification**: 빈 데이터, 단일 운동, 다양한 운동 시나리오 테스트

### Step 4: Foundation Models 텍스트 생성 어댑터

**목표**: 운동 요약을 자연어로 포맷팅 (지원 디바이스 전용)

**WorkoutReportFormatting 프로토콜** (Domain):
```swift
protocol WorkoutReportFormatting: Sendable {
    func format(report: WorkoutReport) async -> String
}
```

**FoundationModelReportFormatter** (Data):
- `import FoundationModels` + `@Generable` 활용
- 프롬프트: 운동 통계 → 2-3문장 자연어 요약 생성
- 디바이스 지원 여부 확인: `LanguageModelSession.isSupported`

**TemplateReportFormatter** (Data):
- Template 기반 fallback: "이번 주 {N}일 운동, 총 {V}kg 볼륨..."
- Foundation Models 미지원 시 자동 사용

**Verification**: 지원/미지원 디바이스 분기 테스트

### Step 5: UI 통합 — InjuryRisk 카드

**목표**: Activity 탭에 부상 위험 카드 표시

- `InjuryRiskCardView`: 원형 게이지 + level 텍스트 + 주요 risk factor 표시
- `ActivityViewModel`에 `injuryRiskAssessment: InjuryRiskAssessment?` 추가
- `ActivityView`에 카드 배치 (TrainingReadiness 아래)

### Step 6: UI 통합 — SleepPrediction 카드

**목표**: Wellness 탭에 수면 예측 카드 표시

- `SleepPredictionCardView`: 예상 점수 + outlook + 개선 팁 표시
- `WellnessViewModel`에 `sleepPrediction: SleepQualityPrediction?` 추가
- Wellness 탭의 수면 섹션에 카드 배치

### Step 7: UI 통합 — WorkoutReport 화면

**목표**: Activity 탭에서 주간 리포트 진입 + 상세 화면

- `WorkoutReportView`: 주간 요약 텍스트 + 통계 그리드 + 근육 비중 차트 + 하이라이트
- `WorkoutReportViewModel`: 데이터 로드 + Foundation Models 텍스트 생성
- Activity 탭에 "주간 리포트" 섹션/버튼 추가

### Step 8: Localization

- 새 UI 문자열 en/ko/ja 3개 언어 번역 등록
- `Localizable.xcstrings` 업데이트
- enum displayName에 `String(localized:)` 패턴 적용

## 테스트 전략

| 테스트 대상 | 파일 | 주요 케이스 |
|-------------|------|------------|
| InjuryRisk UseCase | `CalculateInjuryRiskUseCaseTests.swift` | 각 factor 개별 기여, 경계값 (0/25/50/75/100), 데이터 없을 때 |
| SleepPrediction UseCase | `PredictSleepQualityUseCaseTests.swift` | 데이터 부족 시 confidence, 경계값, 운동 강도별 영향 |
| WorkoutReport UseCase | `GenerateWorkoutReportUseCaseTests.swift` | 빈 기간, 단일 운동, 복합 운동, highlight 감지 |
| TemplateFormatter | `TemplateReportFormatterTests.swift` | 포맷 정확성, 빈 데이터 |

테스트 면제: SwiftUI View body, Foundation Models 실제 호출 (시뮬레이터 제한)

## 리스크 & Edge Cases

| 리스크 | 완화 |
|--------|------|
| Foundation Models 미지원 디바이스 | TemplateReportFormatter fallback |
| HealthKit 데이터 부족 (신규 사용자) | Confidence=low 표시 + 최소 데이터 필요 안내 |
| 부상 위험 오탐 (높은 위험 → 불필요한 불안) | 보수적 임계값 + "참고용" 면책 표시 |
| Foundation Models API 변경 (iOS 26 beta) | 프로토콜 추상화로 격리 |
| 수면 예측 정확도 한계 | Confidence level로 투명하게 표시 |

## 대안 비교

| 접근법 | 선택 이유 |
|--------|----------|
| Rule-based vs Core ML (부상/수면) | MVP 속도 + 라벨 데이터 불필요 + 향후 ML 전환 가능 |
| Foundation Models vs GPT API (리포트) | 온디바이스 프라이버시 + 무료 + Apple 생태계 일관성 |
| 통합 점수 vs 개별 factor 표시 | 개별 factor가 사용자 actionable insight 제공 |

## 구현 순서

1. Step 1-3: Domain 모델 + UseCase (순수 로직, 테스트 우선)
2. Step 4: Foundation Models 어댑터 (디바이스 분기)
3. Step 5-7: UI 통합 (기존 탭에 카드/화면 추가)
4. Step 8: Localization
