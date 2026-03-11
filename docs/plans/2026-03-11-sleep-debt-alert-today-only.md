---
topic: sleep-debt-alert-today-only
date: 2026-03-11
status: draft
confidence: high
related_solutions:
  - docs/solutions/architecture/sleep-deficit-personal-average.md
  - docs/solutions/healthkit/background-notification-system.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-sleep-deficit-personal-average.md
  - docs/brainstorms/2026-03-03-healthkit-background-notifications.md
---

# Implementation Plan: Sleep Debt Alert Today Only

## Context

`Sleep Debt Alert` 알림은 현재 7일 누적 부채(`weeklyDeficit`)와 level만 보고 생성된다. 이 구조에서는 오늘 수면이 충분해 당일 deficit이 0이어도, 과거 며칠의 누적 부채만으로 오늘 알림이 발생할 수 있다. 사용자가 체감하는 "오늘자 경고"와 실제 트리거 기준이 어긋나므로, 알림 applicability를 오늘 데이터에 한정해야 한다.

## Requirements

### Functional

- `Sleep Debt Alert`는 `SleepDeficitAnalysis`에 오늘자(`today`) 일별 deficit이 존재할 때만 생성한다.
- 오늘 entry가 있어도 deficit이 0 이하이면 sleep debt alert를 생성하지 않는다.
- 오늘자 deficit이 양수이고 level이 `good`/`insufficient`가 아니면 기존과 동일한 sleep debt alert를 생성한다.
- today-only guard에 걸린 경우 background evaluator는 `sleepComplete` fallback 흐름을 유지한다.

### Non-functional

- 날짜 판정은 `Calendar` 기반으로 일 단위 비교하여 자정 경계 회귀를 줄인다.
- Domain layer purity를 유지한다. (`Foundation` 외 추가 의존성 없음)
- 기존 localization key/title/body는 유지하여 사용자-facing copy regression을 피한다.
- 기존 테스트 파일에 경계 분기를 추가해 regression을 막는다.

## Approach

수면 부채 알림 applicability 판단을 `EvaluateHealthInsightUseCase.evaluateSleepDebt`로 이동한다. background evaluator는 계산된 `SleepDeficitAnalysis` 전체를 전달하고, use case가 `dailyDeficits`의 최신 today entry를 확인해 alert 생성 여부를 결정한다.

이 접근을 선택하는 이유:

- 알림 생성 규칙이 `HealthInsight` 조립 지점에 모여 있어 테스트하기 쉽다.
- Data layer는 분석 결과 전달만 담당하고, "언제 alert를 만들어야 하는가"는 Domain rule로 유지된다.
- 기존 `sleepComplete` fallback을 최소 수정으로 유지할 수 있다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `BackgroundNotificationEvaluator`에서 today 여부를 직접 guard | 변경 파일이 적음 | alert rule이 Data layer로 내려가고 테스트가 어려움 | Rejected |
| `EvaluateHealthInsightUseCase`가 `SleepDeficitAnalysis` 전체를 받아 today deficit까지 판단 | 도메인 규칙 집중, 단위 테스트 용이 | 시그니처 변경 필요 | Selected |
| `SleepDeficitAnalysis` 모델에 today helper 추가 | 재사용 가능 | 이번 요구 범위 대비 모델 표면적 증가 | Rejected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/UseCases/EvaluateHealthInsightUseCase.swift` | modify | sleep debt alert 생성 조건을 today-only로 강화 |
| `DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift` | modify | use case 호출을 `SleepDeficitAnalysis` 기반으로 변경 |
| `DUNETests/EvaluateHealthInsightUseCaseTests.swift` | modify | today deficit 존재/부재/0 deficit 분기 테스트 추가 |
| `docs/plans/2026-03-11-sleep-debt-alert-today-only.md` | add | 이번 변경 계획 문서 |
| `docs/solutions/general/2026-03-11-sleep-debt-alert-today-only.md` | add | 최종 해결 패턴 문서화 |

## Implementation Steps

### Step 1: Move sleep debt applicability to domain use case

- **Files**: `DUNE/Domain/UseCases/EvaluateHealthInsightUseCase.swift`
- **Changes**:
  - `evaluateSleepDebt` 입력을 `SleepDeficitAnalysis` 중심으로 조정
  - `dailyDeficits`에서 today entry를 찾고, today deficit이 양수일 때만 alert 생성
  - 기존 level / weeklyDeficit guard와 alert message 포맷은 유지
- **Verification**: use case tests에서 today entry/date/0 deficit 분기 확인

### Step 2: Update background evaluator call site

- **Files**: `DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift`
- **Changes**:
  - sleep deficit analysis 계산 후 revised use case 호출
  - today-only guard에 걸리면 기존 `sleepComplete` fallback이 유지되도록 확인
- **Verification**: build + 관련 unit tests 통과

### Step 3: Add regression tests

- **Files**: `DUNETests/EvaluateHealthInsightUseCaseTests.swift`
- **Changes**:
  - 오늘자 deficit이 있을 때 alert 생성
  - 오늘 entry가 아니면 alert 미생성
  - 오늘 entry지만 deficit 0이면 alert 미생성
- **Verification**: `swift test` 또는 `scripts/test-unit.sh --ios-only`에서 해당 테스트 통과

## Edge Cases

| Case | Handling |
|------|----------|
| `dailyDeficits`가 비어 있음 | alert 생성하지 않음 |
| 최신 entry가 today가 아님 | alert 생성하지 않음 |
| today entry가 있지만 deficit 0 | alert 생성하지 않음 |
| weekly deficit > 0 이지만 level이 `.good` | 기존대로 alert 생성하지 않음 |
| overnight sleep 샘플로 오늘 entry가 생성됨 | `Calendar.isDate(_:inSameDayAs:)`로 today 판단 |

## Testing Strategy

- Unit tests: `DUNETests/EvaluateHealthInsightUseCaseTests.swift`에 today-only 분기 추가
- Integration tests: 없음. background evaluator는 use case 결과 wiring만 변경
- Manual verification: sleep debt가 누적되었지만 오늘 수면이 평균 이상인 fixture에서 `Sleep Debt Alert`가 생성되지 않는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| today 판정이 시간대/자정 경계에서 어긋남 | low | medium | `Calendar.isDate(_:inSameDayAs:)` 사용 |
| call-site 시그니처 변경으로 다른 참조 누락 | low | medium | `rg`로 모든 call site 확인 |
| alert suppression이 과도해질 가능성 | low | medium | 양수 today deficit 케이스를 명시 테스트 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: call site가 단일하고, today applicability rule이 pure domain logic으로 표현 가능하며, 기존 테스트 파일에 regression 추가가 쉽다.
