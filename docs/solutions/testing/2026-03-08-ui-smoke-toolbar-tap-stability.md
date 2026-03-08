---
tags: [ui-test, xctest, smoke-test, ci, accessibility, toolbar-button, hit-testing, flake]
category: testing
date: 2026-03-08
severity: important
related_files:
  - DUNEUITests/Helpers/UITestBaseCase.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
  - DUNEUITests/Smoke/ActivitySmokeTests.swift
  - DUNEUITests/Smoke/DashboardSmokeTests.swift
  - DUNEUITests/Smoke/LifeSmokeTests.swift
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase2-today-settings-regression.md
  - docs/solutions/testing/2026-03-08-e2e-phase3-activity-exercise-regression-hardening.md
  - docs/solutions/testing/ui-test-infrastructure-design.md
---

# Solution: UI Smoke Toolbar Tap Stability

## Problem

GitHub Actions iOS UI smoke job에서 toolbar 기반 smoke test가 연속으로 실패했다.
특히 Today, Activity, Life 탭의 add/settings/what's-new 동작은 화면이 이미 떠 있어도 XCUI tap target이 불안정해서 CI에서 red가 났다.

### Symptoms

- Actions job `66175942817`에서 `ActivitySmokeTests`, `DashboardSmokeTests`, `LifeSmokeTests`가 toolbar action 직후 실패하거나 runner restart로 이어졌다.
- XCUI log에 `Tap "life-toolbar-add" Any`, `Tap "dashboard-toolbar-settings" Any` 같은 generic hit target이 반복해서 보였다.
- `testSaveEmptyHabitKeepsFormPresented`는 빈 입력 validation 자체보다 sheet save button tap 경로가 흔들렸다.
- `testTabNavigationRoundTrip`는 tab 전환 smoke여야 하는데, 한때 각 화면의 별도 anchor render 상태까지 같이 검증해 scope가 넓어질 위험이 있었다.

### Root Cause

근본 원인은 두 가지였다.

1. accessibility identifier가 존재해도 테스트가 `descendants(matching: .any)[identifier]`를 직접 눌러 `Button` 대신 `Other/Any` wrapper를 hit target으로 잡았다.
2. 새 shared helper를 도입한 뒤에도 fallback path가 caller timeout budget을 그대로 쓰지 않으면, flaky selector가 조기 실패해 helper contract 자체가 다시 불안정해질 수 있었다.

## Solution

toolbar/action selector를 공통 helper로 모으되, 항상 실제 `Button`을 먼저 찾고 fallback도 같은 timeout budget 안에서만 동작하도록 바꿨다.
동시에 smoke test는 "실제 사용자 상호작용을 안정적으로 탭한다"는 목적만 유지하고, tab round-trip은 다시 좁은 selection smoke로 정리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEUITests/Helpers/UITestHelpers.swift` | `waitAndTap(_:)` 추가, `buttons[identifier]`/`.button` descendants 우선 탐색, fallback도 shared deadline 사용 | generic `Any` wrapper tap과 timeout drift를 줄이기 위해 |
| `DUNEUITests/Helpers/UITestBaseCase.swift` | `navigateToSettings()`를 shared helper 기반으로 변경 | Today toolbar tap 로직을 한 곳에서 안정화하기 위해 |
| `DUNEUITests/Smoke/ActivitySmokeTests.swift` | add button lookup을 `Button` 기반으로 교체 | exercise picker open/search smoke가 wrapper tap에 의존하지 않게 하기 위해 |
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` | what's-new/notification toolbar 진입을 shared helper로 교체, tab round-trip을 `isSelected` 확인만 하는 좁은 smoke로 복원 | toolbar tap 안정화와 smoke scope 분리를 동시에 달성하기 위해 |
| `DUNEUITests/Smoke/LifeSmokeTests.swift` | add/save habit form 진입을 shared helper로 교체 | life add/save CTA가 `Any` wrapper가 아니라 실제 button hit target을 타게 하기 위해 |

### Key Code

```swift
@discardableResult
func waitAndTap(_ identifier: String, timeout: TimeInterval = 5) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    let buttonPredicate = NSPredicate(format: "identifier == %@", identifier)
    let buttonCandidates = [
        buttons[identifier].firstMatch,
        descendants(matching: .button).matching(buttonPredicate).firstMatch
    ]

    for button in buttonCandidates {
        let remainingTime = max(0, deadline.timeIntervalSinceNow)
        if button.exists || button.waitForExistence(timeout: remainingTime) {
            button.tap()
            return true
        }
    }

    let element = descendants(matching: .any)[identifier].firstMatch
    let remainingTime = max(0, deadline.timeIntervalSinceNow)
    guard element.exists || element.waitForExistence(timeout: remainingTime) else { return false }
    element.tap()
    return true
}
```

```swift
func testTabNavigationRoundTrip() throws {
    let tabBar = app.tabBars.firstMatch
    XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")

    for tab in ["Activity", "Wellness", "Life", "Today"] {
        let tabButton = tabBar.buttons[tab].firstMatch
        XCTAssertTrue(tabButton.waitForExistence(timeout: 3), "\(tab) tab should exist")
        tabButton.tap()

        let selectedPredicate = NSPredicate(format: "isSelected == true")
        expectation(for: selectedPredicate, evaluatedWith: tabButton)
        waitForExpectations(timeout: 3)
    }
}
```

## Prevention

UI smoke에서 accessibility identifier가 있다고 해서 바로 `Any` descendant를 누르면 안 된다.
toolbar, sheet action, save button처럼 hit target이 명확한 CTA는 항상 `Button` surface를 먼저 잡고, smoke test는 "전환/선택 안정성"과 "화면 렌더링 검증"을 서로 다른 테스트로 유지해야 한다.

### Checklist Addition

- [ ] identifier tap helper는 `buttons[identifier]` 또는 `.button` descendants를 `Any` fallback보다 먼저 탐색하는가?
- [ ] shared tap helper의 fallback path도 caller가 준 timeout budget을 그대로 사용하는가?
- [ ] tab round-trip smoke가 화면 렌더링 anchor까지 같이 검증하며 scope를 불필요하게 넓히지 않았는가?
- [ ] toolbar/add/save 같은 CTA는 debugDescription에서 실제 `Button`으로 노출되는지 한 번 확인했는가?
- [ ] validation smoke와 navigation smoke를 한 테스트에 섞지 않고, 실패 시 triage 가능한 단위로 분리했는가?

### Rule Addition (if applicable)

`docs/corrections-active.md`에 "XCUI identifier tap은 Button-first + shared timeout budget 유지" 항목을 추가했다.
반복되면 별도 UI testing rule로 승격한다.

## Lessons Learned

이번 건의 핵심은 화면 구현 자체보다 XCUI가 실제로 무엇을 탭하느냐였다.
동일한 identifier라도 `Button`이 아닌 wrapper를 잡으면 CI에서 바로 flaky해졌고, tap helper가 timeout contract를 정확히 지키지 않으면 안정화용 abstraction이 오히려 새 flake를 만들 수 있었다.

또한 smoke test는 coverage를 넓히는 것보다 실패 원인을 빠르게 좁힐 수 있는 scope가 더 중요했다.
tab 전환 smoke는 tab selection만 검증하고, 각 화면의 render/assertion은 별도 smoke에 남겨 두는 편이 회귀 triage 속도와 유지보수성 모두에서 유리했다.
