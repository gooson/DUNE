---
tags: [ios, xctest, healthkit, ui-test, test-flakiness]
category: testing
date: 2026-02-23
severity: important
related_files:
  - DailveUITests/HealthKitPermissionUITests.swift
  - Dailve/Presentation/Dashboard/DashboardViewModel.swift
  - Dailve/App/DailveApp.swift
related_solutions:
  - docs/solutions/architecture/2026-02-22-cloudkit-date-roundtrip-validation.md
---

# Solution: Gate HealthKit Permission UI Test To Manual Runs

## Problem

HealthKit 권한 승인 UI 테스트가 기본 테스트 스위트에 포함되면서 CI/로컬 자동 실행에서 장시간 대기 상태가 발생했다.

### Symptoms

- 전체 `xcodebuild test` 실행 시 HealthKit 권한 화면에서 테스트가 멈추거나 매우 오래 대기
- 시스템 권한 alert 타이밍에 따라 간헐적인 flaky 실패

### Root Cause

`HealthKitPermissionUITests`가 기본 실행 대상이었고, 권한 승인 흐름 자체가 수동 개입/환경 상태에 영향을 크게 받는 시나리오라 자동 회귀 테스트에 부적합했다. 또한 고정 `sleep()` 대기로 alert 타이밍 편차를 흡수하려 하면서 실행 시간이 불필요하게 늘고 불안정성이 커졌다.

## Solution

권한 UI 테스트를 "수동 실행 전용"으로 명시하고, 기본 실행에서는 skip 하도록 변경했다. 동시에 `sleep()` 기반 대기를 제거하고 `waitForExistence` 기반으로 시트를 처리하도록 정리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DailveUITests/HealthKitPermissionUITests.swift` | `RUN_HEALTHKIT_PERMISSION_UI_TEST=1` 또는 `--run-healthkit-permission-uitest`일 때만 실행, 기본은 `XCTSkip` | 자동 테스트 정체 방지 |
| `DailveUITests/HealthKitPermissionUITests.swift` | `sleep()` 제거, `waitForExistence` + helper 분리 | 타이밍 의존성 완화 |
| `Dailve/App/DailveApp.swift` | XCTest 감지 시 consent/watch activation 비활성화 유지, 미사용 `@AppStorage` 제거 | 테스트 부트스트랩 단순화 |
| `Dailve/Presentation/Dashboard/DashboardViewModel.swift` | XCTest 환경 기본 권한 요청 우회 (전용 권한 UI 테스트는 예외) | 비권한 테스트 경로 안정화 |

### Key Code

```swift
guard Self.shouldRunManualPermissionFlow else {
    throw XCTSkip("Manual-only test. Set RUN_HEALTHKIT_PERMISSION_UI_TEST=1 to run.")
}
```

## Prevention

권한/시스템 alert 기반 UI 테스트는 기본 회귀 테스트에서 제외하고, 수동 또는 별도 파이프라인에서 명시적으로 실행한다.

### Checklist Addition

- [ ] 시스템 권한/설정 의존 UI 테스트는 기본 suite에 자동 포함하지 않는다.
- [ ] UI 테스트에서 `sleep()` 대신 `waitForExistence` 또는 expectation 기반 대기를 사용한다.

### Rule Addition (if applicable)

기존 `.claude/skills/ui-testing/SKILL.md` anti-pattern(`sleep()` 금지)과 일치하도록 유지한다.

## Lessons Learned

권한 승인처럼 외부 상태(시뮬레이터 설정, OS alert)에 강하게 의존하는 테스트는 신뢰도보다 정체 위험이 더 크다. 이런 테스트는 "항상 실행"보다 "의도적으로 실행"이 더 안전하며, 자동 회귀에서는 deterministic 경로를 우선해야 한다.
