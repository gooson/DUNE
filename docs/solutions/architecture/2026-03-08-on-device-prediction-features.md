---
tags: [prediction, foundation-models, on-device-ml, injury-risk, sleep-quality, workout-report]
date: 2026-03-08
category: solution
status: implemented
---

# On-Device Prediction Features 아키텍처

## Problem

HealthKit 데이터(수면, HRV, RHR, 운동기록)를 활용한 예측 기능 3가지를 추가해야 했다:
1. 부상 위험도 평가 (Injury Risk Assessment)
2. 수면 품질 예측 (Sleep Quality Prediction)
3. 주간 운동 리포트 (Weekly Workout Report) — Apple Foundation Models 요약 포함

## Solution

### 레이어 구조

```
Domain (Models + UseCases)
├── InjuryRiskAssessment + CalculateInjuryRiskUseCase
├── SleepQualityPrediction + PredictSleepQualityUseCase
└── WorkoutReport + GenerateWorkoutReportUseCase
         ↓ (WorkoutReportFormatting protocol)
Data (Services)
├── FoundationModelReportFormatter (Apple Foundation Models)
└── TemplateReportFormatter (fallback)

Presentation (Cards + ViewModel integration)
├── InjuryRiskCard → ActivityViewModel
├── SleepPredictionCard → WellnessViewModel
└── WorkoutReportCard → ActivityViewModel
```

### 핵심 설계 결정

1. **UseCase 패턴**: `protocol XxxCalculating: Sendable` + `struct XxxUseCase`. Input struct로 의존성 역전.
2. **Formatter 프로토콜**: `WorkoutReportFormatting`으로 Foundation Models ↔ Template 전략 교체. Domain은 Data 구현 모름.
3. **Two-phase report 생성**: 보고서 데이터 먼저 구성 → formatter에 전달 → 최종 보고서 반환. `formattedSummary`가 Optional인 이유.
4. **Cancel-before-spawn**: `weeklyReportTask?.cancel()` 후 새 Task. Foundation Models 추론이 느릴 수 있으므로 필수.

### Foundation Models 통합

```swift
// A17 Pro+ 디바이스에서만 동작
guard FoundationModels.isAvailable() else { return templateFallback() }
let session = LanguageModelSession()
let response = try await session.respond(to: prompt)
```

- **availability 체크**: `FoundationModels.isAvailable()` (하드웨어 + OS 버전)
- **fallback**: Template 기반 요약 문자열
- **프롬프트**: 보고서 통계를 요약하는 짧은 시스템 프롬프트

### Injury Risk 가중치 (총합 = 1.0)

| 요소 | 가중치 | 근거 |
|------|--------|------|
| Muscle Fatigue | 0.25 | 과도 사용 직접 지표 |
| Consecutive Days | 0.20 | 회복 없는 연속 훈련 |
| Volume Spike | 0.20 | 급격한 볼륨 증가 |
| Sleep Deficit | 0.15 | 회복 품질 |
| Active Injury | 0.10 | 기존 부상 악화 위험 |
| Low Recovery | 0.10 | 컨디션 점수 기반 |

### Sleep Quality 예측 가중치

| 요소 | 가중치 |
|------|--------|
| Recent Sleep Average | 0.40 |
| Workout Effect | 0.20 |
| HRV Trend | 0.15 |
| Bedtime Consistency | 0.15 |
| Condition Score | 0.10 |

## Prevention

### 리뷰에서 발견된 주요 문제

1. **Service 재할당 방지**: `TrendAnalysisService`를 메서드 내 지역변수로 매번 생성하면 불필요한 allocation. Stored dependency로 주입.
2. **중복 O(N) 스캔 방지**: 같은 데이터를 여러 메서드에서 반복 필터하면 shared helper (`partitionSnapshotsByWeek()`) 추출.
3. **isFinite guard 필수**: volume 합산 시 `NaN`/`Infinity` 방어. `.filter(\.isFinite)`.
4. **volumeChangePercent 클램핑**: division 결과가 극단값이 될 수 있으므로 `min(10.0, max(-1.0, raw))`.
5. **Sort-in-body 금지**: `factors.sorted()` 같은 정렬은 UseCase에서 사전 수행. View body에서 정렬하면 매 렌더마다 O(N log N).
6. **LocalizedStringKey vs String**: View helper의 label 파라미터는 `LocalizedStringKey` 사용. `String`으로 받으면 localization leak.

## 관련 파일

- `Domain/Models/InjuryRiskAssessment.swift`
- `Domain/Models/SleepQualityPrediction.swift`
- `Domain/Models/WorkoutReport.swift`
- `Domain/UseCases/Calculate*.swift`, `Predict*.swift`, `Generate*.swift`
- `Data/Services/FoundationModelReportFormatter.swift`
- `Presentation/Activity/Components/InjuryRiskCard.swift`, `WorkoutReportCard.swift`
- `Presentation/Wellness/Components/SleepPredictionCard.swift`
