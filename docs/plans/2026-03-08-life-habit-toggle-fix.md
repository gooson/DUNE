---
topic: life habit toggle fix
date: 2026-03-08
status: implemented
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-02-28-habit-tab-implementation-patterns.md
  - docs/solutions/architecture/2026-03-04-life-tab-ux-consistency-sectiongroup-refresh.md
  - docs/solutions/general/2026-03-04-habit-recurring-start-point.md
related_brainstorms:
  - docs/brainstorms/2026-02-28-systematic-ui-test-design.md
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: Life Habit Toggle Fix

## Context

Life 탭의 `My Habits`에서 체크형 습관을 눌러도 완료 상태가 즉시 반영되지 않는다. 현재 `HabitListQueryView`는 `HabitDefinition`만 관찰하고, 토글 직후에는 `habit.logs` relationship을 다시 읽어 진행률을 계산한다. 이 구조는 SwiftData 변경 타이밍에 따라 새 `HabitLog`가 같은 렌더 사이클에 반영되지 않아 완료 상태가 갱신되지 않을 수 있다.

공식 Apple 문서에서도 `@Query`를 통해 SwiftData 변경을 화면에 반영하는 패턴을 권장하고 있으며, 변경을 관찰하는 데이터 소스가 실제 파생 상태 계산 입력과 일치해야 한다는 점을 시사한다. 이번 수정은 Life 탭의 계산 입력을 로그 변경과 동기화하고, 회귀를 막는 UI 검증을 추가하는 데 목적이 있다.

## Requirements

### Functional

- Life 탭의 체크형 습관을 탭하면 완료 상태와 hero progress가 즉시 반영되어야 한다.
- 같은 항목을 다시 탭하면 완료가 해제되어야 한다.
- count / duration / recurring habit 동작은 유지되어야 한다.
- seeded UI 환경에서 habit toggle 회귀를 자동 검증할 수 있어야 한다.

### Non-functional

- `HabitListQueryView`의 isolated `@Query` 구조는 유지한다.
- SwiftData/CloudKit 관계 모델을 깨지 않는 최소 수정으로 해결한다.
- UI 테스트가 안정적으로 요소를 찾을 수 있도록 AXID를 보강한다.

## Approach

`HabitListQueryView`에서 습관 로그도 별도로 관찰하고, 토글/값 변경/주기 액션 시 relationship 컬렉션을 즉시 동기화하는 helper를 추가한다. 이렇게 하면 `recalculate()`가 같은 이벤트 루프 안에서 최신 로그 집합으로 진행률을 계산할 수 있고, 이후 SwiftData query 갱신이 와도 상태가 다시 뒤집히지 않는다. 동시에 habit section / row toggle에 accessibility identifier를 부여하고 seeded smoke test를 추가해 탭 동작을 회귀 테스트로 고정한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `try modelContext.save()` 후 재계산 | 변경 코드가 적음 | autosave 타이밍/relationship refresh에 여전히 의존 | 기각 |
| `HabitDefinition.logs`만 직접 append/remove | immediate UI fix 가능 | 외부 로그 변경(CloudKit, future entry point) 관찰이 부족 | 부분 채택 |
| `HabitLog`를 별도 `@Query`로 관찰하고 토글 helper에서 relationship도 즉시 동기화 | immediate fix + passive refresh 모두 보강 | 코드가 약간 늘어남 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Life/LifeView.swift` | modify | `HabitLog` query 추가, log sync helper 추가, recalculate trigger 보강 |
| `DUNE/Presentation/Life/HabitRowView.swift` | modify | habit toggle accessibility identifier 추가 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | modify | Life habit toggle selector 상수 추가 |
| `DUNEUITests/Smoke/LifeSmokeTests.swift` | modify | seeded habit toggle completion smoke test 추가 |
| `docs/solutions/general/2026-03-08-life-habit-toggle-sync.md` | add | root cause / fix / prevention 문서화 |

## Implementation Steps

### Step 1: Log observation and immediate state sync

- **Files**: `DUNE/Presentation/Life/LifeView.swift`
- **Changes**:
  - `HabitListQueryView`에 `HabitLog` query 또는 equivalent observation 추가
  - log insert/delete를 공통 helper로 묶어 `habit.logs`와 `modelContext`를 같은 액션에서 동기화
  - `recalculate()`를 log 변경에도 다시 실행되도록 연결
- **Verification**: 체크형 habit tap 이후 `viewModel.completedCount`와 row icon이 즉시 갱신된다.

### Step 2: UI test selectors and regression coverage

- **Files**: `DUNE/Presentation/Life/HabitRowView.swift`, `DUNEUITests/Helpers/UITestHelpers.swift`, `DUNEUITests/Smoke/LifeSmokeTests.swift`
- **Changes**:
  - habit section / toggle button selector를 부여
  - seeded smoke test에서 habit toggle 전후 hero/habit 상태 변화를 검증
- **Verification**: seeded UI test가 토글 전후 상태를 식별할 수 있다.

### Step 3: Validation and pipeline outputs

- **Files**: 계획서/solution doc, 필요 시 테스트 파일
- **Changes**:
  - Life 관련 unit/UI tests 실행
  - review/compound에 필요한 결과 정리
- **Verification**: 대상 테스트가 통과하고 문서 산출물이 생성된다.

## Edge Cases

| Case | Handling |
|------|----------|
| 이미 완료된 체크형 habit 재탭 | 해당 일자의 log만 삭제하고 hero count를 감소시킨다 |
| count/duration habit 값 수정 | 기존 today logs 정리 후 새 값 log를 1회 삽입한다 |
| recurring habit complete/skip/snooze | 기존 cycle helper를 유지하되 동일한 log sync 경로를 사용한다 |
| seeded data 없는 UI test 환경 | 기존 smoke test와 분리하여 seeded base case에서만 toggle 검증한다 |

## Testing Strategy

- Unit tests: 기존 `LifeViewModelTests` 회귀 영향 확인
- Integration tests: `DUNEUITests/Smoke/LifeSmokeTests.swift`에 seeded toggle smoke 추가
- Manual verification: Life 탭에서 check habit 1개를 2회 탭해 완료/해제와 hero count 변화를 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| relationship 수동 동기화가 SwiftData inverse update와 충돌 | medium | medium | append/remove를 id 기준으로 보호하고 중복 추가를 피한다 |
| `HabitLog` query 추가로 재계산 빈도 증가 | low | low | count/signature 기반 최소 change observation만 사용한다 |
| UI test가 텍스트 기반 selector에 의존해 locale에 취약 | medium | medium | accessibility identifier를 고정한다 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 원인 가설은 현재 코드 구조와 증상에 강하게 부합하지만, SwiftData relationship 반영 타이밍은 런타임 의존성이 있어 테스트 실행으로 최종 확인이 필요하다.
