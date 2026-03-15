---
tags: [unit-test, swift-testing, foundation-models, watchos, regression]
category: testing
date: 2026-03-14
severity: important
related_files:
  - DUNE/Domain/UseCases/CalculateTrainingReadinessUseCase.swift
  - DUNE/Domain/UseCases/CalculateWellnessScoreUseCase.swift
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
  - DUNE/Data/Services/HealthDataQAService.swift
  - DUNE/Data/Services/AICoachingMessageService.swift
  - DUNE/Data/Services/AIWorkoutTemplateGenerator.swift
  - DUNEWatch/Helpers/WatchRPEEstimator.swift
related_solutions:
  - docs/solutions/testing/2026-02-16-xcodegen-test-infrastructure.md
---

# Solution: Unit Test Regression Fix

## Problem

`scripts/test-unit.sh` 실행 시 iOS/watch unit suite가 여러 군데에서 깨졌다. 첫 증상은
`CalculateTrainingReadinessUseCase.Input` 와 `CalculateWellnessScoreUseCase.Input` 의
`evaluationDate` 인자 컴파일 오류였지만, 이를 복구한 뒤에도 runtime 환경과 locale, persisted
timestamp precision에 묶인 test 가정들이 연쇄적으로 드러났다.

### Symptoms

- use case input 생성 시 `extra argument 'evaluationDate' in call`
- Foundation Models 가용성에 따라 simulator test 결과가 달라짐
- localized string 비교가 English literal에 묶여 실패
- mirrored payload roundtrip에서 `ConditionScoreDetail.evaluationDate` 정밀도 차이로 equality 실패
- watch `WatchRPEEstimator` 가 무게 증가 세트에도 reps degradation correction을 적용해 `nil` 또는 과대 추정 반환

### Root Cause

- stored property default만 둔 `let evaluationDate` 는 외부 주입 가능한 memberwise init parameter를 만들지 않았다.
- 일부 test는 "simulator에서는 Foundation Models unavailable" 같은 하드웨어/런타임 가정을 박아두고 있었다.
- localized copy와 millisecond-encoded `Date` 를 literal/equality로 직접 비교했다.
- watch RPE estimator는 "같은 무게에서 reps 감소"라는 fatigue correction 조건을 코드로 제한하지 않았다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/UseCases/CalculateTrainingReadinessUseCase.swift` | `Input` explicit initializer 추가 | `evaluationDate` 주입 surface 복구 |
| `DUNE/Domain/UseCases/CalculateWellnessScoreUseCase.swift` | `Input` explicit initializer 추가 | time-of-day 검증 테스트 복구 |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | live HRV refresh 실패 시 stale condition state clear | refresh 실패 후 이전 점수가 남는 회귀 차단 |
| `DUNE/Data/Services/HealthDataQAService.swift` | availability provider injection 추가 | Foundation Models 가용성 테스트를 deterministic 하게 고정 |
| `DUNE/Data/Services/AICoachingMessageService.swift` | availability provider injection 추가 | runtime hardware 의존 test 제거 |
| `DUNE/Data/Services/AIWorkoutTemplateGenerator.swift` | availability provider injection 추가 | unavailable path test를 host 상태와 분리 |
| `DUNETests/*` 일부 | localized expectation / deterministic fixture로 갱신 | locale/date precision 기반 flake 제거 |
| `DUNEWatch/Helpers/WatchRPEEstimator.swift` | same-weight일 때만 reps degradation correction 적용 + upper clamp 추가 | watch RPE auto-estimation regression 수정 |

### Key Code

```swift
struct Input: Sendable {
    let evaluationDate: Date

    init(..., evaluationDate: Date = .now) {
        ...
        self.evaluationDate = evaluationDate
    }
}

if hrvResult.failed, sharedSnapshot == nil {
    conditionScore = nil
    baselineStatus = nil
    recentScores = []
}
```

## Prevention

### Checklist Addition

- [ ] stored property default로 외부 initializer surface가 유지된다고 가정하지 않는다
- [ ] Foundation Models / Apple Intelligence 가용성은 test에서 provider injection으로 고정한다
- [ ] localized string은 literal English가 아니라 `String(localized:)` 기준으로 검증한다
- [ ] persisted `Date` roundtrip equality는 deterministic fixture timestamp를 사용한다
- [ ] watch fatigue correction은 "같은 무게" 같은 전제 조건을 코드와 테스트에 함께 고정한다

### Rule Addition (if applicable)

기존 `testing-required.md` 와 `testing-patterns` 범위에서 커버 가능해서 새 rule 추가는 생략했다.

## Lessons Learned

1. 테스트 회귀는 한 개의 compile error만 고쳐도 끝나지 않고, 숨겨진 runtime assumption을 연달아 드러내는 경우가 많다.
2. host hardware capability에 따라 달라지는 기능은 availability injection 없이는 안정적인 unit test를 만들기 어렵다.
3. persistence roundtrip 테스트는 `Date()` 같은 현재 시각 fixture를 쓰는 순간 millisecond precision mismatch로 쉽게 깨진다.
