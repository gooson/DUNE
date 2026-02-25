---
tags: [condition-score, hrv, z-score, rhr-fallback, parameter-tuning, debugging-ui]
category: general
date: 2026-02-25
severity: critical
related_files:
  - Dailve/Domain/UseCases/CalculateConditionScoreUseCase.swift
  - Dailve/Domain/Models/ConditionScore.swift
  - Dailve/Data/Services/SharedHealthDataServiceImpl.swift
  - Dailve/Presentation/Dashboard/DashboardViewModel.swift
  - Dailve/Presentation/Shared/Components/ConditionCalculationCard.swift
  - Dailve/Presentation/Dashboard/ConditionScoreDetailView.swift
  - Dailve/Presentation/Wellness/WellnessScoreDetailView.swift
related_solutions:
  - performance/2026-02-16-review-triage-division-by-zero-and-nan.md
  - architecture/2026-02-20-wellness-viewmodel-sendable-tuples.md
---

# Solution: Condition Score Always 0 — RHR Fallback Bug + Parameter Tuning

## Problem

### Symptoms

- Condition score가 Wellness 탭에서 항상 0 또는 "--"(nil)으로 표시
- Apple Watch를 밤에 착용하지 않은 날(주간 HRV만 존재) 특히 발생
- 이전 세션에서 `prefix(7)` 버그와 60일 윈도우 문제를 수정했으나 여전히 0

### Root Cause

**3개의 독립적 원인이 동시 작용**:

