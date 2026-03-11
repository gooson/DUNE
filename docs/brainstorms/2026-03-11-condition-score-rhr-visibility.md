---
tags: [condition-score, rhr, ui, dashboard]
date: 2026-03-11
category: brainstorm
status: draft
---

# Brainstorm: Condition Score RHR UI 가시성

## Problem Statement

Condition Score 계산에 RHR이 사용되고 있지만, UI에서 RHR 값이 표시되지 않음.
`ConditionScoreDetail` 모델이 `rhrPenalty`(숫자)만 저장하고 실제 RHR 값(`todayRHR`, `yesterdayRHR`)을 버림.
사용자 입장에서 "RHR이 계산에서 빠졌다"고 느끼는 원인.

## Root Cause

```
DashboardViewModel → todayRHR, yesterdayRHR 전달 ✅
CalculateConditionScoreUseCase → rhrPenalty 계산 ✅
ConditionScoreDetail 모델 → rhrPenalty만 저장 ❌ (todayRHR/yesterdayRHR 없음)
ConditionCalculationCard → "RHR Penalty" 숫자만 표시 ❌
```

## 현재 공식 (유지)

- Base: 50점
- HRV z-score: `(ln(todayHRV) - ln(baseline)) / stdDev × 15.0`
- RHR 보정:
  - RHR↑ > +2bpm AND HRV↓ → `rhrChange × 2.0` 감점
  - RHR↓ < -2bpm AND HRV↑ → `abs(rhrChange)` 가점
- Final: clamp(0...100)

## 영향받는 파일

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Domain/Models/ConditionScore.swift` | `ConditionScoreDetail`에 `todayRHR: Double?`, `yesterdayRHR: Double?` 추가 |
| `DUNE/Domain/UseCases/CalculateConditionScoreUseCase.swift` | detail 생성 시 RHR 값 전달 |
| `DUNE/Presentation/Shared/Components/ConditionCalculationCard.swift` | RHR 값 표시 행 추가 |
| `DUNETests/CalculateConditionScoreUseCaseTests.swift` | detail 필드 검증 추가 |

## Scope

### MVP (Must-have)
- ConditionScoreDetail에 todayRHR/yesterdayRHR 필드 추가
- UseCase에서 값 전달
- ConditionCalculationCard에 "RHR" 행 표시 (예: "72 → 78 bpm (+6)")
- RHR 없을 때 "—" 표시

### Nice-to-have (Future)
- RHR 트렌드 차트 (7일/14일)
- RHR baseline 표시
- RHR이 패널티에 기여한 정도 시각화

## Next Steps

- [ ] `/plan condition-score-rhr-visibility` 로 구현 계획 생성
