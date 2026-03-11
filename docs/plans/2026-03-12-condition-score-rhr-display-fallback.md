---
tags: [condition-score, rhr, ui, healthkit, fallback]
date: 2026-03-12
category: plan
status: draft
---

# Condition Score RHR 표시 fallback

## Problem

`ConditionCalculationCard`에서 RHR 행이 보이지 않는 문제. 원인:
- `fetchRestingHeartRate(for: today)`가 이른 시간(자정 직후 등)에 nil 반환
- Apple이 아직 오늘의 RHR을 계산하지 않은 시점
- `ConditionScoreDetail.todayRHR = nil` → UI에서 RHR 행 전체 숨김

DashboardViewModel은 이미 `latestRHR` fallback을 사용해 메트릭 목록에 RHR을 표시하지만, `ConditionScoreDetail`에는 이 값이 전달되지 않음.

## Solution

### 핵심 원칙

- **Penalty 계산**: 변경 없음. 실제 today/yesterday RHR만 사용 (Correction #24 준수)
- **UI 표시**: `latestRHR` fallback을 `ConditionScoreDetail`에 전달하여 사용자에게 항상 RHR 정보 표시
- historical 값임을 UI에서 명시 (날짜 표시)

### Affected Files

| File | Change |
|------|--------|
| `DUNE/Domain/Models/ConditionScore.swift` | `ConditionScoreDetail`에 `displayRHR: Double?`, `displayRHRDate: Date?` 추가 |
| `DUNE/Domain/UseCases/CalculateConditionScoreUseCase.swift` | Input에 `displayRHR`, `displayRHRDate` 추가, Detail 생성 시 전달 |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | UseCase Input에 `effectiveRHR` 값 전달 |
| `DUNE/Data/Services/SharedHealthDataServiceImpl.swift` | UseCase Input에 latestRHR fallback 전달 |
| `DUNE/Presentation/Shared/Components/ConditionCalculationCard.swift` | `displayRHR`/`displayRHRDate` 사용하여 RHR 행 표시 |
| `DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift` | 변경 없음 (chart에서는 RHR 미사용) |

### Implementation Steps

#### Step 1: Domain Model 확장

`ConditionScoreDetail`에 display 전용 필드 추가:
```swift
/// Effective RHR for display (may be from a recent day, not necessarily today)
let displayRHR: Double?
/// Date of the displayRHR value (nil if displayRHR is nil)
let displayRHRDate: Date?
```

#### Step 2: UseCase Input/Output 확장

`CalculateConditionScoreUseCase.Input`에 display 필드 추가:
```swift
let displayRHR: Double?
let displayRHRDate: Date?
```

기본값 nil로 설정하여 기존 call site가 깨지지 않음.

UseCase가 `ConditionScoreDetail` 생성 시 이 값을 그대로 전달.

#### Step 3: DashboardViewModel 전달

이미 계산된 `effectiveRHR`/`rhrDate`를 UseCase Input에 전달:
```swift
let input = CalculateConditionScoreUseCase.Input(
    hrvSamples: conditionSamples,
    todayRHR: todayRHR,
    yesterdayRHR: yesterdayRHR,
    displayRHR: effectiveRHR,
    displayRHRDate: effectiveRHR != nil ? rhrDate : nil
)
```

#### Step 4: SharedHealthDataServiceImpl 전달

`computeCondition`에 latestRHR 정보를 전달하여 동일 패턴 적용.

#### Step 5: ConditionCalculationCard UI 수정

`displayRHR` 우선, fallback으로 기존 `todayRHR` 사용:
- `displayRHR`이 있으면 RHR 행 표시
- `displayRHRDate`가 today가 아니면 날짜 표시 (예: "62 bpm (3/10)")
- `displayRHR`도 nil이면 기존대로 행 숨김

### Test Strategy

- `CalculateConditionScoreUseCaseTests`: displayRHR/displayRHRDate가 detail에 전달되는지 검증
- 시나리오: todayRHR=nil + displayRHR 있음 → detail.displayRHR 존재
- 시나리오: todayRHR 있음 + displayRHR 있음 → 둘 다 존재

### Risks / Edge Cases

- displayRHR이 7일 전 값일 수 있음 → 날짜 표시로 사용자에게 명시
- penalty 계산에 displayRHR이 사용되지 않아야 함 → UseCase 내부에서 명확히 분리
- 기존 call site (ConditionScoreDetailViewModel.computeDailyScores)는 displayRHR=nil로 호출 → 차트에는 영향 없음

### Related Docs

- `docs/solutions/general/2026-03-11-condition-score-rhr-visibility.md`
- `docs/solutions/general/2026-02-25-condition-score-zero-fix.md` (Correction #24)
