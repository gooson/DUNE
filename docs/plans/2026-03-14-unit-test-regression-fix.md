---
topic: unit-test-regression-fix
date: 2026-03-14
status: implemented
confidence: high
related_solutions:
  - docs/solutions/testing/2026-02-16-xcodegen-test-infrastructure.md
  - docs/solutions/general/2026-03-08-simulator-advanced-mock-data.md
related_brainstorms:
  - docs/brainstorms/2026-03-02-unit-test-hardening-including-watch.md
---

# Implementation Plan: Unit Test Regression Fix

## Context

`scripts/test-unit.sh --no-stream-log` 실행 시 iOS unit test build가 실패한다. 실패 원인은
`CalculateTrainingReadinessUseCase.Input` 와 `CalculateWellnessScoreUseCase.Input` 에서
`evaluationDate` 를 전달받는 public memberwise initializer surface가 사라져, 기존 테스트와
time-of-day 보정 검증 경로가 컴파일되지 않는 것이다.

## Requirements

### Functional

- 전체 unit test를 실제로 실행해 실패를 재현한다.
- `evaluationDate` 를 명시적으로 주입할 수 있도록 두 use case input API를 복구한다.
- 관련 unit test가 다시 컴파일되고 통과하는지 검증한다.

### Non-functional

- 기존 call site를 깨지 않는 최소 수정으로 처리한다.
- time-of-day adjustment 관련 테스트 의도를 유지한다.
- `scripts/test-unit.sh` 기준으로 iOS + watch unit test를 모두 재검증한다.

## Approach

`let evaluationDate: Date = .now` 형태의 stored property default는 외부에서 해당 값을 받는
memberwise initializer parameter를 만들지 않는다. 따라서 property default만 두는 대신,
`CalculateConditionScoreUseCase.Input` 패턴과 맞춰 explicit initializer를 선언해
`evaluationDate` 기본값은 유지하면서 외부 주입도 허용한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 테스트에서 `evaluationDate` 전달 제거 | 수정 범위가 좁다 | 생산 코드의 의도된 주입 포인트가 사라지고 time-of-day 테스트 가치가 줄어든다 | 기각 |
| Input stored property를 `var` 로 변경 | 간단해 보인다 | 불필요하게 mutability를 늘리고 initializer surface 문제를 해결하지 못한다 | 기각 |
| Input에 explicit initializer 추가 | 기존 API 의도와 테스트를 모두 보존한다 | 생산 코드 2파일 수정이 필요하다 | 선택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/UseCases/CalculateTrainingReadinessUseCase.swift` | code fix | `Input` explicit initializer 추가 |
| `DUNE/Domain/UseCases/CalculateWellnessScoreUseCase.swift` | code fix | `Input` explicit initializer 추가 |
| `DUNETests/CalculateTrainingReadinessUseCaseTests.swift` | verification | `evaluationDate` 주입 경로 재컴파일 확인 |
| `DUNETests/CalculateWellnessScoreUseCaseTests.swift` | verification | score/status 경계 테스트 재컴파일 확인 |

## Implementation Steps

### Step 1: Restore input initializer surface

- **Files**: `DUNE/Domain/UseCases/CalculateTrainingReadinessUseCase.swift`, `DUNE/Domain/UseCases/CalculateWellnessScoreUseCase.swift`
- **Changes**: `evaluationDate` 를 포함한 explicit `init(...)` 를 선언하고 기본값은 `.now` 또는 `Date()` 수준으로 유지
- **Verification**: failing test files가 더 이상 `extra argument 'evaluationDate' in call` 를 내지 않아야 함

### Step 2: Re-run unit suites

- **Files**: 없음
- **Changes**: `scripts/test-unit.sh --no-stream-log` 재실행 후 iOS/watch suite 모두 확인
- **Verification**: `** TEST FAILED **` 없이 두 suite가 종료되어야 함

## Edge Cases

| Case | Handling |
|------|----------|
| call site가 `evaluationDate` 를 생략하는 경우 | initializer default 값으로 기존 동작 유지 |
| test가 과거/특정 시각을 주입하는 경우 | explicit initializer로 deterministic verification 유지 |
| 다른 compile error가 연쇄적으로 드러나는 경우 | 첫 수정 후 전체 suite를 다시 실행해 추가 회귀를 계속 수정 |

## Testing Strategy

- Unit tests: `scripts/test-unit.sh --no-stream-log`
- Integration tests: 없음
- Manual verification: `.xcodebuild/unit-test.log` 실패 요약과 재실행 결과 비교

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| initializer signature가 기존 call site와 어긋남 | 낮음 | 중간 | `CalculateConditionScoreUseCase.Input` 패턴을 그대로 따른다 |
| iOS compile fix 후 watch suite에서 별도 실패 발생 | 중간 | 중간 | 전체 `scripts/test-unit.sh` 를 다시 돌려 watch까지 확인한다 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 현재 실패 로그가 모두 동일한 initializer surface regression을 가리키고 있고, 인접 use case에 이미 검증된 패턴이 있다.
