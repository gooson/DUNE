---
topic: watch-quickstart-procedure-memory-levelup
date: 2026-03-15
status: draft
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-07-workout-session-progressive-overload-and-levelup.md
  - docs/solutions/general/2026-02-26-quickstart-ia-usage-tracking-consistency.md
related_brainstorms:
  - docs/brainstorms/2026-03-15-watch-quickstart-procedure-memory-levelup.md
  - docs/brainstorms/2026-03-07-workout-procedure-levelup-progression.md
---

# Implementation Plan: Watch Quick Start Procedure Memory + Level-Up Integration

## Context

Watch Quick Start는 현재 최근 사용 순서와 마지막 세트의 weight/reps만 기억한다. 사용자는 같은 운동을 다시 선택했을 때 마지막 완료 세션의 `세트별 무게/횟수`와 `총 세트 수`를 그대로 복원받길 원하며, 기존 iPhone 쪽 progression/level-up 정책과도 일관되게 동작해야 한다.

현재 코드베이스에서 재사용 가능한 기반은 다음과 같다.
- Watch local persistence: `RecentExerciseTracker`
- Watch sync payload: `WatchExerciseInfo` + `WatchExerciseLibraryPayloadBuilder`
- iPhone progression policy: `WorkoutSessionViewModel`
- Watch start flow: `snapshotFromExercise` → `WorkoutPreviewView` → `WorkoutManager`/`MetricsView`

핵심은 CloudKit persisted `TemplateEntry`를 건드리지 않고, watch-only snapshot과 WatchConnectivity metadata를 확장해 절차 기억을 추가하는 것이다.

## Requirements

### Functional

- Quick Start 동일 운동 재시작 시 마지막 완료 세션 1개의 세트별 weight/reps를 복원한다.
- 변형 운동은 별개 운동으로 취급한다. exact exercise ID 기준으로 저장/조회한다.
- 총 세트 수를 마지막 완료 세션 기준으로 복원한다.
- 한 세트도 완료하지 않고 종료한 세션은 저장하지 않는다.
- 기록이 없으면 기존 defaultSets/defaultReps/defaultWeight fallback을 유지한다.
- 기존 progression 규칙을 Quick Start 복원 흐름에 통합한다.
  - 다음 세션 시작 시 첫 세트 증량 추천 반영
- iPhone persisted history에서 내려온 metadata와 watch local history가 모두 복원에 기여해야 한다.

### Non-functional

- 기존 recent/preferred/popular 정렬 규칙과 canonical usage 집계를 깨지 않는다.
- `WatchExerciseInfo` payload 확장은 backward compatible decode를 유지해야 한다.
- SwiftData/CloudKit persisted template schema는 변경하지 않는다.
- watch-only 로직 변경에 대응하는 unit tests를 반드시 추가한다.

## Approach

