---
tags: [unit-test, simulator-mock, host-parity, userdefaults, loading-guard]
category: testing
date: 2026-03-14
severity: important
related_files:
  - DUNE/Data/Services/SimulatorAdvancedMockData.swift
  - DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift
  - DUNETests/SimulatorAdvancedMockDataTests.swift
  - DUNETests/TrainingVolumeViewModelTests.swift
related_solutions:
  - docs/solutions/general/2026-03-08-simulator-advanced-mock-data.md
  - docs/solutions/testing/2026-03-08-training-load-daily-volume-scroll-history.md
  - docs/solutions/testing/2026-03-14-unit-test-regression-fix.md
---

# Solution: Simulator Mock Host Parity And Loading Guard

## Problem

`DUNETests`에서 simulator advanced mock data 관련 테스트 4개와
`TrainingVolumeViewModel`의 loading guard 테스트가 동시에 깨졌다. 테스트를
`My Mac` 대상으로 실행하면 simulator-only mock mode가 완전히 꺼지고, query service가
실데이터 경로로 빠지면서 기대값이 모두 흔들렸다.

### Symptoms

- `SimulatorAdvancedMockDataModeStore.isEnabled` 가 `false`로 남아 seed test 실패
- mock workout query가 10개 대신 실제 HealthKit 데이터(예: 107개)를 반환
- mirrored snapshot service가 persisted reference date 대신 `nowProvider` 기준 빈 snapshot 반환
- `TrainingVolumeViewModel.loadData(manualRecords:)`가 이미 로딩 중이어도 다시 진입

### Root Cause

- `SimulatorAdvancedMockDataModeStore.isSimulatorAvailable`가 compile-time simulator 환경에만
  묶여 있어서 XCTest host(`My Mac`)에서는 mock mode persistence 자체가 비활성화되었다.
- mock mode state가 app runtime 기본 `UserDefaults.standard`에 의존해 host/runtime parity가 깨질
  여지가 있었다.
- `TrainingVolumeViewModel.loadData(manualRecords:)`에서 `isLoading` early-return guard가
  빠져 테스트가 보장하던 contract와 구현이 어긋났다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Services/SimulatorAdvancedMockData.swift` | XCTest 런타임에서는 simulator availability를 열고 test-scoped `UserDefaults` suite를 사용하도록 조정 | host target에서도 mock mode persistence와 query fallback을 deterministic하게 유지 |
| `DUNE/Data/Services/SimulatorAdvancedMockData.swift` | test suite name에 deterministic hash 사용 | process-random `hashValue`로 인한 preference domain 누적 방지 |
| `DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeViewModel.swift` | `guard !isLoading else { return }` 복원 | overlapping load 요청이 state contract를 깨지 않도록 보장 |

### Key Code

```swift
private static var currentDefaults: UserDefaults {
    guard isRunningXCTest else { return .standard }
    return UserDefaults(suiteName: unitTestDefaultsSuiteName) ?? .standard
}

static var isSimulatorAvailable: Bool {
#if targetEnvironment(simulator)
    true
#else
    isRunningXCTest
#endif
}

func loadData(manualRecords: [ExerciseRecord]) async {
    guard !isLoading else { return }
    ...
}
```

## Prevention

### Checklist Addition

- [ ] simulator-only feature test는 host XCTest에서도 동작할지, state 저장소가 app runtime과 분리되는지 함께 확인한다
- [ ] `loadData`/`refresh` entry point는 `isLoading` guard contract를 테스트와 코드 양쪽에 같이 고정한다

### Rule Addition (if applicable)

기존 `testing-required.md`와 `testing-patterns` 범위에서 커버 가능해서 별도 rule 추가는 하지 않았다.

## Lessons Learned

1. simulator-only 테스트 실패가 여러 개 한꺼번에 보이면 query service 자체보다 availability gate를 먼저 의심하는 편이 빠르다.
2. unit test host와 실제 simulator runtime을 분리하지 않으면 `UserDefaults.standard` 같은 persisted state가 회귀 원인을 숨기거나 증폭시킨다.
3. view model loading contract는 비동기 stale-result 방어와 별개로, 재진입 가드 자체를 명시적으로 유지해야 한다.
