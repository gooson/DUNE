---
tags: [condition-score, rhr, ui, domain-model]
date: 2026-03-11
category: general
status: implemented
---

# Condition Score RHR UI 가시성 복원

## Problem

`ConditionScoreDetail` 모델이 `rhrPenalty` 숫자만 저장하고 실제 RHR 값(`todayRHR`, `yesterdayRHR`)을 버려서, `ConditionCalculationCard`에서 RHR 값을 표시할 수 없었음. 사용자 관점에서 "RHR이 계산에서 빠졌다"고 오해할 수 있는 상황.

## Root Cause

`CalculateConditionScoreUseCase`는 `todayRHR`/`yesterdayRHR`를 입력으로 받아 `rhrPenalty`를 계산하지만, 계산 후 원본 값을 `ConditionScoreDetail`에 저장하지 않았음. UI는 penalty 숫자만 표시 가능.

## Solution

### 1. Domain Model 확장 (`ConditionScore.swift`)

`ConditionScoreDetail`에 두 필드 추가:
```swift
let todayRHR: Double?
let yesterdayRHR: Double?
```

### 2. UseCase 전달 (`CalculateConditionScoreUseCase.swift`)

`ConditionScoreDetail` 생성 시 입력값 그대로 전달:
```swift
todayRHR: input.todayRHR,
yesterdayRHR: input.yesterdayRHR
```

### 3. UI 표시 (`ConditionCalculationCard.swift`)

init에서 pre-compute 후 조건부 표시:
- RHR 데이터 있음: "65 → 72 bpm (+7)" 형식
- 어제 데이터 없음: "72 bpm" + "no comparison"
- RHR 데이터 없음: 행 자체 숨김

### 4. Divider 로직

`showRHRDivider` bool로 분리:
- `hasRHRData == true` → divider 표시
- `hasRHRData == false && rhrPenalty > 0` → divider 표시
- 둘 다 아님 → divider 숨김 (double-divider 방지)

## Prevention

- Domain 모델에서 계산 입력값을 버리지 말고 항상 저장할 것 — UI에서 필요할 수 있음
- `BodyScoreDetail` 등 유사 패턴에서도 동일 원칙 적용
- pre-compute 패턴(Correction #80) 준수: body에서 함수 호출 금지

## Related

- `docs/solutions/general/2026-02-25-condition-score-zero-fix.md` — RHR fallback 버그
- `docs/solutions/architecture/2026-02-25-body-score-calculation-card.md` — BodyScoreDetail 패턴
