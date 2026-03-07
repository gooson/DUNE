---
topic: workout-procedure-levelup-implementation
date: 2026-03-07
status: implemented
confidence: medium
related_solutions: [docs/solutions/testing/2026-03-07-actions-unit-test-regressions.md]
related_brainstorms: [docs/brainstorms/2026-03-07-workout-procedure-levelup-progression.md]
---

# Implementation Plan: Workout Procedure Replay + Level-Up + Weight Progression

## Context

브레인스토밍에서 정의된 요구사항(운동 절차 자동 재현, 일정 기준 달성 시 레벨업 안내, 세트당/세션당 점진적 중량 증가)을 실제 세션 로직에 반영한다.

## Requirements

### Functional

- 이전 세션 데이터가 있을 때 세트 절차를 재현한다.
- 세트 완료 시 다음 세트 중량을 안전하게 자동 증가할 수 있어야 한다.
- 저장 가능한 수준 달성 시 레벨업 안내 여부를 판단할 수 있어야 한다.

### Non-functional

- 기존 유효성 검증/저장 플로우를 깨지 않아야 한다.
- 증가 로직은 상한선을 가져야 하며 예측 가능해야 한다.
- 변경 로직에 대응하는 단위 테스트를 추가한다.

## Approach

`WorkoutSessionViewModel`에 progression policy/달성 판정 함수를 추가하고, `WorkoutSessionView`의 세트 완료 흐름에서 이를 호출해 다음 세트를 채운다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| View에서 직접 중량 계산 | 빠름 | 중복/테스트 어려움 | 기각 |
| ViewModel에 정책 캡슐화 | 테스트 가능, 재사용 용이 | VM 코드 증가 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift | Modify | progression/level-up 판단 로직 추가 |
| DUNE/Presentation/Exercise/WorkoutSessionView.swift | Modify | 세트 완료 후 다음 세트 중량 자동 증가 적용 |
| DUNETests/WorkoutSessionViewModelTests.swift | Modify | 신규 로직 테스트 추가 |

## Implementation Steps

### Step 1: Progression + Level-up 정책 추가

- **Files**: `WorkoutSessionViewModel.swift`
- **Changes**: 증가폭/상한/근육군 기반 규칙, 레벨업 기준 계산 API 추가
- **Verification**: 각 규칙별 테스트 통과

### Step 2: 세트 완료 플로우 연동

- **Files**: `WorkoutSessionView.swift`
- **Changes**: 세트 완료 후 다음 세트에 증가된 weight 자동 반영
- **Verification**: 기존 prefill 동작과 충돌 없이 값이 채워지는지 확인

### Step 3: 테스트 보강

- **Files**: `WorkoutSessionViewModelTests.swift`
- **Changes**: 증가/동결/레벨업 판정 테스트 케이스 추가
- **Verification**: 대상 테스트 파일 통과

## Edge Cases

| Case | Handling |
|------|----------|
| 현재 세트 무게 없음 | 증가 계산 스킵 |
| reps 파싱 실패 | 증가/레벨업 계산에서 제외 |
| 너무 큰 증가값 | 퍼센트 캡(10%) + plate step 반올림 |
| 부분 완료 세션 | 레벨업 false |

## Testing Strategy

- Unit tests: `WorkoutSessionViewModelTests`
- Integration tests: 없음 (VM + View 연계는 수동 확인 범위)
- Manual verification: 세트 완료 후 다음 세트 무게 자동 증가 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 증가 규칙이 운동 특성에 과/미적합 | Medium | Medium | 보수적 기본값 + 상한선 적용 |
| 기존 prefill 충돌 | Low | Medium | 빈 필드일 때만 적용 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 세션 로직 위에 정책 함수 추가 방식이라 영향 범위는 제한적이나, 실제 UX 기대와 정책 튜닝은 후속 검증이 필요하다.