`RecentExerciseTracker`와 `WatchExerciseInfo`/payload builder를 확장해 exact-ID 기반 procedure snapshot을 추가한다. watch는 로컬 snapshot을 우선 사용하고, 로컬 데이터가 없으면 iPhone sync payload의 procedure metadata를 fallback으로 사용한다. Quick Start 시작 시 이 procedure snapshot을 watch-only `WorkoutSessionTemplate`의 per-set plan으로 변환하고, 기존 progression increment 정책에 따라 첫 세트 추천 무게를 overlay 한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `TemplateEntry`에 per-set 절차 필드 추가 | 기존 preview/session 파이프라인 재사용 폭이 큼 | CloudKit persisted contract 변경 리스크가 큼 | Rejected |
| 별도 watch/iPhone procedure store + 신규 DTO 생성 | 개념 분리 명확 | 현재 tracker/payload 패턴과 중복, 영향 범위 확대 | Rejected |
| `RecentExerciseTracker` + `WatchExerciseInfo` optional metadata + watch-only `WorkoutSessionTemplate` 확장 | 기존 fallback 계층과 테스트 패턴을 그대로 재사용, migration 리스크 낮음 | watch/iPhone 양쪽 helper 조정 필요 | Selected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Models/WatchConnectivityModels.swift` | Modify | exact procedure snapshot + progression metadata를 `WatchExerciseInfo`에 optional 필드로 추가 |
| `DUNE/Data/WatchConnectivity/WatchExerciseLibraryPayloadBuilder.swift` | Modify | iPhone `ExerciseRecord.completedSets` 기반 exact procedure snapshot과 progression metadata 집계 |
| `DUNEWatch/Managers/RecentExerciseTracker.swift` | Modify | watch local exact-ID procedure snapshot 저장/조회 추가 |
| `DUNEWatch/Helpers/WatchExerciseHelpers.swift` | Modify | procedure snapshot 우선 조회, total sets/세트별 계획 복원, first-set progression overlay 적용 |
| `DUNEWatch/Managers/WorkoutManager.swift` | Modify | watch-only `WorkoutSessionTemplate`에 per-set plan metadata 추가 및 현재 세트 계획 조회 helper 제공 |
| `DUNEWatch/Views/MetricsView.swift` | Modify | current set prefill 시 per-set plan → last completed set → entry default 우선순위 적용 |
| `DUNEWatch/Views/SessionSummaryView.swift` | Modify | 완료 세트가 있을 때 exact procedure snapshot 저장 경로 추가 |
| `DUNEWatch/Views/QuickStartAllExercisesView.swift` | Modify | new payload metadata를 invalidation key에 반영 |
| `DUNEWatch/Views/CarouselHomeView.swift` | Modify | new payload metadata를 invalidation key/표시 계산에 반영 |
| `DUNETests/WatchExerciseLibraryPayloadBuilderTests.swift` | Modify | exact procedure snapshot 집계 + defaults-only retention + progression metadata 회귀 테스트 추가 |
| `DUNETests/DomainModelCoverageTests.swift` | Modify | `WatchExerciseInfo` round-trip/backward compatibility 테스트 확장 |
| `DUNEWatchTests/RecentExerciseTrackerTests.swift` | Modify | procedure snapshot exact-ID 저장/조회 테스트 추가 |
| `DUNEWatchTests/WatchExerciseHelpersTests.swift` | Modify | local-vs-synced fallback, total set restore, first-set progression overlay 테스트 추가 |
| `DUNEWatchTests/WatchExerciseInfoHashableTests.swift` | Modify | 구버전 payload decode 시 새 필드 기본값 회귀 테스트 추가 |

## Implementation Steps

### Step 1: Shared payload + watch-local procedure snapshot contract 추가

- **Files**: `WatchConnectivityModels.swift`, `RecentExerciseTracker.swift`
- **Changes**:
  - per-set snapshot DTO를 추가한다.
  - `WatchExerciseInfo`에 optional procedure metadata와 progression increment metadata를 추가한다.
  - `RecentExerciseTracker`에 latest set과 별도로 exact-ID procedure snapshot 저장/조회 API를 추가한다.
- **Verification**:
  - legacy decode가 nil/default로 안전하게 동작한다.
  - exact-ID snapshot이 variant와 섞이지 않는다.

### Step 2: iPhone payload builder가 persisted history에서 procedure metadata를 생성

- **Files**: `WatchExerciseLibraryPayloadBuilder.swift`, 관련 tests
- **Changes**:
  - canonical usage/defaults 집계는 유지한다.
  - exact exercise ID 기준으로 최신 `ExerciseRecord`의 completed sets를 procedure snapshot으로 추출한다.
  - exercise definition 기반 progression increment metadata를 함께 내려준다.
  - defaults-only payload rebuild 시 기존 procedure metadata를 유지한다.
- **Verification**:
  - latest exact session만 payload에 반영된다.
  - variant끼리 procedure가 합쳐지지 않는다.
  - defaults-only sync가 procedure metadata를 덮어쓰지 않는다.

### Step 3: Watch Quick Start snapshot 복원 경로 확장

- **Files**: `WatchExerciseHelpers.swift`, `WorkoutManager.swift`, `MetricsView.swift`, `QuickStartAllExercisesView.swift`, `CarouselHomeView.swift`
- **Changes**:
  - helper가 procedure snapshot을 `local exact snapshot -> synced payload snapshot -> latest set/default` 순으로 해석한다.
  - `WorkoutSessionTemplate`에 watch-only per-set plan metadata를 추가한다.
  - `snapshotFromExercise`가 total sets와 세트별 기본값을 procedure snapshot에서 생성한다.
  - `MetricsView.prefillFromEntry()`가 현재 세트 번호에 맞는 planned weight/reps를 우선 사용한다.
  - exercise list invalidation key와 subtitle 계산이 procedure metadata 반영 후 다시 그려지게 조정한다.
- **Verification**:
  - 다음 Quick Start 시작 시 1세트/2세트/3세트가 각각 이전 절차대로 채워진다.
  - extra set로 종료한 경우 총 세트 수도 같이 복원된다.

### Step 4: Session save 시 local procedure snapshot 기록 + progression overlay 적용

- **Files**: `SessionSummaryView.swift`, `WatchExerciseHelpers.swift`, tests
- **Changes**:
  - 완료 세트가 1개 이상일 때만 exact procedure snapshot을 저장한다.
  - first-set progression overlay helper를 추가해 기존 increment 정책(+5/+2.5/+1, 10% cap, plate rounding)을 watch에서도 동일하게 적용한다.
  - overlay는 raw history를 변경하지 않고 다음 Quick Start plan 생성 시에만 반영한다.
- **Verification**:
  - 세트 0개 종료 시 저장되지 않는다.
  - completed procedure는 raw 값으로 남고, next session plan에서만 첫 세트가 증량된다.

## Edge Cases

| Case | Handling |
|------|----------|
| local watch history 없음, synced payload만 있음 | synced procedure snapshot fallback 사용 |
| synced payload 없음, local watch history만 있음 | local procedure snapshot 사용 |
| variant 운동 (`tempo`, `paused`) | exact exercise ID 기준 저장/조회로 분리 |
| extra set 추가 후 종료 | completed set count 전체를 procedure snapshot에 저장 |
| 한 세트도 완료하지 않고 종료 | snapshot 미저장, 기존 defaults 유지 |
| cardio exercise | 기존 cardio path 유지, strength-like exercise에만 procedure/overload 적용 |
| 구버전 payload decode | 새 optional 필드는 nil/default로 해석 |

## Testing Strategy

- Unit tests:
  - `DUNETests/WatchExerciseLibraryPayloadBuilderTests.swift`
  - `DUNETests/DomainModelCoverageTests.swift`
  - `DUNEWatchTests/RecentExerciseTrackerTests.swift`
  - `DUNEWatchTests/WatchExerciseHelpersTests.swift`
  - `DUNEWatchTests/WatchExerciseInfoHashableTests.swift`
- Build verification:
  - `scripts/build-ios.sh`
- Targeted validation:
  - `swift test` or project test target for the modified watch/iOS unit suites if build-only gate is insufficient
- Manual verification:
  - watch Quick Start에서 동일 운동 시작 → 세트별 weight/reps/총 세트 수 복원 확인
  - 세트 추가 후 종료 → 다음 시작 시 추가 세트까지 복원 확인
  - 기록 없는 운동 → defaults fallback 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| procedure metadata 추가로 payload backward compatibility가 깨짐 | Low | High | optional/default decode + round-trip tests 추가 |
| watch local snapshot과 synced payload가 충돌 | Medium | Medium | local 우선, synced fallback, timestamp는 snapshot 내부에 유지 |
| progression overlay가 “그대로 복원” 기대와 충돌 | Medium | Medium | raw procedure는 유지하고 next session plan에서만 first-set overlay 적용 |
| watch-only `WorkoutSessionTemplate` 확장이 preview/navigation equality에 예상치 못한 영향 | Low | Medium | Hashable contract 유지, targeted quick start smoke/manual 확인 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 tracker/payload/quick-start flow를 재사용하므로 구조적 리스크는 낮다. 다만 watch-only session prefill에 per-set plan을 주입하는 경로와, exact procedure snapshot을 synced metadata와 local state로 함께 다루는 부분은 회귀 테스트와 manual verification이 중요하다.
