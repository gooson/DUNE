---
topic: SwiftData 134504 Recovery
date: 2026-03-14
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-01-swiftdata-schema-model-mismatch.md
  - docs/solutions/architecture/2026-03-12-mac-swiftdata-migration-refresh-stability.md
  - docs/solutions/architecture/2026-03-12-swiftdata-reopen-snapshot-pairing.md
  - docs/solutions/general/2026-03-07-review-finding-fixes.md
  - docs/solutions/architecture/2026-03-13-hourly-score-snapshot-system.md
related_brainstorms:
  - docs/brainstorms/2026-03-13-hourly-condition-tracking.md
---

# Implementation Plan: SwiftData 134504 Recovery

## Context

`default.store`를 여는 시점에 `NSCocoaErrorDomain 134504`와
`Cannot use staged migration with an unknown model version`가 발생한다.
현재 로그는 Core Data가 migration failure를 명확히 기록했는데도 앱이
`Skipping store deletion for non-migration container error` 경로로 빠져 in-memory fallback만 사용한다.

문제는 두 층이다.

1. 기존 App Group store가 현재 `AppMigrationPlan`이 알지 못하는 checksum 상태일 수 있다.
   특히 `AppSchemaV15` 추가 직후 개발 중간 빌드가 남긴 store면 이 상황이 쉽게 생긴다.
2. top-level `SwiftData.SwiftDataError.loadIssueModelContainer`가 migration error를 감싼 채 올라오면
   현재 `PersistentStoreRecovery`가 이를 migration failure로 분류하지 못해 store purge/retry가 생략된다.

이 작업의 목표는 schema 자체를 임의로 다시 올리는 것이 아니라,
현재 declared schema가 유효하다는 전제에서 `unknown model version` recovery를 실제로 동작하게 만들고,
동시에 V15 regression guard를 보강하는 것이다.

## Requirements

### Functional

- `ModelContainer` 초기화가 wrapped migration failure(`SwiftDataError.loadIssueModelContainer`)로 실패해도
  recoverable migration error로 분류되어 persistent store delete → recreate 경로가 실행되어야 한다.
- iOS와 watchOS bootstrap이 동일한 recovery semantics를 유지해야 한다.
- `AppMigrationPlanTests`가 최신 schema를 `V15`로 인지하고, V15 관련 회귀를 더 이상 놓치지 않아야 한다.
- recovery 분류 로직은 non-migration startup failure와 CloudKit/account failure를 계속 보존해야 한다.

### Non-functional

- 데이터 삭제는 migration-compatible failure에만 한정해야 한다.
- 변경은 기존 persistence bootstrap 구조를 깨지 않는 최소 범위여야 한다.
- 테스트는 Swift Testing 패턴을 따르고 기존 suite에 회귀 케이스를 추가해야 한다.
- 문서에는 "왜 schema bump가 아니라 recovery fix가 맞는지" 근거가 남아야 한다.

## Approach

핵심 접근은 `schema bump`가 아니라 `recovery classification + regression guard`다.

- `AppSchemaV15` 이후 persisted model set에는 git 이력상 추가 schema delta가 없다.
  따라서 근거 없는 `V16` 추가는 duplicate checksum 또는 잘못된 migration history를 만들 가능성이 높다.
- 실제 런타임 로그는 migration failure 자체보다도 "migration failure를 recovery가 놓친다"는 점을 보여준다.
- Apple의 SwiftData migration guidance도 `VersionedSchema`의 total ordering과
  release별 schema capture를 강조한다. 이미 배포된 버전의 checksum이 drift하지 않도록 guard test를 강화하는 편이 맞다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `PersistentStoreRecovery`만 강화 | 직접 관측된 failure path를 해결, 변경 범위 작음 | schema regression guard가 약하면 재발 가능 | 채택 |
