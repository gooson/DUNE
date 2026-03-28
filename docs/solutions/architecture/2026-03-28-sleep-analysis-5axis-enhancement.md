---
tags: [sleep, waso, rem, breathing-disturbances, nocturnal-vitals, exercise-correlation, score-redesign, healthkit]
date: 2026-03-28
category: solution
status: implemented
related_files:
  - DUNE/Domain/UseCases/CalculateSleepScoreUseCase.swift
  - DUNE/Domain/UseCases/AnalyzeWASOUseCase.swift
  - DUNE/Domain/UseCases/CorrelateSleepExerciseUseCase.swift
  - DUNE/Domain/UseCases/AggregateNocturnalVitalsUseCase.swift
  - DUNE/Data/HealthKit/BreathingDisturbanceQueryService.swift
  - DUNE/Presentation/Sleep/SleepViewModel.swift
---

# Solution: 수면 분석 5축 고도화 + 야간 바이탈 통합

## Problem

기존 Sleep Score는 Duration(40%) + Deep Sleep(30%) + Efficiency(30%)의 3축 모델로,
REM 수면 비율과 중간 각성(WASO)을 반영하지 못했다.
또한 Apple Watch가 수집하는 Breathing Disturbances, 야간 심박수/호흡수/온도 데이터를
수면 분석에 활용하지 못하고 있었다.

## Solution

### 1. Sleep Score 5축 재설계

| 컴포넌트 | 이전 | 이후 | 근거 |
|----------|------|------|------|
| Duration | 40pt | 30pt | REM/WASO에 가중치 배분 |
| Deep Sleep | 30pt | 20pt | penalty rate 150→100 |
| REM Sleep | — | 15pt | 이상 20-25%, center 0.225 |
| Efficiency | 30pt | 20pt | WASO와 분리 세분화 |
| WASO | — | 15pt | 5분+ 각성만 집계 |

**핵심 결정**: WASO UseCase를 별도로 분리하여 Score와 독립적인 상세 분석 제공.
Score에서는 WASO.score를 15pt 스케일로 매핑.

### 2. WASO 분석

- 수면 개시(첫 non-awake) ~ 최종 기상(마지막 non-awake end) 사이의 5분+ 각성만 집계
- 점수: 0-10분=100, 10-30분=선형 감소(100→50), 30-60분=선형 감소(50→20), 60분+=20

### 3. Breathing Disturbances

- `HKQuantityType(.appleSleepingBreathingDisturbances)` 읽기
- 단위: count/hour, 유효 범위 0-100
- Elevated 임계값: 10회/시간
- 4단계 Risk Level: normal(<5)/mild(5-10)/elevated(10-15)/significant(15+)

### 4. 수면-운동 상관분석

- 각 밤의 수면(D)과 전날(D-1)의 운동을 매칭
- 4개 강도 band: rest/light(0.01-0.39)/moderate(0.40-0.69)/intense(0.70+)
- Confidence: <14쌍=low, 14-30=medium, 30+=high

### 5. 야간 바이탈 집계

- 수면 윈도우 내 HR/호흡수/온도/SpO2를 5분 bucket으로 집계
- 각 bucket: avg/min/max
- Summary: minHR, avgHR, avgRR, wristTempDeviation(baseline 대비), avgSpO2

### 6. UI 통합 패턴 (PR #643)

**카드 배치**: `MetricDetailView`의 sleep 섹션에 조건부 렌더링:
- `SleepDeficitGaugeView` 뒤에 WASO → Breathing → Correlation → Nocturnal Vitals 순서 배치
- 각 카드는 데이터 nil/empty 시 자동 숨김

**데이터 로딩**: `MetricDetailViewModel.loadSleepInsightCards()` → `loadSleepEnhancedInsights()` 체인
- 3개 독립 작업 병렬 실행: `async let (wasoTask, breathingTask, correlationTask)`
- 수면-운동 상관: `sleepScoreUseCase`로 일관된 점수 계산 (인라인 공식 금지)
- 야간 바이탈: 전체 수면 세션 윈도우 사용 (awake bookend 포함)

**Localization**: 21개 신규 문자열 en/ko/ja 등록 (`Shared/Resources/Localizable.xcstrings`)

## Prevention

1. **Score 가중치 변경 시**: 합이 100인지 검증 + 기존 테스트 업데이트 + What's New 안내
2. **HealthKit 새 타입 추가 시**: readTypes에 추가 + 쿼리 서비스 생성 + 유효 범위 정의
3. **ViewModel에 미연결 프로퍼티 추가 금지**: 데이터 로딩 코드 없이 프로퍼티만 선언하면 dead code
4. **Localized 문자열에 .lowercased() 사용 금지**: 한국어/일본어에서 의미 없음

## Lessons Learned

- Swift 6의 `@MainActor` 클래스에서 `withTaskGroup { group.addTask { @MainActor in ... } }` 패턴은
  region-based isolation checker 에러를 유발 → 단순 순차 호출로 변경 (corrections-active.md 참조)
- `HealthMetric.Category` 추가 시 10+ 파일의 exhaustive switch 수정 필요 (corrections-active.md #94)
- `HealthKitManaging` 프로토콜은 최소한의 인터페이스만 노출 — 쿼리 서비스는 `HealthKitManager` 구체 타입 직접 사용
- 상관분석에서 인라인 score/efficiency 공식은 tautology bug를 유발 — 항상 기존 UseCase를 통해 계산
- 독립적인 HealthKit 쿼리들은 `async let` 병렬화 필수 — 순차 실행 시 UI 로딩 지연
