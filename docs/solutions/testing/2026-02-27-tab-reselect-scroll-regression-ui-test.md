---
tags: [ios, swiftui, tabview, ui-test, regression-test, scroll-to-top, accessibility-identifier]
category: testing
date: 2026-02-27
severity: minor
related_files:
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNEUITests/DailveUITests.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
related_solutions:
  - docs/solutions/testing/2026-02-23-healthkit-permission-ui-test-gating.md
---

# Solution: Add Regression UI Test For Tab Reselect Scroll-To-Top

## Problem

탭 재선택 시 스크롤을 최상단으로 올리는 기능을 추가했지만, 해당 동작을 검증하는 UI 회귀 테스트가 없어 이후 `TabView`/레이아웃 변경 시 동작이 깨져도 조기 감지되지 않는 상태였다.

### Symptoms

- `Activity` 탭 재탭 시 top 이동 동작이 코드 변경 후 무음 회귀될 위험
- 기존 `DailveUITests`는 탭 이동만 확인하고 재선택 시나리오는 검증하지 않음

### Root Cause

핵심 상호작용(같은 탭 재탭) 전용 테스트 케이스가 빠져 있었고, 상단 앵커 컴포넌트를 안정적으로 식별할 접근성 식별자도 정의되어 있지 않았다.

## Solution

탭 재선택 스크롤 동작을 end-to-end로 검증하는 UI 테스트를 추가하고, 상단 카드에 `accessibilityIdentifier`를 부여해 테스트 식별 안정성을 확보했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/ActivityView.swift` | `TrainingReadiness` 카드에 `activity-readiness-card` 식별자 추가 | 재선택 후 top 복귀 여부를 UI 테스트에서 안정적으로 판별 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | `AXID.activityReadinessCard` 상수 추가 | 테스트 식별자 하드코딩 방지 및 재사용 |
| `DUNEUITests/DailveUITests.swift` | `testReselectCurrentTabScrollsToTop()` 추가 | 스크롤 하강 → 동일 탭 재탭 → top 복귀 회귀 검증 |

### Key Code

```swift
func testReselectCurrentTabScrollsToTop() throws {
    let activityTab = app.tabBars.buttons["Activity"]
    activityTab.tap()

    let topCard = app.buttons[AXID.activityReadinessCard]
    XCTAssertTrue(topCard.waitForExistence(timeout: 10))

    while topCard.isHittable { app.swipeUp() }
    XCTAssertFalse(topCard.isHittable)

    activityTab.tap() // reselect current tab

    let becameVisible = NSPredicate(format: "hittable == true")
    expectation(for: becameVisible, evaluatedWith: topCard)
    waitForExpectations(timeout: 3)
}
```

## Prevention

탭/스크롤 상호작용 변경 시에는 기능 구현과 동시에 UI 회귀 테스트를 최소 1개 추가한다.

### Checklist Addition

- [ ] `TabView` 상호작용(재선택, 루트 복귀, 스크롤 복귀) 변경 시 대응 UI 테스트를 추가했는가?
- [ ] 테스트 대상 상단 앵커 요소에 안정적인 `accessibilityIdentifier`를 부여했는가?
- [ ] iPad 레이아웃(사이드바)에서 비적용 시 `XCTSkip` 조건을 명시했는가?

### Rule Addition (if applicable)

현재 규칙/스킬(`ui-testing`) 범위 내에서 커버 가능하므로 신규 rule 파일 추가는 생략했다.

## Lessons Learned

1. 기능 구현만으로는 회귀를 막을 수 없고, 사용자 상호작용 단위의 테스트가 반드시 필요하다.
2. UI 테스트 안정성은 로직보다 식별자 설계(`AXID`) 품질에 크게 좌우된다.
3. 탭 재선택 같은 "작은 UX 규칙"일수록 자동화되지 않으면 다음 리팩토링에서 가장 먼저 깨진다.