1. **RHR fallback이 비인접일 비교 유발 (Correction #24 위반)**
   - `SharedHealthDataServiceImpl`과 `DashboardViewModel`에서 `todayRHR ?? latestRHR?.value` 패턴 사용
   - 오늘 RHR이 없으면 3~7일 전 RHR을 "todayRHR"로 전달
   - 어제 RHR과의 차이가 비인접일 데이터끼리 비교되어 -10~-20 거짓 패널티 발생

2. **minimumStdDev(0.05)가 지나치게 작음**
   - 정상적인 20% HRV 일간 변동에도 z-score가 -2 이하로 산출
   - ln-space에서 20% 변동 = ~0.22 → stdDev 0.05 대비 z = -4.4 → score = 0

3. **zScoreMultiplier(25)가 지나치게 가파름**
   - z-score ±2 범위가 전체 0-100 스케일을 커버
   - 주간 전용 HRV(야간 대비 20-40% 낮음)에서 z ≈ -2.5 → score = 50 + (-2.5 × 25) = -12.5 → clamped 0

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `SharedHealthDataServiceImpl.swift` | `todayRHR ?? latestRHR?.value` → `todayRHR` 직접 전달 | 비인접일 RHR 비교 방지 (#24) |
| `DashboardViewModel.swift` | 동일 RHR fallback 제거 + `startOfDay` 정규화 | 양쪽 caller 일관성 |
| `CalculateConditionScoreUseCase.swift` | `minimumStdDev` 0.05→0.25, `zScoreMultiplier` 25→15 | 주간 HRV 패턴에서 합리적 점수 산출 |
| `CalculateConditionScoreUseCase.swift` | `rhrValidRange`, `hrvValidRange` 추가 | 센서 오류 값 필터링 |
| `CalculateConditionScoreUseCase.swift` | `static let conditionWindowDays = 14` | 매직넘버 제거, 단일 소스 |
| `CalculateConditionScoreUseCase.swift` | `baselineHRV` NaN/Inf guard 추가 | `exp()` overflow 방어 |
| `ConditionScore.swift` | `ConditionScoreDetail` struct 추가 | 중간 계산값 UI 노출 |
| `ConditionCalculationCard.swift` | 공유 디버깅 UI 컴포넌트 생성 | Today/Wellness 양쪽에서 재사용 |
| `ConditionScoreDetailView.swift` | `ConditionCalculationCard` 추가 | Today 탭 상세에서 계산 과정 확인 |
| `WellnessScoreDetailView.swift` | inline 코드 → 공유 컴포넌트 교체 | DRY, ~100줄 제거 |

### Key Code

**1. RHR fallback 제거 (SharedHealthDataServiceImpl)**

```swift
// BEFORE: 비인접일 RHR을 "today"로 전달 → 거짓 패널티
let effectiveRHR = todayRHR ?? latestRHR?.value
let input = CalculateConditionScoreUseCase.Input(
    hrvSamples: conditionSamples,
    todayRHR: effectiveRHR,  // 3일 전 데이터일 수 있음!
    yesterdayRHR: yesterdayRHR
)

// AFTER: 실제 오늘 RHR만 전달
let input = CalculateConditionScoreUseCase.Input(
    hrvSamples: conditionSamples,
    todayRHR: todayRHR,       // nil이면 RHR 보정 스킵
    yesterdayRHR: yesterdayRHR
)
```

**2. 파라미터 튜닝 결과**

```
minimumStdDev: 0.05 → 0.10 → 0.20 → 0.25 (최종)
zScoreMultiplier: 25 → 20 → 15 (최종)

Score curve (minimumStdDev=0.25, multiplier=15):
  HRV 변동  | z-score | Raw Score | Clamped
  +40%     |  +1.35  |  70.2     | 70
  +20%     |  +0.73  |  60.9     | 61
   0%      |   0.00  |  50.0     | 50
  -20%     |  -0.89  |  36.6     | 37
  -40%     |  -2.04  |  19.4     | 19
  -60%     |  -3.66  |   0.0     |  0
```

**3. ConditionScoreDetail (디버깅 UI)**

```swift
struct ConditionScoreDetail: Sendable, Hashable {
    let todayHRV: Double       // 오늘 평균 HRV (ms)
    let baselineHRV: Double    // 기준선 HRV (ms, exp of ln mean)
    let zScore: Double         // 표준화 점수
    let stdDev: Double         // 실제 표준편차 (ln)
    let effectiveStdDev: Double // max(stdDev, minimumStdDev)
    let daysInBaseline: Int    // 기준선 데이터 일수
    let todayDate: Date        // 비교 기준일
    let rawScore: Double       // 클램핑 전 원점수
    let rhrPenalty: Double     // RHR 패널티 (있으면)
}
```

## Prevention

### Checklist Addition

- [ ] RHR 데이터를 "today"로 전달할 때 실제 오늘 데이터인지 확인 (historical fallback 금지)
- [ ] 통계 알고리즘의 파라미터(stdDev, multiplier)가 실제 사용자 데이터 패턴에서 합리적 범위를 산출하는지 검증
- [ ] 점수 알고리즘에 중간 계산값 UI를 기본 포함하여 디버깅 가능하게 설계
- [ ] HealthKit 입력값에 생리학적 범위 검증 적용 (HR 20-300, HRV 0-500)

### Rule Addition

기존 규칙으로 충분:
- Correction #24: historical fallback 시 change 계산 스킵
- Correction #22: HealthKit 값 범위 검증 필수
- `input-validation.md`: 수학 함수 방어 (NaN, Inf)

### CLAUDE.md Correction Addition

```
### 2026-02-25: Condition Score 0점 수정 교정

112. **RHR fallback을 condition input의 "today" 파라미터로 전달 금지**: `todayRHR ?? latestRHR?.value` 패턴은 비인접일 비교를 유발하여 거짓 패널티 발생. `todayRHR`이 nil이면 RHR 보정을 스킵하는 것이 올바른 동작
113. **z-score 기반 점수 알고리즘에 ConditionScoreDetail 패턴 적용**: 중간 계산값(todayHRV, baselineHRV, zScore, stdDev, rawScore)을 Domain 모델에 포함하여 UI에서 디버깅 가능하게. 점수가 비정상일 때 원인 추적 가능
114. **통계 파라미터(minimumStdDev, zScoreMultiplier) 변경 시 실데이터 시나리오 검증**: 야간 미착용(주간 전용 HRV), 운동 직후, 컨디션 저하 등 3개 이상 시나리오에서 산출 점수가 0-100 범위 내 합리적 분포인지 확인
```

## Lessons Learned

1. **Fallback 데이터의 semantic 변질**: `todayRHR ?? latestRHR?.value`는 코드상 자연스러워 보이지만, 수신 측이 "today" 파라미터로 해석하면 비인접일 비교가 발생. Fallback은 caller가 아닌 수신 함수 내부에서 명시적으로 처리해야 함

2. **파라미터 튜닝은 반복적**: `minimumStdDev`를 0.05→0.10→0.20→0.25로 4번 조정. 초기값 설정 시 실제 데이터 분포를 고려하지 않으면 여러 라운드의 조정이 필요

3. **디버깅 UI는 선제적으로 구축**: 점수가 0인 원인을 파악하기 위해 `ConditionScoreDetail`을 만들어야 했음. 점수 알고리즘 최초 구현 시부터 중간값 노출 UI를 함께 만들었다면 디버깅 시간 대폭 단축

4. **주간 전용 HRV는 야간 대비 20-40% 낮음**: Apple Watch를 밤에 착용하지 않는 사용자의 HRV 기준선은 야간 착용 사용자와 크게 다름. 알고리즘이 이 패턴을 "정상 범위"로 수용해야 0점이 아닌 합리적 점수 산출
