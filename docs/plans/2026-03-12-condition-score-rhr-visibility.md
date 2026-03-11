---
topic: condition-score-rhr-visibility
date: 2026-03-12
status: draft
confidence: high
related_solutions:
  - docs/solutions/performance/2026-02-15-healthkit-query-parallelization.md
related_brainstorms:
  - docs/brainstorms/2026-03-11-condition-score-rhr-visibility.md
---

# Implementation Plan: Condition Score RHR Visibility

## Context

Today 히어로 카드와 Condition Score 상세 화면에서 RHR가 누락된다. 현재 `ConditionCalculationCard`와 `ConditionScoreDetail` 자체는 RHR를 표시할 수 있지만, Cloud mirror payload가 `ConditionScore`를 점수만 남기고 재구성하면서 `detail`과 `contributions`를 버린다. 그 결과 mirrored snapshot 경로에서는 hero narrative가 generic guide message로 후퇴하고, 상세 화면의 계산 카드도 렌더링되지 않는다. 추가로 상세 화면 hero는 `score.narrativeMessage` 대신 `status.guideMessage`를 사용해, detail이 살아 있어도 RHR 맥락을 잃는다.

## Requirements

### Functional

- mirrored snapshot 경로에서도 `ConditionScore.detail`과 `contributions`가 보존되어야 한다.
- Today hero card가 mirrored snapshot에서도 RHR-aware narrative를 유지해야 한다.
- Condition Score detail hero가 generic guide message 대신 현재 score narrative를 사용해야 한다.
- 기존 payload를 읽을 때는 backward compatible 해야 한다.

### Non-functional

- 기존 Cloud mirror JSON decode를 깨뜨리지 않아야 한다.
- 변경 범위는 Condition Score mirror serialization과 detail hero copy에 한정한다.
- 회귀를 막기 위한 unit test를 추가하거나 갱신한다.

## Approach

`HealthSnapshotMirrorMapper.Payload`에 현재 condition score를 복원하는 데 필요한 최소 정보를 optional 필드로 추가한다. 구체적으로 `contributions`와 `ConditionScoreDetail`을 encode/decode 가능한 nested payload로 저장하고, `makeSnapshot`에서 이를 사용해 full `ConditionScore`를 재구성한다. 기존 레코드는 새 필드가 없더라도 decode 가능하도록 optional로 둔다. UI 쪽에서는 `ConditionScoreDetailView` hero subtitle을 `score.narrativeMessage`로 바꿔 mirrored/local 경로 모두 동일한 narrative를 보여준다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `DashboardViewModel`에서 snapshot의 raw HRV/RHR로 detail 재계산 | UI layer에서 즉시 보정 가능 | 중복 계산, detail/contributions 누락 원인 자체는 유지, 다른 소비자에 재발 가능 | 기각 |
| mirror payload에 full `ConditionScore` 복원 정보 저장 | 단일 원인 제거, 모든 mirrored consumer에 일관 적용 | payload 구조 확장 필요 | 선택 |
| hero/card가 detail 없어도 RHR를 별도 계산해 표시 | 증상만 완화 | detail screen contributors/calculation card 누락 문제 해결 안 됨 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Services/HealthSnapshotMirrorMapper.swift` | modify | `ConditionScore` detail/contributions payload 추가 및 복원 |
| `DUNE/Presentation/Dashboard/ConditionScoreDetailView.swift` | modify | detail hero subtitle을 narrative 기반으로 통일 |
| `DUNETests/HealthSnapshotMirrorMapperTests.swift` | modify | mirror roundtrip 시 detail/contributions 보존 검증 |
| `DUNETests/CloudMirroredSharedHealthDataServiceTests.swift` | modify | mirrored service가 복원한 condition detail을 노출하는지 검증 |

## Implementation Steps

### Step 1: Extend mirror payload for condition detail

- **Files**: `DUNE/Data/Services/HealthSnapshotMirrorMapper.swift`
- **Changes**: nested payload structs를 추가해 `ConditionScoreDetail`과 `ScoreContribution`을 encode/decode하고, `makePayload`/`makeSnapshot`에서 current condition score의 detail과 contributions를 roundtrip 한다.
- **Verification**: mapper unit test에서 detail/contributions가 동일하게 유지된다.

### Step 2: Keep detail hero narrative aligned

- **Files**: `DUNE/Presentation/Dashboard/ConditionScoreDetailView.swift`
- **Changes**: hero subtitle에 `score.status.guideMessage` 대신 `score.narrativeMessage`를 전달한다.
- **Verification**: code inspection으로 dashboard hero/detail hero가 동일 narrative source를 사용한다.

### Step 3: Add regression coverage for mirrored consumers

- **Files**: `DUNETests/HealthSnapshotMirrorMapperTests.swift`, `DUNETests/CloudMirroredSharedHealthDataServiceTests.swift`
- **Changes**: mirrored payload/service가 `ConditionScore.detail.todayRHR`, `yesterdayRHR`, `displayRHR`, `contributions`를 보존하는 테스트를 추가한다.
- **Verification**: targeted tests pass.

## Edge Cases

| Case | Handling |
|------|----------|
| 기존 mirror record에 새 필드 없음 | optional decode로 기존 레코드 유지, detail/contributions는 nil/empty fallback |
| `todayRHR` 없이 historical `displayRHR`만 있는 경우 | `displayRHR`와 `displayRHRDate`를 payload에 포함해 fallback UI 유지 |
| detail은 있지만 contributions 없음 | `ConditionScore`는 empty contributions로 복원 가능하게 유지 |

## Testing Strategy

- Unit tests: mapper roundtrip test, mirrored service reconstruction test
- Integration tests: 없음, shared snapshot 복원 경로는 unit 수준에서 검증
- Manual verification: mirrored snapshot 환경에서 Today hero subtitle과 Condition Score detail 계산 카드에 RHR가 표시되는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| payload schema 확장으로 old JSON decode 깨짐 | low | high | 새 필드를 모두 optional로 추가하고 기존 test에 roundtrip 케이스 유지 |
| mirrored snapshot의 detail만 복원되고 hero copy는 여전히 generic | medium | medium | detail hero를 narrative source로 명시적으로 변경 |
| 테스트 fixture가 새 payload 필드를 빠뜨려 compile/test 실패 | medium | low | mapper/service tests fixture를 함께 갱신 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 현재 UI는 detail만 있으면 RHR를 이미 렌더링할 수 있고, 누락 원인이 mirror serialization 축소에 집중되어 있다.
