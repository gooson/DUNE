---
tags: [condition-score, rhr, ui, domain-model, cloud-mirror]
date: 2026-03-11
category: general
status: implemented
---

# Condition Score RHR UI 가시성 복원

## Problem

`ConditionScoreDetail` 모델이 `rhrPenalty` 숫자만 저장하고 실제 RHR 값(`todayRHR`, `yesterdayRHR`)을 버려서, `ConditionCalculationCard`에서 RHR 값을 표시할 수 없었음. 이후 `displayRHR` fallback까지 추가했지만, Cloud mirrored snapshot payload가 `ConditionScore.detail`과 `contributions`를 저장하지 않아 Today hero card와 Condition Score detail 화면에서는 다시 RHR 문맥이 사라질 수 있었음.

## Root Cause

1. `CalculateConditionScoreUseCase`는 `todayRHR`/`yesterdayRHR`를 입력으로 받아 `rhrPenalty`를 계산하지만, 초기 구현에서는 계산 후 원본 값을 `ConditionScoreDetail`에 저장하지 않았음.
2. 이후 `displayRHR` fallback을 추가했지만, `HealthSnapshotMirrorMapper`가 mirrored payload에서 `ConditionScore.detail`과 `contributions`를 버리고 점수만 재구성했음.
3. legacy mirrored payload는 새 필드가 없어서, 앱이 업데이트되어도 기존 저장 레코드를 그대로 읽으면 hero/detail 화면이 generic 상태로 남을 수 있었음.

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

### 5. Display RHR Fallback (2026-03-12 추가)

`todayRHR`이 nil인 경우(Apple이 아직 오늘의 RHR을 계산하지 않은 시점) RHR 행이 완전히 숨겨지는 문제 해결.

**추가 필드** (`ConditionScoreDetail`):
```swift
let displayRHR: Double?     // latestRHR fallback (최근 7일 내)
let displayRHRDate: Date?   // displayRHR의 날짜
```

**데이터 흐름**:
- `DashboardViewModel`: 이미 계산된 `effectiveRHR` (todayRHR ?? latestRHR)를 UseCase Input에 전달
- `SharedHealthDataServiceImpl`: 동일 패턴 적용
- `ConditionCalculationCard`: `todayRHR ?? displayRHR`로 RHR 행 표시, historical 값이면 날짜 표시

**핵심**: penalty 계산은 여전히 todayRHR/yesterdayRHR만 사용 (Correction #24 준수). displayRHR은 순수 UI 표시용.

### 6. Mirrored Snapshot 보존 + Legacy 복원 (2026-03-12 추가)

`HealthSnapshotMirrorMapper`가 current `ConditionScore`의 다음 정보를 함께 payload에 저장하도록 확장:

```swift
let conditionContributions: [ScoreContribution]?
let conditionDetail: ConditionScoreDetail?
```

복원 시 동작:
- 새 payload: 저장된 `detail`/`contributions`를 그대로 사용
- legacy payload: `hrv14Day`, `todayRHR`, `yesterdayRHR`, `latestRHR`로 `CalculateConditionScoreUseCase`를 다시 실행해 `detail`과 `contributions`를 즉시 재생성

추가 UI 정렬:
- `ConditionScoreDetailView` hero subtitle은 `status.guideMessage` 대신 `score.narrativeMessage`를 사용해 Today hero와 동일한 RHR-aware narrative를 노출

## Prevention

- Domain 모델에서 계산 입력값을 버리지 말고 항상 저장할 것 — UI에서 필요할 수 있음
- HealthKit 데이터가 "오늘 날짜에 없을 수 있음"을 항상 고려 — `latestRHR` 같은 fallback 경로 확보
- `BodyScoreDetail` 등 유사 패턴에서도 동일 원칙 적용
- pre-compute 패턴(Correction #80) 준수: body에서 함수 호출 금지
- display 용도의 값도 `rhrValidRange` 검증 적용 (todayRHR과 동일 수준)
- mirror payload가 summary score만 저장하면 안 됨 — detail 화면이 사용하는 `detail`/`contributors`까지 함께 보존하거나, 최소한 legacy payload를 로컬에서 재구성할 수 있어야 함

## Related

- `docs/solutions/general/2026-02-25-condition-score-zero-fix.md` — RHR fallback 버그
- `docs/solutions/architecture/2026-02-25-body-score-calculation-card.md` — BodyScoreDetail 패턴
