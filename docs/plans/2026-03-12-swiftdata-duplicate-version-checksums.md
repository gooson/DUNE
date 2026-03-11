---
topic: swiftdata duplicate version checksums
date: 2026-03-12
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-12-mac-swiftdata-migration-refresh-stability.md
  - docs/solutions/architecture/2026-03-12-set-rpe-integration.md
  - docs/solutions/general/2026-03-04-habit-recurring-start-point.md
related_brainstorms:
  - docs/brainstorms/2026-03-07-preferred-exercise-ordering.md
  - docs/brainstorms/2026-03-04-cardio-full-measurement-tracking.md
---

# Implementation Plan: SwiftData Duplicate Version Checksums

## Context

`ModelContainer` 생성 시 `Duplicate version checksums across stages detected.` 크래시가 발생한다.
현재 `AppSchemaV12`, `AppSchemaV13`, `AppSchemaV14`의 역할이 merge 과정에서 뒤섞여,
인접 migration stage가 서로 다른 버전 번호를 갖지만 실질적으로 같은 checksum을 만들고 있다.

## Requirements

### Functional

- `AppMigrationPlan`이 중복 checksum 없이 `ModelContainer`를 정상 생성해야 한다.
- `ExerciseDefaultRecord.isPreferred` 도입 단계와 `WorkoutSet.rpe` 도입 단계를 서로 다른 schema checksum으로 분리해야 한다.
- 회귀를 막기 위해 migration plan 테스트를 갱신해야 한다.

### Non-functional

- 기존 배포 store의 staged migration 경로를 보존해야 한다.
- 수정은 `AppSchemaVersions.swift`와 관련 테스트에 국한한다.
- 검증은 최소 빌드 + targeted test로 수행한다.

## Approach

`V12`를 pre-`isPreferred` snapshot schema로 복구하고, `V13`은 live `ExerciseDefaultRecord` + pre-`rpe` `WorkoutSet` snapshot으로 유지한다.
`V14`는 live `WorkoutSet`을 사용해 set-level RPE 도입 버전으로 둔다.
이렇게 하면 `V12 -> V13`은 preferred flag 도입, `V13 -> V14`는 set-level RPE 도입으로 분리된다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `V13`을 live schema로 되돌리고 `V14` 제거 | 단순함 | 이미 선언된 V14 migration 경로를 없애며 merge 이후 버전 이력을 다시 바꿔야 함 | 기각 |
| `V12`와 `V13` 중 하나만 snapshot 유지 | 변경량 적음 | preferred flag와 set-level RPE 중 하나의 checksum 분리가 다시 사라짐 | 기각 |
| `V12`에 ExerciseDefaultRecord snapshot, `V13`에 WorkoutSet snapshot 유지 | 기존 의도와 배포 경로를 모두 보존 | 테스트도 함께 갱신 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift` | modify | `V12`/`V13`/`V14` schema 역할 재정렬, snapshot 타입 복구 |
| `DUNETests/AppMigrationPlanTests.swift` | modify | 최신 schema expectations 갱신, snapshot invariants 및 container init 회귀 테스트 추가 |

## Implementation Steps

### Step 1: Restore distinct schema snapshots

- **Files**: `DUNE/Data/Persistence/Migration/AppSchemaVersions.swift`
- **Changes**: `AppSchemaV12`에 pre-`isPreferred` `ExerciseDefaultRecord` snapshot 추가, `models` 배열을 snapshot 타입 기준으로 정렬, 주석을 실제 의미에 맞게 정리
- **Verification**: `AppSchemaV12`/`V13`/`V14`가 각각 다른 snapshot/live 조합을 사용함을 코드상 확인

### Step 2: Update migration tests

- **Files**: `DUNETests/AppMigrationPlanTests.swift`
- **Changes**: latest schema를 `V14` 기준으로 갱신하고, `V12`/`V13`/`V14` snapshot invariants와 in-memory `ModelContainer` 생성 테스트 추가
- **Verification**: targeted unit test에서 duplicate checksum 크래시 없이 container 생성 통과

### Step 3: Validate build and targeted test

- **Files**: 없음
- **Changes**: `scripts/build-ios.sh`와 `xcodebuild test ... -only-testing:DUNETests/AppMigrationPlanTests` 실행
- **Verification**: build 성공, targeted test 성공

## Edge Cases

| Case | Handling |
|------|----------|
| 기존 store가 pre-`isPreferred` 상태인 경우 | `V12` snapshot으로 checksum을 보존해 `V12 -> V13` 경로 유지 |
| 기존 store가 pre-`rpe` preferred-exercise 상태인 경우 | `V13` snapshot으로 checksum을 고정해 `V13 -> V14` 경로 유지 |
| 테스트가 단순 타입 비교만으로는 회귀를 놓치는 경우 | 실제 `ModelContainer` 생성 테스트를 추가해 runtime crash를 직접 잡음 |

## Testing Strategy

- Unit tests: `AppMigrationPlanTests`에 latest schema / snapshot invariant / in-memory container init 테스트 추가
- Integration tests: 없음
- Manual verification: 앱 실행 시 `makeModelContainer(configuration:)` 경로에서 crash 재발 여부 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 과거 배포 checksum과 snapshot 정의가 완전히 일치하지 않을 수 있음 | medium | high | 기존 solution 문서와 commit history 기준으로 snapshot 필드를 배포 시점과 맞춘다 |
| 추가된 테스트가 환경 의존적으로 flaky할 수 있음 | low | medium | in-memory configuration으로 store I/O 의존성을 제거한다 |
| detached HEAD 상태에서 후속 ship 자동화가 제한될 수 있음 | medium | low | 수정/검증 완료 후 branch/ship 단계는 현재 git 상태 기준으로 명시적으로 보고한다 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 현재 크래시 원인이 V12/V13/V14 schema drift로 좁혀졌고, 과거 commit/solution 문서가 intended layout을 명확히 보여준다.
