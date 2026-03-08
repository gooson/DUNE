---
topic: wellness body record empty state regression
date: 2026-03-08
status: implemented
confidence: high
related_solutions:
  - docs/solutions/performance/2026-02-28-wellness-scrollview-infinite-bounce.md
  - docs/solutions/testing/2026-03-02-nightly-full-ui-test-hardening.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: Wellness Body Record Empty State Regression

## Context

웰니스 탭에서 `+ > Body Record`로 수동 신체기록을 저장해도 아무 카드/링크가 나타나지 않는다. 원인은 `WellnessView`의 empty-state 분기가 `WellnessViewModel`의 HealthKit 기반 카드 상태만 보고 결정되고, SwiftData `@Query`로 분리된 수동 기록 존재 여부를 고려하지 않기 때문이다.

## Requirements

### Functional

- 수동 신체기록만 있는 상태에서도 웰니스 탭이 빈 상태로 남지 않아야 한다.
- 수동 신체기록 저장 직후 사용자가 접근 가능한 body history 진입 카드/링크가 보여야 한다.
- 기존 injury/banner 동작과 HealthKit 기반 카드 렌더링을 깨지 않아야 한다.

### Non-functional

- `docs/solutions/performance/2026-02-28-wellness-scrollview-infinite-bounce.md`의 `@Query` 격리 패턴을 유지한다.
- 수정 범위는 `WellnessView`와 관련 회귀 테스트로 제한한다.
- UI 회귀를 빠르게 검증할 수 있는 smoke test를 추가한다.

## Approach

부모 `WellnessView`의 무거운 ScrollView/body가 SwiftData 변화에 직접 관찰되지 않도록 유지하면서, "HealthKit 기반 지표는 없지만 수동 기록은 있는 상태"만 처리하는 작은 fallback child view를 추가한다. 이 child view가 자체 `@Query`로 body/injury record 존재 여부를 판단해 empty state 또는 수동 기록 진입 UI를 렌더링한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `WellnessView` 루트에 `@Query` 재도입 | empty-state 조건을 가장 단순하게 계산 가능 | 이전 infinite bounce/performance 회귀를 다시 만들 수 있음 | Rejected |
| 수동 body record를 `WellnessViewModel`에 주입 | 상태 계산을 한곳에 모을 수 있음 | ViewModel에 SwiftData 의존이 스며들고 레이어 규칙 위반 위험 | Rejected |
| fallback child view로 수동 기록 상태만 격리 | 기존 구조와 성능 패턴 유지, 수정 범위 최소 | child view가 약간 늘어남 | Accepted |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Wellness/WellnessView.swift` | update | empty-state fallback을 수동 기록 인지형 child view로 분리 |
| `DUNEUITests/Smoke/WellnessSmokeTests.swift` | update | body record 저장 후 body history 링크 표시 회귀 테스트 추가 |

## Implementation Steps

### Step 1: Empty-state gating 보정

- **Files**: `DUNE/Presentation/Wellness/WellnessView.swift`
- **Changes**: HealthKit 카드가 비어 있는 경우에도 SwiftData 기반 수동 기록이 있으면 fallback child view가 body/injury 진입 UI를 노출하도록 수정
- **Verification**: 코드상 수동 body record 존재 시 `EmptyStateView` 대신 body history link가 렌더링되는지 확인

### Step 2: UI smoke regression 추가

- **Files**: `DUNEUITests/Smoke/WellnessSmokeTests.swift`
- **Changes**: body form 저장 후 `wellness-link-bodyhistory` 노출을 검증하는 smoke test 추가
- **Verification**: 대상 UI test가 저장 직후 링크 등장까지 기다려 통과하는지 확인

## Edge Cases

| Case | Handling |
|------|----------|
| HealthKit 데이터는 없고 body record만 있음 | fallback child view가 body history link 노출 |
| HealthKit 데이터는 없고 injury record만 있음 | fallback child view가 injury banner 노출 |
| HealthKit 데이터와 수동 기록이 모두 있음 | 기존 main content 경로 유지, body history link는 기존 child view로 계속 표시 |
| 수동 기록이 전혀 없음 | 기존 empty state 유지 |

## Testing Strategy

- Unit tests: 없음. 이번 변경은 View conditional rendering/UI regression 성격이라 smoke UI test로 검증
- Integration tests: 기존 없음
- Manual verification: Wellness 탭에서 `+ > Body Record` 저장 후 history link/entry UI가 즉시 보이는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| fallback child view가 query 변경마다 과도하게 재렌더링 | low | medium | query 범위를 fallback 영역으로만 제한하고 루트 ScrollView 관찰은 유지하지 않음 |
| UI test가 시뮬레이터 타이밍에 민감 | medium | medium | accessibility identifier 추가 및 `waitForExistence` 사용 |
| injury-only 상태 UI가 기존 기대와 다르게 보일 수 있음 | low | low | 기존 `WellnessInjuryBannerView`를 재사용해 시각 패턴 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 원인이 명확하고, 이전 성능 해결책을 유지하면서 empty-state 분기만 보정하면 되는 국소 수정이다.
