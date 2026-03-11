---
tags: [condition-score, rhr, ui, calculation-card]
date: 2026-03-11
category: plan
status: draft
---

# Plan: Condition Score RHR UI 가시성

## 목표

ConditionCalculationCard에 실제 RHR 값(today/yesterday)을 표시하여 사용자가 RHR 보정이 어떻게 적용되는지 볼 수 있게 한다.

## 영향 파일

| 파일 | 변경 내용 | 위험도 |
|------|----------|--------|
| `DUNE/Domain/Models/ConditionScore.swift` | `ConditionScoreDetail`에 `todayRHR: Double?`, `yesterdayRHR: Double?` 추가 | Low |
| `DUNE/Domain/UseCases/CalculateConditionScoreUseCase.swift` | detail 생성 시 RHR 값 전달 | Low |
| `DUNE/Presentation/Shared/Components/ConditionCalculationCard.swift` | RHR 행 추가 (today/yesterday/change 표시) | Low |
| `DUNETests/CalculateConditionScoreUseCaseTests.swift` | detail의 RHR 필드 검증 | Low |

## 구현 단계

### Step 1: ConditionScoreDetail 모델 확장

`ConditionScoreDetail`에 2개 필드 추가:
```swift
let todayRHR: Double?
let yesterdayRHR: Double?
```

기존 `rhrPenalty`는 유지. Hashable/Sendable 자동 합성이므로 추가 코드 불필요.

**검증**: 빌드 통과

### Step 2: UseCase에서 값 전달

`CalculateConditionScoreUseCase.execute()` 내 detail 생성 시:
```swift
let detail = ConditionScoreDetail(
    ...existing fields...,
    todayRHR: input.todayRHR,
    yesterdayRHR: input.yesterdayRHR
)
```

**검증**: 빌드 통과, 기존 테스트 통과

### Step 3: ConditionCalculationCard UI 수정

RHR 행 추가:
- RHR 데이터가 있을 때: "RHR" → "72 → 78 bpm" + "(+6)" sub
- RHR penalty가 있을 때: "RHR Penalty" 행은 기존대로 유지
- RHR 데이터가 없을 때: "RHR" → "—"

init에서 pre-compute (Correction #80 준수):
```swift
private let rhrText: String
private let rhrSub: String
```

**검증**: Simulator preview

### Step 4: 테스트 업데이트

`CalculateConditionScoreUseCaseTests`에서:
- 기존 RHR 테스트에 `detail.todayRHR`, `detail.yesterdayRHR` 검증 추가
- RHR nil 케이스에서 detail 필드도 nil 확인

**검증**: 테스트 통과

## 테스트 전략

- 기존 `CalculateConditionScoreUseCaseTests`에 필드 검증 추가 (새 테스트 파일 불필요)
- UI는 ConditionCalculationCard preview로 검증

## 리스크 / 엣지 케이스

| 리스크 | 대응 |
|--------|------|
| todayRHR만 있고 yesterdayRHR 없는 경우 | "72 bpm (no comparison)" 표시 |
| 양쪽 다 nil | "RHR" 행 숨김 또는 "—" |
| rhrPenalty > 0인데 RHR 값은 nil (불가능하지만 방어) | penalty 행만 표시 |

## 로컬라이제이션

- "RHR" 라벨: 의학 약어로 번역 면제 (단위 기호와 동일 취급)
- "no comparison", "stable" 등 sub 텍스트: 기존 ConditionCalculationCard의 sub 텍스트와 동일하게 영어 고정 (디버깅 UI 성격)
