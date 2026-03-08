---
tags: [swift-6, mainactor, xctest, ui-test, override, setupwitherror]
category: testing
date: 2026-03-08
severity: important
related_files:
  - DUNEUITests/Regression/ChartInteractionRegressionUITests.swift
  - DUNEUITests/Helpers/UITestBaseCase.swift
  - docs/plans/2026-03-08-ui-test-override-actor-isolation-fix.md
related_solutions:
  - docs/solutions/architecture/2026-02-28-ci-script-dedup-and-uitest-base-class.md
  - docs/solutions/architecture/2026-03-08-launch-argument-mainactor-isolation.md
  - docs/solutions/general/2026-03-08-chart-long-press-scroll-regression.md
---

# Solution: UI Test Override Actor Isolation Fix

## Problem

GitHub Actions `ios-ui-tests` job가 `DUNEUITests` 빌드 단계에서 멈췄다.
새로 추가된 chart regression UI test가 `setUpWithError()` override에 method-level `@MainActor`를 붙이면서,
nonisolated base override contract와 충돌하는 Swift 6 compile error가 발생했다.

### Symptoms

- `main actor-isolated instance method 'setUpWithError()' has different actor isolation from nonisolated overridden declaration`
- `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift` 컴파일 실패
- `scripts/test-ui.sh` / GitHub Actions `ios-ui-tests` job가 test 실행 전 build 단계에서 중단

### Root Cause

`ChartInteractionRegressionUITests` class 자체는 이미 `@MainActor` 였다.
그런데 `setUpWithError()` override에 다시 method-level `@MainActor`를 명시하면서,
기준 선언인 `UITestBaseCase.setUpWithError()` 와 isolation signature가 달라졌다.
Swift 6는 이 override mismatch를 컴파일 타임에 막는다.

## Solution

중복된 method-level `@MainActor` 를 제거해 override signature를 base class와 맞췄다.
클래스 레벨 `@MainActor` 는 유지되므로 UI test 내부 상호작용의 main-actor isolation은 그대로 보존된다.
추가로 `DUNEUITests` 전체에서 같은 패턴이 더 있는지 audit했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift` | `setUpWithError()` 의 method-level `@MainActor` 제거 | `UITestBaseCase` override contract와 actor isolation을 일치시키기 위해 |
| `docs/plans/2026-03-08-ui-test-override-actor-isolation-fix.md` | status를 `implemented` 로 업데이트 | pipeline 결과와 문서 상태를 맞추기 위해 |
| `docs/solutions/testing/2026-03-08-ui-test-override-actor-isolation.md` | solution 문서 추가 | 동일 Swift 6/XCTest override 패턴을 future search로 다시 찾기 위해 |

### Key Code

```swift
@MainActor
final class ChartInteractionRegressionUITests: SeededUITestBaseCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToActivity()
    }
}
```

## Prevention

UI test class에 `@MainActor` 를 붙여 둔 상태라면, `setUpWithError()` 같은 XCTest override에 method-level actor annotation을 다시 붙이지 않는다.
override는 base declaration과 같은 isolation signature를 유지하고, 필요한 isolation은 class boundary에서만 관리한다.

### Checklist Addition

- [ ] XCTest override (`setUpWithError`, `tearDownWithError`) 는 base declaration과 동일한 isolation signature인지 확인한다
- [ ] test class가 이미 `@MainActor` 면 method-level `@MainActor` 중복 선언을 피한다
- [ ] CI failure가 compile-stage인지 runtime-stage인지 먼저 구분한 뒤 최소 수정으로 해결한다
- [ ] compile fix 후에는 최소 한 번 `DUNEUITests` build gate를 다시 통과시킨다

### Rule Addition (if applicable)

새 rule 파일은 추가하지 않았다.
기존 UI test base class solution과 이 문서를 함께 참조하면 동일 패턴을 다시 찾을 수 있다.

## Lessons Learned

Swift 6에서는 “같은 의미로 보이는 `@MainActor` 중복 선언”도 override 계약을 깨면 바로 compile blocker가 된다.
XCTest 기반 UI test는 class-level isolation과 override signature를 분리해서 보는 편이 가장 안전하다.