| `AppSchemaV16` 추가 | 미래 drift 대응처럼 보임 | 실제 model delta가 없으면 duplicate checksum 위험, 현재 orphan checksum을 직접 해결하지 못함 | 미채택 |
| 앱 전체 store purge fallback 확대 | 즉시 복구 가능성 높음 | permission/CloudKit 오류까지 데이터 삭제 위험 | 미채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Persistence/Migration/PersistentStoreRecovery.swift` | modify | wrapped SwiftData migration failure를 recoverable로 분류하도록 확장 |
| `DUNE/App/DUNEApp.swift` | modify | recovery logging/branching을 현재 helper 계약에 맞게 유지 또는 보강 |
| `DUNEWatch/DUNEWatchApp.swift` | modify | iOS와 동일한 recovery behavior 유지 |
| `DUNETests/PersistentStoreRecoveryTests.swift` | modify | top-level SwiftData error description path 회귀 테스트 추가 |
| `DUNETests/AppMigrationPlanTests.swift` | modify | latest schema를 V15 기준으로 갱신하고 V15 regression guard 추가 |
| `docs/solutions/architecture/2026-03-14-swiftdata-134504-recovery.md` | create | 원인/해결/예방 문서화 |

## Implementation Steps

### Step 1: Harden migration recovery classification

- **Files**: `PersistentStoreRecovery.swift`, `DUNEApp.swift`, `DUNEWatchApp.swift`
- **Changes**:
  - `SwiftData.SwiftDataError.loadIssueModelContainer`처럼 top-level wrapper만 남는 경우를 분류할 수 있게
    helper를 확장한다.
  - 기존 `NSError` chain 탐색은 유지하고, migration signature가 wrapper description에만 남는 케이스를 추가로 잡는다.
  - iOS/watch recovery path가 같은 helper 계약을 사용하도록 확인하고 필요 시 logging을 보강한다.
- **Verification**:
  - recovery helper unit tests 통과
  - `scripts/build-ios.sh` 성공

### Step 2: Refresh V15 migration guard tests

- **Files**: `DUNETests/AppMigrationPlanTests.swift`
- **Changes**:
  - latest schema expectation을 `AppSchemaV15` 기준으로 갱신한다.
  - `HourlyScoreSnapshot`가 current schema에 포함되는지 검증한다.
  - 가능하면 `V14` on-disk store를 current migration plan으로 reopen하는 테스트를 추가해
    `V14 -> V15` 경계를 고정한다.
- **Verification**:
  - 관련 test file compile 확인
  - 기존 stale V14 assumption 제거

### Step 3: Validate and document

- **Files**: build/test scripts invocation, solution doc
- **Changes**:
  - `scripts/build-ios.sh` 실행
  - 가능한 범위에서 targeted test 또는 compile verification 수행
  - 최종 원인과 residual risk를 solution doc에 기록한다.
- **Verification**:
  - build 결과 확보
  - review/compound 단계에 필요한 evidence 정리

## Edge Cases

| Case | Handling |
|------|----------|
| top-level error에 `NSUnderlyingErrorKey`가 없음 | wrapper domain/description 기반 heuristics를 추가하되 migration-specific signature로만 제한 |
| 실제로는 permission 또는 CloudKit 오류인데 wrapper domain만 `SwiftDataError`인 경우 | migration signature 없으면 기존처럼 store 보존 |
| V15 current schema guard만 통과하고 persisted reopen이 빠지는 경우 | `V14 -> V15` reopen test를 우선 고려하고, test infra blocker가 있으면 명시적으로 기록 |
| detached HEAD 상태에서 구현 시작 | Work Phase에서 feature branch 생성 후 진행 |

## Testing Strategy

- Unit tests: `DUNETests/PersistentStoreRecoveryTests.swift`에 wrapped migration error 케이스 추가
- Unit tests: `DUNETests/AppMigrationPlanTests.swift`에 V15 latest schema / `HourlyScoreSnapshot` / optional reopen guard 추가
- Build: `scripts/build-ios.sh`
- Manual verification:
  - migration-failed persistent store가 있을 때 delete → recreate 경로로 회복되는지 로그 확인
  - 앱 재실행 시 in-memory fallback만 반복되지 않는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| wrapper heuristic가 너무 넓어 non-migration failure를 purge | medium | high | migration-specific phrase와 existing test suite로 범위 제한 |
| unrelated `DUNETests` compile failure로 targeted test 실행이 막힘 | high | medium | build script를 우선 gate로 사용하고 test blocker를 명시 기록 |
| 실제 orphan checksum이 current schema mismatch라 delete 후에도 실패 | low | high | current schema alignment test를 갱신하고 bare in-memory fallback path는 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 런타임 로그가 recovery misclassification을 직접 보여주고 있고, git 이력상 V15 이후 persisted model delta가 없어 schema bump보다 recovery fix가 더 타당하다. 남은 불확실성은 test infra blocker와 실제 top-level SwiftData error bridge 형태인데, 둘 다 unit test + logging으로 빠르게 검증 가능하다.
