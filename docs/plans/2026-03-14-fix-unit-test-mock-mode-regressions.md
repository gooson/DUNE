---
topic: fix-unit-test-mock-mode-regressions
date: 2026-03-14
status: implemented
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-08-simulator-advanced-mock-data.md
related_brainstorms: []
---

# Implementation Plan: Unit Test Mock Mode Regressions

## Context

`DUNETests`에서 simulator advanced mock data 관련 테스트 4개가 동시에 깨지고, 별도로 `TrainingVolumeViewModel`의 "already loading" guard 테스트도 실패하고 있다. 현재 구현은 `SimulatorAdvancedMockDataModeStore.isSimulatorAvailable`이 compile-time simulator 환경에만 열려 있어서, 테스트가 `My Mac` 또는 simulator가 아닌 대상에서 실행되면 mock mode가 완전히 비활성화된다. 이 상태에서는 persisted reference date가 저장되지 않고, query service가 mock dataset 대신 실제 HealthKit 경로로 빠지며, mirror snapshot service도 빈 snapshot을 반환한다.

## Requirements

### Functional

- simulator advanced mock data 관련 unit tests가 실행 대상과 무관하게 deterministic하게 동작해야 한다.
- mock mode가 활성화되면 persisted reference date와 query fallback이 기존 기대값을 유지해야 한다.
- `TrainingVolumeViewModel.loadData(manualRecords:)`는 이미 로딩 중일 때 즉시 return 해야 한다.

### Non-functional

- production runtime에서 simulator-only UX와 seeded mock 진입점의 동작 의미를 바꾸지 않는다.
- 테스트 훅은 최소 범위로 노출하고, test 간 상태 누수를 막는다.
- 기존 solution doc와 현재 mock dataset shape(workouts 10개, fetchedAt 고정)를 유지한다.

## Approach

`SimulatorAdvancedMockDataModeStore`가 XCTest 런타임에서는 simulator availability를 열고, app runtime과 분리된 test-scoped `UserDefaults` suite를 사용하도록 조정한다. 이렇게 하면 기존 테스트 코드 수정 없이 mock mode persistence와 query fallback이 deterministic하게 동작한다. 별도로 `TrainingVolumeViewModel`에는 `guard !isLoading else { return }`를 추가해 중복 로드 요청을 무시하도록 맞춘다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 테스트를 simulator 전용으로 제한 | production 코드 변경 없음 | 로컬/CI 대상 편차가 계속 남고 현재 실패 원인을 해결하지 못함 | 기각 |
| `isSimulatorAvailable`를 XCTest에서 항상 true로 변경 | 구현이 단순함 | test isolation이 부족하고 defaults/state leakage 가능성이 남음 | 기각 |
| XCTest 전용 defaults suite + XCTest availability gate | 테스트 대상 편차 제거, 상태 제어 가능, production 영향 최소 | production store에 test-aware 분기 추가 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Services/SimulatorAdvancedMockData.swift` | modify | 테스트 환경 override와 isolated defaults 지원 추가 |
| `DUNETests/SimulatorAdvancedMockDataTests.swift` | verify | 기존 테스트가 new test-scoped defaults 경로에서도 그대로 통과하는지 검증 |
| `DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift` | modify | 중복 load guard 복원 |
| `DUNETests/TrainingVolumeViewModelTests.swift` | verify | existing expectation과 구현 일치 여부 검증 |

## Implementation Steps

### Step 1: Stabilize simulator advanced mock mode for tests

- **Files**: `DUNE/Data/Services/SimulatorAdvancedMockData.swift`
- **Changes**: XCTest 런타임에서 simulator gate를 열고 test-scoped defaults suite를 사용하도록 조정한다.
- **Verification**: `SimulatorAdvancedMockDataTests`에서 `isEnabled`, `referenceDate`, `workouts.count`, `snapshot.fetchedAt` 기대값이 모두 통과한다.

### Step 2: Restore loading guard semantics

- **Files**: `DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift`
- **Changes**: 이미 로딩 중인 경우 추가 `loadData` 호출을 무시하는 guard를 추가한다.
- **Verification**: `TrainingVolumeViewModelTests/isLoadingGuard`가 `isLoading == true`, `comparison == nil`을 유지한다.

### Step 3: Run targeted and broader unit verification

- **Files**: 없음
- **Changes**: 관련 테스트 스위트를 실행해 회귀 여부를 확인한다.
- **Verification**: `SimulatorAdvancedMockDataTests`, `TrainingVolumeViewModelTests`, 가능하면 `DUNETests` 전체 또는 `scripts/test-unit.sh --ios-only --no-regen --no-stream-log`.

## Edge Cases

| Case | Handling |
|------|----------|
| 테스트가 iOS simulator가 아니라 `My Mac` 대상에서 실행됨 | XCTest 런타임에서는 simulator gate를 열어 mock mode 경로를 유지 |
| standard defaults에 남은 기존 mock state가 새 테스트에 영향을 줌 | XCTest 전용 defaults suite로 app runtime state와 분리 |
| production UI가 non-simulator 환경에서 mock section을 노출할 위험 | 일반 런타임은 기존 simulator gate를 유지하고 XCTest에서만 분기 |
| overlapping load 요청 중 첫 요청 결과가 늦게 도착 | existing requestID 기반 stale-result guard 유지 |

## Testing Strategy

- Unit tests: `SimulatorAdvancedMockDataTests`, `TrainingVolumeViewModelTests`
- Integration tests: 가능하면 `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests ... -only-testing DUNETests`
- Manual verification: 없음

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| test-aware branch가 production runtime behavior를 흔듦 | low | medium | 일반 런타임은 기존 simulator gate를 유지하고 XCTest에서만 defaults suite를 분리 |
| test-scoped suite 이름이 세션마다 달라 stale domain이 쌓일 수 있음 | low | low | deterministic hash로 suite 이름을 고정하고 random `hashValue` 사용을 피함 |
| loading guard 복원이 실제 refresh UX를 막음 | low | low | guard는 이미 `isLoading == true`인 동일 viewmodel 호출에만 적용되고 async refresh path는 별도 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 사용자 제공 4개 mock-mode 실패는 모두 동일한 availability gate에서 설명되고, `TrainingVolumeViewModel` 실패는 구현과 테스트의 계약 불일치가 명확하다.
