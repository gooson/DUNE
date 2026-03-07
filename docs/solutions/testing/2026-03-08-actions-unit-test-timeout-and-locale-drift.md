---
tags: [testing, ci, github-actions, xctest, cloud-sync, localization, watch]
category: testing
date: 2026-03-08
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNETests/WellnessViewModelTests.swift
  - DUNETests/WorkoutSessionViewModelTests.swift
  - DUNEWatchTests/WatchExerciseHelpersTests.swift
related_solutions:
  - docs/solutions/testing/2026-02-23-healthkit-permission-ui-test-gating.md
  - docs/solutions/testing/2026-03-02-locale-safe-validation-format-tests.md
---

# Solution: Actions Unit Test Timeout and Locale Drift Fix

## Problem

GitHub Actions unit-test job가 assertion failure를 보여주기 전에 30분 타임아웃으로 종료됐다. bootstrap 문제를 제거하자 실제 expectation drift가 iOS/watch 테스트에서 연이어 드러났다.

### Symptoms

- Actions job `66143968283`가 `xcodebuild test` 이후 test suite를 시작하지 못한 채 30분 제한에 걸렸다.
- `HealthSnapshotMirrorContainerFactoryTests` host app launch 중 `SyncedDefaults`/iCloud 계열 로그가 찍히며 시작이 지연됐다.
- 이후 `WellnessViewModelTests`, `WorkoutSessionViewModelTests`, `WatchExerciseHelpersTests`가 현재 구현과 다른 기대값으로 실패했다.

### Root Cause

`DUNETests`는 host app으로 `DUNEApp`를 띄우는데, 앱 초기화가 XCTest 환경에서도 `CloudSyncPreferenceStore.resolvedValue()`를 호출해 `NSUbiquitousKeyValueStore` 동기화 경로를 건드리고 있었다. CI처럼 iCloud account가 없는 환경에서는 이 bootstrap side effect가 test start 이전 launch를 불안정하게 만들었다.

남은 실패는 테스트 drift였다. VO2 max card는 현재 `activeCards`에 노출되는데 테스트는 `physicalCards`를 보고 있었고, overload cap 테스트는 barbell 반올림 규칙이 적용되는 helper로 dumbbell 기대값을 검증하고 있었다. watch helper 테스트도 localized 문자열과 normalized `ExerciseInputType` raw value 대신 legacy 영문/alias를 기대하고 있었다.

## Solution

XCTest 부팅 시 cloud-sync preference 해석을 완전히 건너뛰고, 나머지 테스트는 현재 제품 동작에 맞게 기대값을 정렬했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/DUNEApp.swift` | XCTest 실행 중에는 `CloudSyncPreferenceStore.resolvedValue()`를 호출하지 않도록 guard 추가 | host app launch에서 iCloud KVS bootstrap side effect 제거 |
| `DUNETests/WellnessViewModelTests.swift` | VO2 max assertion 대상을 `activeCards`로 변경 | 현재 card 분류와 테스트 기대값 정렬 |
| `DUNETests/WorkoutSessionViewModelTests.swift` | helper에 `equipment` 주입 추가, 10% cap 테스트는 `.dumbbell` 사용 | barbell plate rounding과 dumbbell overload 규칙 분리 |
| `DUNEWatchTests/WatchExerciseHelpersTests.swift` | localized subtitle/meta expectation 및 canonical `ExerciseInputType` raw value 사용 | locale/legacy alias 의존 제거 |

### Key Code

```swift
let cloudSyncEnabled = Self.isRunningXCTest
    ? false
    : CloudSyncPreferenceStore.resolvedValue()

let expectedBase = String(localized: "\(3) sets · \(10) reps")
#expect(entry.inputTypeRaw == ExerciseInputType.durationDistance.rawValue)
```

## Prevention

### Checklist Addition

- [ ] XCTest host app bootstrap은 iCloud KVS, WatchConnectivity activation, remote sync처럼 외부 상태 의존 side effect 없이 시작되는지 확인한다.
- [ ] 사용자 노출 문자열 테스트는 영문 하드코딩 대신 `String(localized:)` 또는 locale-independent helper 기준으로 검증한다.
- [ ] persisted enum/raw value 테스트는 legacy alias가 아니라 현재 canonical `rawValue`를 기준으로 검증한다.
- [ ] shared test helper 기본값이 도메인 규칙(barbell rounding 등)을 암묵적으로 끌어오지 않는지 확인한다.

### Rule Addition (if applicable)

active correction에 XCTest bootstrap/i18n expectation 관련 항목을 추가했다. 반복되면 `testing-required.md` 또는 별도 test-bootstrap rule로 승격한다.

## Lessons Learned

CI 타임아웃은 실제 assertion failure보다 앞단의 host app bootstrap side effect에서 시작될 수 있다. 테스트가 아예 시작되지 않는다면 production code bug만 볼 게 아니라, test host가 launch 시 외부 sync를 건드리는지 먼저 의심해야 한다. 또 watch/i18n 관련 테스트는 영문 literal이나 legacy raw alias보다 현재 localization/normalization contract에 맞춰 써야 장기적으로 안정적이다.
