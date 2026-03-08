---
topic: ui-test-override-actor-isolation-fix
date: 2026-03-08
status: approved
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-08-chart-long-press-scroll-regression.md
  - docs/solutions/testing/2026-03-04-ui-test-max-hardening-and-axid-stability.md
  - docs/solutions/architecture/2026-03-08-launch-argument-mainactor-isolation.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: UI Test Override Actor Isolation Fix

## Context

GitHub Actions `ios-ui-tests` job failed on March 8, 2026 while compiling `DUNEUITests`.
The failure is not a runtime UI regression. It is a Swift 6 actor-isolation compile error:
`ChartInteractionRegressionUITests.setUpWithError()` was declared `@MainActor`, but the overridden
`UITestBaseCase.setUpWithError()` remains nonisolated, so the override contract is invalid.

## Requirements

### Functional

- `DUNEUITests` must compile again in the same CI path used by `scripts/test-ui.sh`.
- `ChartInteractionRegressionUITests` must still launch the seeded app and navigate to Activity before each test.

### Non-functional

- Keep the fix minimal and local to the failing regression test unless an audit finds the same invalid override pattern elsewhere.
- Preserve the existing `UITestBaseCase` contract so other UI tests are unaffected.
- Verify through the project script path, not ad-hoc xcodegen/xcodebuild regeneration.

## Approach

Remove the method-level `@MainActor` annotation from the override in
`ChartInteractionRegressionUITests`. The class itself is already `@MainActor`, so UI interactions
inside the test remain main-actor isolated without changing the override signature relative to the
base class.

Also audit `DUNEUITests` for other explicit `@MainActor override func setUpWithError()` declarations
to ensure the same compile failure will not reappear in a sibling test file.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Remove method-level `@MainActor` on the failing override | Minimal diff, preserves existing base-class contract, matches other UI test files | Relies on class-level isolation remaining in place | Selected |
| Mark `UITestBaseCase.setUpWithError()` as `@MainActor` | Makes the override relationship explicit for all subclasses | Broadens actor isolation on shared test infrastructure and risks new XCTest override mismatches | Rejected |
| Remove `@MainActor` from the whole regression test class | Avoids override mismatch | Weakens isolation guarantees for UI interactions across the entire suite | Rejected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift` | code | Remove the invalid method-level actor annotation while keeping setup behavior unchanged |
| `docs/plans/2026-03-08-ui-test-override-actor-isolation-fix.md` | documentation | Record plan, scope, verification, and risks for the pipeline |

## Implementation Steps

### Step 1: Fix the invalid override annotation

- **Files**: `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift`
- **Changes**: remove the explicit `@MainActor` attribute from `setUpWithError()` and keep the seeded Activity navigation logic intact
- **Verification**: the Swift compiler no longer reports an actor-isolation mismatch for that override

### Step 2: Audit sibling UI test setup overrides

- **Files**: `DUNEUITests/**/*.swift`
- **Changes**: inspect for any other explicit method-level `@MainActor` annotations on `setUpWithError()` overrides
- **Verification**: no remaining invalid override pattern is found, or any additional offenders are fixed in the same patch

### Step 3: Re-run the UI test compile path

- **Files**: none
- **Changes**: run `scripts/test-ui.sh` with a focused target or equivalent smoke path that compiles `DUNEUITests`
- **Verification**: `DUNEUITests` build passes without the previous actor-isolation error

## Edge Cases

| Case | Handling |
|------|----------|
| XCTest still treats class-level `@MainActor` as incompatible on this override | Expand the fix to the class boundary only after reproducing locally; do not broaden `UITestBaseCase` isolation first |
| Another regression test file has the same method-level annotation | Include it in the same patch so CI does not fail on the next file |
| Focused UI test execution is flaky at runtime | Treat compile success as the primary gate first, then distinguish runtime flake from compile regression |

## Testing Strategy

- Unit tests: 없음. 이번 변경은 UI test target compile fix다.
- Integration tests: `scripts/test-ui.sh --no-stream-log --only-testing DUNEUITests/ChartInteractionRegressionUITests`
- Manual verification: GitHub Actions failure line (`main actor-isolated instance method 'setUpWithError()' has different actor isolation`) no longer appears

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| XCTest + Swift 6 조합에서 class-level `@MainActor` 자체가 추가 오류를 유발할 수 있음 | low | medium | 로컬 compile path를 즉시 재실행하고, 필요 시 범위를 넓히지 않고 offending test class만 추가 조정 |
| regression test가 compile은 되지만 seeded navigation이 깨질 수 있음 | low | medium | focused UI test path로 setup 이후 test launch까지 함께 검증 |
| 다른 UI test file에 같은 pattern이 숨겨져 있음 | medium | low | `rg` audit 결과를 근거로 남은 explicit method-level annotations를 점검 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: CI 로그가 정확한 failing symbol과 원인을 제공했고, 현재 저장소의 다른 UI tests는 class-level `@MainActor`만으로 같은 setup pattern을 이미 사용하고 있다.
